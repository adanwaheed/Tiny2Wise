import 'package:flutter/material.dart';
import '../services/api_service.dart';

class AssignedActivitiesScreen extends StatefulWidget {
  final String toddlerId;
  final String toddlerName;

  const AssignedActivitiesScreen({
    super.key,
    required this.toddlerId,
    required this.toddlerName,
  });

  @override
  State<AssignedActivitiesScreen> createState() => _AssignedActivitiesScreenState();
}

class _AssignedActivitiesScreenState extends State<AssignedActivitiesScreen> {
  static const Color bg = Color(0xFFF4FFF6);
  static const Color green = Color(0xFF27C267);
  static const Color greenDark = Color(0xFF179C4C);
  static const Color dark = Color(0xFF14201A);
  static const Color grey = Color(0xFF6E7B80);
  static const Color border = Color(0xFFE2EFE7);
  static const Color red = Color(0xFFE74C3C);

  bool loading = true;
  List<Map<String, dynamic>> assignments = [];
  Set<String> actionLoadingIds = {};

  @override
  void initState() {
    super.initState();
    _loadAssignments();
  }

  Future<void> _loadAssignments() async {
    setState(() => loading = true);
    try {
      final list = await ApiService.getToddlerAssignedActivities(widget.toddlerId);
      assignments = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (e) {
      _toast("Failed to load assignments: $e");
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

  String _timeText(String raw) {
    try {
      final dt = DateTime.parse(raw).toLocal();
      return "${dt.day}/${dt.month}/${dt.year} • ${dt.hour.toString().padLeft(2, "0")}:${dt.minute.toString().padLeft(2, "0")}";
    } catch (_) {
      return raw;
    }
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
              style: TextStyle(
                color: grey,
                fontWeight: FontWeight.w800,
              ),
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

  Future<void> _completeAssignment(String assignmentId) async {
    final ok = await _confirmAction(
      title: "Complete Activity",
      message: "Mark this activity as completed for ${widget.toddlerName}?",
      confirmText: "Complete",
      confirmColor: green,
    );
    if (!ok) return;

    setState(() => actionLoadingIds.add(assignmentId));
    try {
      await ApiService.completeAssignedActivity(assignmentId);
      assignments.removeWhere((item) => (item["_id"] ?? "").toString() == assignmentId);
      if (mounted) setState(() {});
      _toast("Activity marked as completed");
    } catch (e) {
      _toast("Failed to complete activity: $e");
    } finally {
      if (mounted) {
        setState(() => actionLoadingIds.remove(assignmentId));
      }
    }
  }

  Future<void> _deleteAssignment(String assignmentId) async {
    final ok = await _confirmAction(
      title: "Delete Activity",
      message: "Are you sure you want to delete this assigned activity?",
      confirmText: "Delete",
      confirmColor: red,
    );
    if (!ok) return;

    setState(() => actionLoadingIds.add(assignmentId));
    try {
      await ApiService.deleteAssignedActivity(assignmentId);
      assignments.removeWhere((item) => (item["_id"] ?? "").toString() == assignmentId);
      if (mounted) setState(() {});
      _toast("Assigned activity deleted");
    } catch (e) {
      _toast("Failed to delete activity: $e");
    } finally {
      if (mounted) {
        setState(() => actionLoadingIds.remove(assignmentId));
      }
    }
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
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "Assigned Activities",
          style: TextStyle(
            color: dark,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: green))
          : RefreshIndicator(
        color: green,
        onRefresh: _loadAssignments,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: border),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: green.withOpacity(0.12),
                    child: Text(
                      widget.toddlerName.isEmpty
                          ? "C"
                          : widget.toddlerName[0].toUpperCase(),
                      style: const TextStyle(
                        color: green,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.toddlerName,
                      style: const TextStyle(
                        color: dark,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Text(
                    "${assignments.length} item(s)",
                    style: const TextStyle(
                      color: grey,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (assignments.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: border),
                ),
                child: const Center(
                  child: Text(
                    "No teacher-assigned activities yet.",
                    style: TextStyle(
                      color: grey,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              )
            else
              ...assignments.map((item) {
                final id = (item["_id"] ?? "").toString();
                final type = (item["activityType"] ?? "").toString();
                final teacherName = (item["teacherName"] ?? "Teacher").toString();
                final classTitle = (item["classTitle"] ?? "").toString();
                final targetType = (item["targetType"] ?? "").toString();
                final assignedAt = (item["assignedAt"] ?? "").toString();
                final isBusy = actionLoadingIds.contains(id);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: border),
                    ),
                    child: Column(
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: _activityTint(type).withOpacity(0.14),
                              child: Icon(
                                _activityIcon(type),
                                color: _activityTint(type),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _activityTitle(type),
                                    style: const TextStyle(
                                      color: dark,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "Assigned by $teacherName",
                                    style: const TextStyle(
                                      color: grey,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  if (classTitle.trim().isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      "Class: $classTitle",
                                      style: const TextStyle(
                                        color: grey,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 4),
                                  Text(
                                    "Target: ${targetType.toUpperCase()}",
                                    style: const TextStyle(
                                      color: grey,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _timeText(assignedAt),
                                    style: const TextStyle(
                                      color: grey,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        if (isBusy)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 6),
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
                                onTap: () => _completeAssignment(id),
                              ),
                              const SizedBox(width: 10),
                              _actionButton(
                                label: "Delete",
                                icon: Icons.delete_outline_rounded,
                                color: red,
                                onTap: () => _deleteAssignment(id),
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
    );
  }
}