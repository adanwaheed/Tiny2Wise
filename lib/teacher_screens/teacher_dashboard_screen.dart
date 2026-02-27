import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'teacher_meetings_screen.dart';
import 'student_enolled_screen.dart';
import 'teacher_setting_screen.dart';

class TeacherDashboardScreen extends StatefulWidget {
  final String teacherName;
  final String teacherEmail;

  const TeacherDashboardScreen({
    super.key,
    required this.teacherName,
    required this.teacherEmail,
  });

  @override
  State<TeacherDashboardScreen> createState() => _TeacherDashboardScreenState();
}

class _TeacherDashboardScreenState extends State<TeacherDashboardScreen> {
  static const Color bg = Color(0xFFF5F7FB);
  static const Color dark = Color(0xFF111827);
  static const Color grey = Color(0xFF6B7280);
  static const Color border = Color(0xFFE5E7EB);
  static const Color green = Color(0xFF22C55E);

  // bottom nav (matches your screenshot)
  static const Color navBg = Color(0xFF0B1220);
  static const Color navInactive = Color(0xFF9CA3AF);

  int _navIndex = 0;
  bool loading = true;

  int studentsCount = 0;
  int alertsCount = 0;
  int tasksCount = 0;
  int progressPercent = 0;

  List<Map<String, dynamic>> classes = [];
  int upcomingCount = 0;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  String get _displayName {
    final n = widget.teacherName.trim();
    if (n.isNotEmpty) return n;
    final local = widget.teacherEmail.split("@").first.replaceAll(".", " ");
    return local
        .split(" ")
        .where((e) => e.trim().isNotEmpty)
        .map((e) => e[0].toUpperCase() + e.substring(1))
        .join(" ");
  }

  void _toast(String msg) {
    if (!mounted) return;
    final safe = msg.length > 120 ? "${msg.substring(0, 120)}..." : msg;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(safe, maxLines: 2, overflow: TextOverflow.ellipsis),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF0F1D14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.all(14),
      ),
    );
  }

  Future<void> _loadDashboard() async {
    setState(() => loading = true);
    try {
      final data = await ApiService.getTeacherDashboard();

      final stats = (data["stats"] as Map<String, dynamic>? ?? {});
      studentsCount = (stats["students"] ?? 0) as int;
      alertsCount = (stats["alerts"] ?? 0) as int;
      tasksCount = (stats["tasks"] ?? 0) as int;
      progressPercent = (stats["progress"] ?? 0) as int;

      classes = (data["classes"] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();

      final upcoming = (data["upcoming"] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
      upcomingCount = upcoming.length;
    } catch (e) {
      _toast("Failed to load: $e");
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  // ------------------- CREATE / EDIT CLASS -------------------

  Future<void> _openClassForm({Map<String, dynamic>? existing}) async {
    final titleCtrl = TextEditingController(text: existing?["title"]?.toString() ?? "");
    final subCtrl = TextEditingController(text: existing?["subtitle"]?.toString() ?? "");
    final isEdit = existing != null && (existing["_id"]?.toString().isNotEmpty ?? false);

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
            ),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        isEdit ? "Edit Class" : "Create Class",
                        style: const TextStyle(color: dark, fontSize: 15, fontWeight: FontWeight.w900),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context, false),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _field(controller: titleCtrl, label: "Class Title", hint: "e.g., Class A - Morning Stars"),
                const SizedBox(height: 10),
                _field(controller: subCtrl, label: "Subtitle (optional)", hint: "e.g., 12 Students • 85% Avg Progress"),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _pillAction(
                        filled: false,
                        text: "Cancel",
                        onTap: () => Navigator.pop(context, false),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _pillAction(
                        filled: true,
                        text: isEdit ? "Save" : "Create",
                        onTap: () async {
                          final title = titleCtrl.text.trim();
                          final sub = subCtrl.text.trim();
                          if (title.isEmpty) {
                            _toast("Class title is required");
                            return;
                          }

                          try {
                            if (isEdit) {
                              await ApiService.updateTeacherClass(
                                classId: existing!["_id"].toString(),
                                title: title,
                                subtitle: sub,
                              );
                            } else {
                              await ApiService.createTeacherClass(title: title, subtitle: sub);
                            }
                            if (context.mounted) Navigator.pop(context, true);
                          } catch (e) {
                            _toast("$e");
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (ok == true) {
      await _loadDashboard();
    }
  }

  Future<void> _deleteClass(Map<String, dynamic> c) async {
    final id = c["_id"]?.toString() ?? "";
    if (id.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete class?"),
        content: Text("This will remove '${c["title"] ?? "Class"}'."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Delete")),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ApiService.deleteTeacherClass(classId: id);
      await _loadDashboard();
      _toast("Class deleted");
    } catch (e) {
      _toast("$e");
    }
  }

  Future<void> _openMeetings() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const TeacherMeetingsScreen()),
    );
    if (changed == true) await _loadDashboard();
  }

  Future<void> _openStudents() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const StudentEnolledScreen()),
    );
    if (changed == true) await _loadDashboard();
  }

  // ------------------- UI -------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
          onRefresh: _loadDashboard,
          color: green,
          backgroundColor: Colors.white,
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: const Color(0xFFEFF6FF),
                      child: Text(
                        _displayName.isNotEmpty ? _displayName[0].toUpperCase() : "T",
                        style: const TextStyle(
                          color: Color(0xFF2563EB),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: dark,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            "Senior Teacher",
                            style: TextStyle(
                              color: grey,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _iconCircle(Icons.notifications_none_rounded, () => _toast("No notifications yet")),
                    const SizedBox(width: 10),
                    _iconCircle(Icons.search_rounded, () => _toast("Search not available yet")),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Today: ${DateTime.now().toLocal().toString().split(' ').first}",
                    style: const TextStyle(
                      color: grey,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GridView.count(
                        crossAxisCount: 2,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        childAspectRatio: 1.55,
                        children: [
                          _statCard("1", "Students", "$studentsCount", const Color(0xFFE9F0FF), const Color(0xFF2563EB)),
                          _statCard("2", "Alerts", "$alertsCount", const Color(0xFFFFE9EC), const Color(0xFFEF4444)),
                          _statCard("3", "Tasks", "$tasksCount", const Color(0xFFFFF6E6), const Color(0xFFF59E0B)),
                          _statCard("4", "Progress", "$progressPercent%", const Color(0xFFE8FFF2), const Color(0xFF22C55E)),
                        ],
                      ),

                      const SizedBox(height: 12),

                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 170,
                              child: _pillButton(
                                filled: true,
                                icon: Icons.add_rounded,
                                text: "New Assignment",
                                onTap: () => _toast(classes.isEmpty ? "Create a class first" : "Assignment feature coming soon"),
                              ),
                            ),
                            const SizedBox(width: 10),
                            SizedBox(
                              width: 150,
                              child: _pillButton(
                                filled: false,
                                icon: Icons.insert_chart_outlined_rounded,
                                text: "View Reports",
                                onTap: () => _toast("Reports will show once students enroll"),
                              ),
                            ),
                            const SizedBox(width: 10),
                            SizedBox(
                              width: 140,
                              child: _pillButton(
                                filled: false,
                                icon: Icons.event_note_rounded,
                                text: "Meeting ($upcomingCount)",
                                onTap: _openMeetings,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 18),

                      Row(
                        children: [
                          const Text(
                            "Your Classes",
                            style: TextStyle(color: dark, fontSize: 14.5, fontWeight: FontWeight.w900),
                          ),
                          const Spacer(),
                          Text(
                            "${classes.length} Classes",
                            style: const TextStyle(color: grey, fontSize: 12.5, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      if (classes.isEmpty)
                        _emptyCard(
                          title: "No classes yet",
                          subtitle: "Create your first class to start tracking students.",
                          icon: Icons.class_outlined,
                          buttonText: "Create Class",
                          onTap: () => _openClassForm(),
                        )
                      else ...[
                        Align(
                          alignment: Alignment.centerRight,
                          child: InkWell(
                            onTap: () => _openClassForm(),
                            borderRadius: BorderRadius.circular(999),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8FFF2),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: const Color(0xFFBBF7D0)),
                              ),
                              child: const Text(
                                "+ Add Class",
                                style: TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.w900, fontSize: 12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        ...classes.map(
                              (c) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _classCard(c),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),

      // ✅ EXACT teacher bottom bar like screenshot (dark bg, green active)
      bottomNavigationBar: _teacherBottomBar(),
    );
  }

  Widget _teacherBottomBar() {
    return Container(
      height: 64,
      decoration: const BoxDecoration(
        color: navBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _navItem(
            index: 0,
            icon: Icons.home_rounded,
            label: "Home",
            onTap: () => setState(() => _navIndex = 0),
          ),
          _navItem(
            index: 1,
            icon: Icons.bar_chart_rounded,
            label: "Activity",
            onTap: () {
              setState(() => _navIndex = 1);
              _toast("Activity coming soon");
            },
          ),
          _navItem(
            index: 2,
            icon: Icons.group_outlined,
            label: "Students",
            onTap: () async {
              setState(() => _navIndex = 2);
              await _openStudents();
              if (mounted) setState(() => _navIndex = 0); // return highlight to Home
            },
          ),
          _navItem(
            index: 3,
            icon: Icons.settings_rounded,
            label: "Settings",
            onTap: () async {
              setState(() => _navIndex = 3);
              final changed = await Navigator.push<bool>(
                context,
                MaterialPageRoute(builder: (_) => const TeacherSettingScreen()),
              );
              if (changed == true) {
                await _loadDashboard();
              }
              if (mounted) setState(() => _navIndex = 0); // highlight Home again if you want
            },
          ),
        ],
      ),
    );
  }

  Widget _navItem({
    required int index,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final active = _navIndex == index;
    final color = active ? green : navInactive;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: 72,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _iconCircle(IconData icon, VoidCallback onTap) {
    return InkResponse(
      onTap: onTap,
      radius: 24,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: border),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: dark, size: 20),
      ),
    );
  }

  Widget _statCard(String bubbleNumber, String bubbleLabel, String value, Color bubbleBg, Color bubbleFg) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(color: bubbleBg, borderRadius: BorderRadius.circular(12)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(bubbleNumber, style: TextStyle(color: bubbleFg, fontWeight: FontWeight.w900, fontSize: 14)),
                const SizedBox(width: 8),
                Text(bubbleLabel, style: TextStyle(color: bubbleFg, fontWeight: FontWeight.w800, fontSize: 12)),
              ],
            ),
          ),
          const Spacer(),
          Text(value, style: const TextStyle(color: dark, fontSize: 20, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  Widget _pillButton({
    required bool filled,
    required IconData icon,
    required String text,
    required VoidCallback onTap,
  }) {
    final bgc = filled ? green : Colors.white;
    final fgc = filled ? Colors.white : dark;
    final bd = filled ? Colors.transparent : border;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: bgc,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: bd),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: fgc, size: 18),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: fgc, fontSize: 12.5, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required String buttonText,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: dark),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: dark, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(color: grey, fontWeight: FontWeight.w600)),
                const SizedBox(height: 10),
                InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8FFF2),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: const Color(0xFFBBF7D0)),
                    ),
                    child: Text(
                      buttonText,
                      style: const TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.w900, fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _classCard(Map<String, dynamic> c) {
    final title = (c["title"] ?? "Class").toString();
    final subtitle = (c["subtitle"] ?? "").toString();
    final students = (c["students"] as List<dynamic>? ?? []);
    final count = (c["studentsCount"] ?? students.length).toString();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(color: dark, fontSize: 13.5, fontWeight: FontWeight.w900),
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == "edit") _openClassForm(existing: c);
                  if (v == "delete") _deleteClass(c);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: "edit", child: Text("Edit")),
                  PopupMenuItem(value: "delete", child: Text("Delete")),
                ],
                icon: const Icon(Icons.more_vert_rounded, color: Color(0xFF9CA3AF)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              subtitle.isEmpty ? "$count Students" : subtitle,
              style: const TextStyle(color: grey, fontSize: 11.5, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 10),
          if (students.isEmpty)
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "No students enrolled yet.",
                style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: border),
            ),
            child: const Center(
              child: Text(
                "View Class",
                style: TextStyle(color: dark, fontSize: 12.5, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: dark, fontWeight: FontWeight.w800, fontSize: 12.5)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontWeight: FontWeight.w600),
            filled: true,
            fillColor: const Color(0xFFF9FAFB),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: green, width: 1.2)),
          ),
        ),
      ],
    );
  }

  Widget _pillAction({
    required bool filled,
    required String text,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: filled ? green : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: filled ? Colors.transparent : border),
        ),
        child: Text(
          text,
          style: TextStyle(color: filled ? Colors.white : dark, fontWeight: FontWeight.w900, fontSize: 13),
        ),
      ),
    );
  }
}