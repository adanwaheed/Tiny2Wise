import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'teacher_setting_screen.dart';

class StudentEnolledScreen extends StatefulWidget {
  const StudentEnolledScreen({super.key});

  @override
  State<StudentEnolledScreen> createState() => _StudentEnolledScreenState();
}

class _StudentEnolledScreenState extends State<StudentEnolledScreen> {
  static const Color dark = Color(0xFF111827);
  static const Color grey = Color(0xFF6B7280);
  static const Color border = Color(0xFFE5E7EB);
  static const Color green = Color(0xFF22C55E);

  // ✅ same teacher bottom bar styling
  static const Color navBg = Color(0xFF0B1220);
  static const Color navInactive = Color(0xFF9CA3AF);

  bool loading = true;

  List<Map<String, dynamic>> toddlers = [];
  List<Map<String, dynamic>> classes = [];

  // ✅ keep Students selected/green on this screen
  int _navIndex = 2;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, maxLines: 2, overflow: TextOverflow.ellipsis),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF0F1D14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.all(14),
      ),
    );
  }

  Future<void> _loadAll() async {
    setState(() => loading = true);
    try {
      final t = await ApiService.getAllToddlersForTeacher();
      final c = await ApiService.getTeacherClasses();

      toddlers = t.cast<Map<String, dynamic>>();
      classes = c.cast<Map<String, dynamic>>();
    } catch (e) {
      _toast("$e");
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  String _ageLabel(dynamic rawAge) {
    final a = int.tryParse(rawAge?.toString() ?? "") ?? 0;
    if (a <= 0) return "";
    if (a == 1) return "1 Year Old";
    return "$a Years Old";
  }

  Map<String, dynamic>? _findAssignedClassForToddler(String toddlerId) {
    for (final c in classes) {
      final students = (c["students"] as List<dynamic>? ?? []);
      for (final s in students) {
        if ((s as Map?)?["toddlerId"]?.toString() == toddlerId) return c;
      }
    }
    return null;
  }

  Future<void> _openAssignSheet(Map<String, dynamic> toddler) async {
    final toddlerId = toddler["_id"]?.toString() ?? "";
    if (toddlerId.isEmpty) return;

    final assigned = _findAssignedClassForToddler(toddlerId);
    String? selectedClassId = assigned?["_id"]?.toString();

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
            child: StatefulBuilder(
              builder: (ctx, setSheet) {
                return Column(
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
                            "Assign Class",
                            style: const TextStyle(
                              color: dark,
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context, false),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        (toddler["name"] ?? "Student").toString(),
                        style: const TextStyle(
                          color: dark,
                          fontWeight: FontWeight.w900,
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: border),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String?>(
                          value: selectedClassId,
                          isExpanded: true,
                          hint: const Text("Select class"),
                          items: [
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text("Unassigned"),
                            ),
                            ...classes.map((c) {
                              return DropdownMenuItem<String?>(
                                value: c["_id"]?.toString(),
                                child: Text((c["title"] ?? "Class").toString()),
                              );
                            }),
                          ],
                          onChanged: (v) => setSheet(() => selectedClassId = v),
                        ),
                      ),
                    ),
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
                            text: "Save",
                            onTap: () async {
                              try {
                                await ApiService.assignToddlerToClass(
                                  toddlerId: toddlerId,
                                  classId: selectedClassId,
                                );
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
                );
              },
            ),
          ),
        );
      },
    );

    if (ok == true) {
      await _loadAll();
      if (mounted) Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFEFFAF2), Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
            onRefresh: _loadAll,
            color: green,
            backgroundColor: Colors.white,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context, false),
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                    ),
                    const SizedBox(width: 6),
                    const Expanded(
                      child: Text(
                        "Manage Profiles",
                        style: TextStyle(color: dark, fontWeight: FontWeight.w900, fontSize: 15),
                      ),
                    ),
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8FFF2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFBBF7D0)),
                      ),
                      child: const Icon(Icons.group_rounded, color: green),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  "Select a child to track progress or add a new one 🌱",
                  style: TextStyle(color: grey, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 18),

                if (toddlers.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.only(top: 60),
                      child: Text(
                        "No toddlers found.",
                        style: TextStyle(color: grey, fontWeight: FontWeight.w700),
                      ),
                    ),
                  )
                else
                  ...toddlers.map(
                        (t) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _profileCard(t),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),

      // ✅ same teacher bottom navigation bar + Students green
      bottomNavigationBar: _teacherBottomBar(),
    );
  }

  Widget _profileCard(Map<String, dynamic> t) {
    final name = (t["name"] ?? "Child").toString();
    final age = _ageLabel(t["age"]);
    final photoUrl = (t["photoUrl"] ?? "").toString();
    final hasPhoto = (t["hasPhoto"] ?? false) == true;

    final assignedClass = _findAssignedClassForToddler(t["_id"]?.toString() ?? "");
    final assignedTitle = assignedClass == null ? "Unassigned" : (assignedClass["title"] ?? "Class").toString();

    return InkWell(
      onTap: () => _openAssignSheet(t),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border),
          boxShadow: const [
            BoxShadow(
              color: Color(0x11000000),
              blurRadius: 10,
              offset: Offset(0, 4),
            )
          ],
        ),
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // ✅ no profile icon; image only, else blank grey circle
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE5E7EB), width: 2),
                color: const Color(0xFFF3F4F6),
              ),
              child: ClipOval(
                child: hasPhoto && photoUrl.trim().isNotEmpty
                    ? Image.network(
                  ApiService.absoluteUrl(photoUrl),
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(color: const Color(0xFFF3F4F6)),
                )
                    : Container(color: const Color(0xFFF3F4F6)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(color: dark, fontWeight: FontWeight.w900, fontSize: 13.5)),
                  const SizedBox(height: 4),
                  Text(age, style: const TextStyle(color: grey, fontWeight: FontWeight.w700, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(
                    "Class: $assignedTitle",
                    style: const TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.w800, fontSize: 11.5),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.more_vert_rounded, color: Color(0xFF9CA3AF)),
          ],
        ),
      ),
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
            onTap: () => Navigator.pop(context, true), // go back to dashboard
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
            onTap: () => setState(() => _navIndex = 2),
          ),
          _navItem(
            index: 3,
            icon: Icons.settings_rounded,
            label: "Settings",
            onTap: () async {
              setState(() => _navIndex = 3);
              await Navigator.push<bool>(
                context,
                MaterialPageRoute(builder: (_) => const TeacherSettingScreen()),
              );
              if (mounted) setState(() => _navIndex = 2);
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
          style: TextStyle(
            color: filled ? Colors.white : dark,
            fontWeight: FontWeight.w900,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}