import 'package:flutter/material.dart';
import '../services/api_service.dart';

class StudentActivityScreen extends StatefulWidget {
  const StudentActivityScreen({super.key});

  @override
  State<StudentActivityScreen> createState() => _StudentActivityScreenState();
}

class _StudentActivityScreenState extends State<StudentActivityScreen> {
  static const Color bg = Color(0xFFF3F8F0);
  static const Color green = Color(0xFF27C267);
  static const Color greenDark = Color(0xFF179C4C);
  static const Color dark = Color(0xFF14201A);
  static const Color grey = Color(0xFF6E7B80);
  static const Color border = Color(0xFFDCE9DD);
  static const Color red = Color(0xFFE74C3C);

  bool loading = true;
  bool assigning = false;
  bool hasChanges = false;

  List<Map<String, dynamic>> classes = [];
  List<Map<String, dynamic>> students = [];
  List<Map<String, dynamic>> recentAssignments = [];
  Set<String> actionLoadingIds = {};

  String selectedTarget = "single";
  String selectedActivity = "speech_practice";

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  List<Map<String, dynamic>> _asMapList(dynamic raw) {
    return (raw as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<void> _loadData() async {
    setState(() => loading = true);
    try {
      final targets = await ApiService.getTeacherActivityTargets();
      final assigned = await ApiService.getTeacherAssignedActivities(limit: 50);

      classes = _asMapList(targets["classes"]);
      students = _asMapList(targets["students"]);
      recentAssignments =
          assigned.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (e) {
      _toast("Failed to load activity data: $e");
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF0F1D14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.all(14),
      ),
    );
  }

  String _activityTitle(String type) {
    switch (type) {
      case "speech_practice":
        return "Speech Practice";
      case "puzzle_game":
        return "Puzzle/Game";
      case "mock_test":
        return "Mock Test";
      case "story_telling":
        return "Story Telling Mode";
      default:
        return "Activity";
    }
  }

  IconData _activityIcon(String type) {
    switch (type) {
      case "speech_practice":
        return Icons.menu_book_rounded;
      case "puzzle_game":
        return Icons.extension_rounded;
      case "mock_test":
        return Icons.assignment_outlined;
      case "story_telling":
        return Icons.mic_rounded;
      default:
        return Icons.circle;
    }
  }

  Color _activityTint(String type) {
    switch (type) {
      case "speech_practice":
        return const Color(0xFF27C267);
      case "puzzle_game":
        return const Color(0xFFB57CFF);
      case "mock_test":
        return const Color(0xFFF2A54A);
      case "story_telling":
        return const Color(0xFF5B8DEF);
      default:
        return green;
    }
  }

  List<Map<String, dynamic>> _studentsForClass(String classId) {
    final found = classes.firstWhere(
          (c) => (c["_id"] ?? "").toString() == classId,
      orElse: () => {},
    );
    return _asMapList(found["students"]);
  }

  Future<bool> _confirmAction({
    required String title,
    required String message,
    required String confirmText,
    Color confirmColor = green,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          title,
          style: const TextStyle(
            color: dark,
            fontWeight: FontWeight.w900,
          ),
        ),
        content: Text(
          message,
          style: const TextStyle(
            color: grey,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              "Cancel",
              style: TextStyle(color: grey, fontWeight: FontWeight.w800),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: confirmColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              confirmText,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );

    return result == true;
  }

  Future<_AssignmentSelection?> _pickSingleStudent() {
    return showModalBottomSheet<_AssignmentSelection>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: SizedBox(
              height: 440,
              child: Column(
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          "Select Single Child",
                          style: TextStyle(
                            color: dark,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: students.isEmpty
                        ? const Center(
                      child: Text(
                        "No linked students found",
                        style: TextStyle(
                          color: grey,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    )
                        : ListView.separated(
                      itemCount: students.length,
                      separatorBuilder: (_, __) =>
                      const SizedBox(height: 10),
                      itemBuilder: (_, i) {
                        final s = students[i];
                        final id = (s["_id"] ?? "").toString();
                        final name = (s["name"] ?? "Student").toString();

                        return InkWell(
                          onTap: () {
                            Navigator.pop(
                              context,
                              _AssignmentSelection(
                                toddlerIds: [id],
                                classId: null,
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              border: Border.all(color: border),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor:
                                  green.withOpacity(0.12),
                                  child: Text(
                                    name.isEmpty
                                        ? "S"
                                        : name[0].toUpperCase(),
                                    style: const TextStyle(
                                      color: greenDark,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    name,
                                    style: const TextStyle(
                                      color: dark,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                const Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  size: 16,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<_AssignmentSelection?> _pickSmallGroup() {
    String? selectedClassId =
    classes.isNotEmpty ? (classes.first["_id"] ?? "").toString() : null;
    final Set<String> selectedIds = {};

    return showModalBottomSheet<_AssignmentSelection>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final classStudents = selectedClassId == null
                ? <Map<String, dynamic>>[]
                : _studentsForClass(selectedClassId!);

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: SizedBox(
                  height: 560,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              "Select Small Group",
                              style: TextStyle(
                                color: dark,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        value: selectedClassId,
                        decoration: InputDecoration(
                          labelText: "Choose Class",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        items: classes
                            .map(
                              (c) => DropdownMenuItem<String>(
                            value: (c["_id"] ?? "").toString(),
                            child: Text((c["title"] ?? "Class").toString()),
                          ),
                        )
                            .toList(),
                        onChanged: (v) {
                          setModalState(() {
                            selectedClassId = v;
                            selectedIds.clear();
                          });
                        },
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        "Select students",
                        style: TextStyle(
                          color: dark,
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: classStudents.isEmpty
                            ? const Center(
                          child: Text(
                            "No students in this class",
                            style: TextStyle(
                              color: grey,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        )
                            : ListView.separated(
                          itemCount: classStudents.length,
                          separatorBuilder: (_, __) =>
                          const SizedBox(height: 8),
                          itemBuilder: (_, i) {
                            final s = classStudents[i];
                            final id = (s["_id"] ?? "").toString();
                            final name = (s["name"] ?? "Student")
                                .toString();
                            final checked = selectedIds.contains(id);

                            return CheckboxListTile(
                              value: checked,
                              activeColor: green,
                              contentPadding:
                              const EdgeInsets.symmetric(
                                  horizontal: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                                side: const BorderSide(color: border),
                              ),
                              title: Text(
                                name,
                                style: const TextStyle(
                                  color: dark,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              onChanged: (_) {
                                setModalState(() {
                                  if (checked) {
                                    selectedIds.remove(id);
                                  } else {
                                    selectedIds.add(id);
                                  }
                                });
                              },
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: green,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: () {
                            if (selectedClassId == null || selectedIds.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("Select class and students"),
                                ),
                              );
                              return;
                            }

                            Navigator.pop(
                              context,
                              _AssignmentSelection(
                                classId: selectedClassId,
                                toddlerIds: selectedIds.toList(),
                              ),
                            );
                          },
                          child: const Text(
                            "Continue",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<_AssignmentSelection?> _pickFullClass() {
    return showModalBottomSheet<_AssignmentSelection>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: SizedBox(
              height: 420,
              child: Column(
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          "Select Full Class",
                          style: TextStyle(
                            color: dark,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: classes.isEmpty
                        ? const Center(
                      child: Text(
                        "No classes available",
                        style: TextStyle(
                          color: grey,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    )
                        : ListView.separated(
                      itemCount: classes.length,
                      separatorBuilder: (_, __) =>
                      const SizedBox(height: 10),
                      itemBuilder: (_, i) {
                        final c = classes[i];
                        final classId = (c["_id"] ?? "").toString();
                        final title =
                        (c["title"] ?? "Class").toString();
                        final count = (_asMapList(c["students"])).length;

                        return InkWell(
                          onTap: () {
                            Navigator.pop(
                              context,
                              _AssignmentSelection(
                                classId: classId,
                                toddlerIds: const [],
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              border: Border.all(color: border),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: green.withOpacity(0.10),
                                    borderRadius:
                                    BorderRadius.circular(14),
                                  ),
                                  child: const Icon(
                                    Icons.groups_rounded,
                                    color: greenDark,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        title,
                                        style: const TextStyle(
                                          color: dark,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        "$count students",
                                        style: const TextStyle(
                                          color: grey,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  size: 16,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _assignSelectedActivity() async {
    if (classes.isEmpty) {
      _toast("Create a class and assign students first");
      return;
    }

    _AssignmentSelection? picked;
    if (selectedTarget == "single") {
      picked = await _pickSingleStudent();
    } else if (selectedTarget == "group") {
      picked = await _pickSmallGroup();
    } else {
      picked = await _pickFullClass();
    }

    if (picked == null) return;

    try {
      setState(() => assigning = true);

      final res = await ApiService.assignTeacherActivity(
        activityType: selectedActivity,
        targetType: selectedTarget,
        classId: picked.classId,
        toddlerIds: picked.toddlerIds,
      );

      hasChanges = true;
      _toast((res["message"] ?? "Activity assigned").toString());
      await _loadData();
    } catch (e) {
      _toast("Assign failed: $e");
    } finally {
      if (mounted) setState(() => assigning = false);
    }
  }

  Future<void> _completeTeacherAssignment(String assignmentId) async {
    final ok = await _confirmAction(
      title: "Complete Assignment",
      message: "Mark this assigned activity as completed?",
      confirmText: "Complete",
      confirmColor: green,
    );
    if (!ok) return;

    setState(() => actionLoadingIds.add(assignmentId));
    try {
      await ApiService.completeTeacherAssignedActivity(assignmentId);
      recentAssignments.removeWhere(
            (item) => (item["_id"] ?? "").toString() == assignmentId,
      );
      hasChanges = true;
      if (mounted) setState(() {});
      _toast("Assignment completed");
    } catch (e) {
      _toast("Failed to complete assignment: $e");
    } finally {
      if (mounted) {
        setState(() => actionLoadingIds.remove(assignmentId));
      }
    }
  }

  Future<void> _deleteTeacherAssignment(String assignmentId) async {
    final ok = await _confirmAction(
      title: "Delete Assignment",
      message: "Are you sure you want to delete this assignment?",
      confirmText: "Delete",
      confirmColor: red,
    );
    if (!ok) return;

    setState(() => actionLoadingIds.add(assignmentId));
    try {
      await ApiService.deleteTeacherAssignedActivity(assignmentId);
      recentAssignments.removeWhere(
            (item) => (item["_id"] ?? "").toString() == assignmentId,
      );
      hasChanges = true;
      if (mounted) setState(() {});
      _toast("Assignment deleted");
    } catch (e) {
      _toast("Failed to delete assignment: $e");
    } finally {
      if (mounted) {
        setState(() => actionLoadingIds.remove(assignmentId));
      }
    }
  }

  Future<void> _goBack() async {
    Navigator.pop(context, hasChanges);
  }

  Widget _actionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    bool filled = false,
  }) {
    return Expanded(
      child: SizedBox(
        height: 40,
        child: filled
            ? ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: onTap,
          icon: Icon(icon, size: 16, color: Colors.white),
          label: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 12.5,
            ),
          ),
        )
            : OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: color.withOpacity(0.35)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: onTap,
          icon: Icon(icon, size: 16, color: color),
          label: Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 12.5,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: loading
            ? const Center(child: CircularProgressIndicator(color: green))
            : RefreshIndicator(
          color: green,
          onRefresh: _loadData,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: _goBack,
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    const Expanded(
                      child: Text(
                        "New Assignment",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: dark,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _goBack,
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  "Who is this for?",
                  style: TextStyle(
                    color: dark,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _TargetCard(
                        title: "Single Child",
                        subtitle: "Assign to one student",
                        icon: Icons.person_outline_rounded,
                        selected: selectedTarget == "single",
                        onTap: () =>
                            setState(() => selectedTarget = "single"),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _TargetCard(
                        title: "Small Group",
                        subtitle: "2-5 students",
                        icon: Icons.groups_2_outlined,
                        selected: selectedTarget == "group",
                        onTap: () =>
                            setState(() => selectedTarget = "group"),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _TargetCard(
                        title: "Full Class",
                        subtitle: "All students",
                        icon: Icons.groups_rounded,
                        selected: selectedTarget == "class",
                        onTap: () =>
                            setState(() => selectedTarget = "class"),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      colors: [
                        green.withOpacity(0.12),
                        Colors.white,
                      ],
                    ),
                    border: Border.all(color: border),
                  ),
                  child: Row(
                    children: const [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: Color(0xFFE9F7EF),
                        child: Icon(
                          Icons.school_rounded,
                          color: greenDark,
                          size: 28,
                        ),
                      ),
                      SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          "Choose one activity and assign it dynamically to a child, group, or full class.",
                          style: TextStyle(
                            color: dark,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  "Select Activity",
                  style: TextStyle(
                    color: dark,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                _ActivityOptionCard(
                  title: "Speech Practice",
                  subtitle: "Phonics & pronunciation",
                  icon: Icons.menu_book_rounded,
                  tint: const Color(0xFF27C267),
                  selected: selectedActivity == "speech_practice",
                  onTap: () => setState(
                        () => selectedActivity = "speech_practice",
                  ),
                ),
                const SizedBox(height: 10),
                _ActivityOptionCard(
                  title: "Puzzle/Game",
                  subtitle: "Interactive learning",
                  icon: Icons.extension_rounded,
                  tint: const Color(0xFFB57CFF),
                  selected: selectedActivity == "puzzle_game",
                  onTap: () =>
                      setState(() => selectedActivity = "puzzle_game"),
                ),
                const SizedBox(height: 10),
                _ActivityOptionCard(
                  title: "Mock Test",
                  subtitle: "Assessment quiz",
                  icon: Icons.assignment_outlined,
                  tint: const Color(0xFFF2A54A),
                  selected: selectedActivity == "mock_test",
                  onTap: () =>
                      setState(() => selectedActivity = "mock_test"),
                ),
                const SizedBox(height: 10),
                _ActivityOptionCard(
                  title: "Story Telling Mode",
                  subtitle: "Record audio",
                  icon: Icons.calendar_today_rounded,
                  tint: const Color(0xFF5B8DEF),
                  selected: selectedActivity == "story_telling",
                  onTap: () =>
                      setState(() => selectedActivity = "story_telling"),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: green,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: assigning ? null : _assignSelectedActivity,
                    child: assigning
                        ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.4,
                      ),
                    )
                        : const Text(
                      "Assign Activity",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    const Text(
                      "Recent Assigned Activities",
                      style: TextStyle(
                        color: dark,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      "${recentAssignments.length}",
                      style: const TextStyle(
                        color: grey,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (recentAssignments.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: border),
                    ),
                    child: const Text(
                      "No assignments yet.",
                      style: TextStyle(
                        color: grey,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                else
                  ...recentAssignments.map((item) {
                    final id = (item["_id"] ?? "").toString();
                    final type = (item["activityType"] ?? "").toString();
                    final isBusy = actionLoadingIds.contains(id);

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: border),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: _activityTint(type)
                                      .withOpacity(0.14),
                                  child: Icon(
                                    _activityIcon(type),
                                    color: _activityTint(type),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _activityTitle(type),
                                        style: const TextStyle(
                                          color: dark,
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        "${(item["targetType"] ?? "").toString().toUpperCase()} • ${(item["assignedCount"] ?? 0)} student(s)",
                                        style: const TextStyle(
                                          color: grey,
                                          fontSize: 11.8,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      if ((item["classTitle"] ?? "")
                                          .toString()
                                          .trim()
                                          .isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          (item["classTitle"] ?? "")
                                              .toString(),
                                          style: const TextStyle(
                                            color: grey,
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ]
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (isBusy)
                              const Padding(
                                padding:
                                EdgeInsets.symmetric(vertical: 6),
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: green,
                                    strokeWidth: 2.5,
                                  ),
                                ),
                              )
                            else
                              Row(
                                children: [
                                  _actionButton(
                                    label: "Complete",
                                    icon: Icons.check_circle_rounded,
                                    color: green,
                                    filled: true,
                                    onTap: () =>
                                        _completeTeacherAssignment(id),
                                  ),
                                  const SizedBox(width: 10),
                                  _actionButton(
                                    label: "Delete",
                                    icon:
                                    Icons.delete_outline_rounded,
                                    color: red,
                                    onTap: () =>
                                        _deleteTeacherAssignment(id),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    );
                  }),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AssignmentSelection {
  final String? classId;
  final List<String> toddlerIds;

  const _AssignmentSelection({
    required this.classId,
    required this.toddlerIds,
  });
}

class _TargetCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _TargetCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF27C267);
    const dark = Color(0xFF14201A);
    const grey = Color(0xFF6E7B80);
    const border = Color(0xFFDCE9DD);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? green.withOpacity(0.10) : const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: selected ? green : border, width: 1.3),
        ),
        child: Column(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: selected ? green : Colors.white,
              child: Icon(icon, size: 18, color: selected ? Colors.white : grey),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: dark,
                fontSize: 11.5,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: grey,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityOptionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color tint;
  final bool selected;
  final VoidCallback onTap;

  const _ActivityOptionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.tint,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const dark = Color(0xFF14201A);
    const grey = Color(0xFF6E7B80);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? tint.withOpacity(0.10) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? tint : const Color(0xFFDCE9DD),
            width: 1.2,
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: tint,
              child: Icon(icon, color: Colors.white, size: 18),
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
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: grey,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              selected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: selected ? tint : grey,
            ),
          ],
        ),
      ),
    );
  }
}