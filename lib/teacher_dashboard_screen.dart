import 'package:flutter/material.dart';
import 'services/api_service.dart';

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

  int _navIndex = 0;
  bool loading = true;

  int studentsCount = 0;
  int alertsCount = 0;
  int tasksCount = 0;
  int progressPercent = 0;

  List<Map<String, dynamic>> classes = [];
  List<Map<String, dynamic>> upcoming = [];

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
        content: Text(
          safe,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
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
      upcoming = (data["upcoming"] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    } catch (e) {
      _toast("Failed to load: $e");
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

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
                    _iconCircle(Icons.notifications_none_rounded,
                            () => _toast("No notifications yet")),
                    const SizedBox(width: 10),
                    _iconCircle(Icons.search_rounded,
                            () => _toast("Search not available yet")),
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
                      // ✅ Smaller Grid + labels moved into chip
                      GridView.count(
                        crossAxisCount: 2,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        childAspectRatio: 1.55,
                        children: [
                          _statCard(
                            "1",
                            "Students",
                            "$studentsCount",
                            const Color(0xFFE9F0FF),
                            const Color(0xFF2563EB),
                          ),
                          _statCard(
                            "2",
                            "Alerts",
                            "$alertsCount",
                            const Color(0xFFFFE9EC),
                            const Color(0xFFEF4444),
                          ),
                          _statCard(
                            "3",
                            "Tasks",
                            "$tasksCount",
                            const Color(0xFFFFF6E6),
                            const Color(0xFFF59E0B),
                          ),
                          _statCard(
                            "4",
                            "Progress",
                            "$progressPercent%",
                            const Color(0xFFE8FFF2),
                            const Color(0xFF22C55E),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // ✅ Fixed + scrollable horizontally (no overflow)
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
                                onTap: () => _toast(
                                  classes.isEmpty
                                      ? "Create a class first"
                                      : "Assignment feature coming soon",
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            SizedBox(
                              width: 150,
                              child: _pillButton(
                                filled: false,
                                icon: Icons.insert_chart_outlined_rounded,
                                text: "View Reports",
                                onTap: () => _toast(
                                  "Reports will show once students enroll",
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            SizedBox(
                              width: 110,
                              child: _smallPill(
                                "Meeting",
                                    () => _toast("No meetings scheduled"),
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
                            style: TextStyle(
                              color: dark,
                              fontSize: 14.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            "${classes.length} Classes",
                            style: const TextStyle(
                              color: grey,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
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
                          onTap: () async {
                            try {
                              await ApiService.createTeacherClass(
                                title: "Class A - Morning Stars",
                                subtitle: "0 Students • 0% Avg Progress",
                              );
                              await _loadDashboard();
                            } catch (e) {
                              _toast("$e");
                            }
                          },
                        )
                      else
                        ...classes.map(
                              (c) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _classCard(c),
                          ),
                        ),

                      const SizedBox(height: 8),

                      const Text(
                        "Upcoming This Week",
                        style: TextStyle(
                          color: dark,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 10),

                      if (upcoming.isEmpty)
                        _emptyCard(
                          title: "No upcoming events",
                          subtitle: "Your schedule will appear here once events are added.",
                          icon: Icons.event_available_outlined,
                          buttonText: "Add Event",
                          onTap: () async {
                            try {
                              await ApiService.createTeacherEvent(
                                title: "Parent-Teacher Meeting",
                                startAt: DateTime.now().add(const Duration(days: 2)),
                                note: "Discuss progress with parents",
                              );
                              await _loadDashboard();
                            } catch (e) {
                              _toast("$e");
                            }
                          },
                        )
                      else
                        ...upcoming.map(
                              (u) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _upcomingCard(u),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _bottomNav(),
    );
  }

  Widget _bottomNav() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: border)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: BottomNavigationBar(
        currentIndex: _navIndex,
        onTap: (i) => setState(() => _navIndex = i),
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        elevation: 0,
        selectedItemColor: green,
        unselectedItemColor: const Color(0xFF9CA3AF),
        selectedFontSize: 11,
        unselectedFontSize: 11,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.analytics_rounded), label: "Analytics"),
          BottomNavigationBarItem(icon: Icon(Icons.people_alt_rounded), label: "Students"),
          BottomNavigationBarItem(icon: Icon(Icons.settings_rounded), label: "Settings"),
        ],
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

  // ✅ label removed from bottom, moved into chip with number
  Widget _statCard(
      String bubbleNumber,
      String bubbleLabel,
      String value,
      Color bubbleBg,
      Color bubbleFg,
      ) {
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
            decoration: BoxDecoration(
              color: bubbleBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  bubbleNumber,
                  style: TextStyle(
                    color: bubbleFg,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  bubbleLabel,
                  style: TextStyle(
                    color: bubbleFg,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              color: dark,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  // ✅ Prevent overflow inside button
  Widget _pillButton({
    required bool filled,
    required IconData icon,
    required String text,
    required VoidCallback onTap,
  }) {
    final bg = filled ? green : Colors.white;
    final fg = filled ? Colors.white : dark;
    final bd = filled ? Colors.transparent : border;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: bd),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: fg, size: 18),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: fg,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _smallPill(String text, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: border),
        ),
        child: Center(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: dark,
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
            ),
          ),
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
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(12),
            ),
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
                      style: const TextStyle(
                        color: Color(0xFF16A34A),
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
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
                  style: const TextStyle(
                    color: dark,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const Icon(Icons.expand_more_rounded, color: Color(0xFF9CA3AF)),
            ],
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              subtitle,
              style: const TextStyle(
                color: grey,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 10),
          if (students.isEmpty)
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "No students enrolled yet.",
                style: TextStyle(
                  color: Color(0xFF9CA3AF),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
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
                style: TextStyle(
                  color: dark,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _upcomingCard(Map<String, dynamic> u) {
    final title = (u["title"] ?? "Event").toString();
    final note = (u["note"] ?? "").toString();
    final startAt = (u["startAt"] ?? "").toString();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF1CC),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.event_note_rounded, color: dark),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: dark,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  startAt,
                  style: const TextStyle(
                    color: grey,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  note,
                  style: const TextStyle(
                    color: Color(0xFF9AA6AF),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}