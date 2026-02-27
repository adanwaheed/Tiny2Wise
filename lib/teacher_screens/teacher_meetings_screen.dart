import 'package:flutter/material.dart';
import '../services/api_service.dart';

class TeacherMeetingsScreen extends StatefulWidget {
  const TeacherMeetingsScreen({super.key});

  @override
  State<TeacherMeetingsScreen> createState() => _TeacherMeetingsScreenState();
}

class _TeacherMeetingsScreenState extends State<TeacherMeetingsScreen> {
  static const Color bg = Color(0xFFF5F7FB);
  static const Color dark = Color(0xFF111827);
  static const Color grey = Color(0xFF6B7280);
  static const Color border = Color(0xFFE5E7EB);
  static const Color green = Color(0xFF22C55E);

  bool loading = true;
  List<Map<String, dynamic>> events = [];

  @override
  void initState() {
    super.initState();
    _loadEvents();
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

  String _fmtDateTime(dynamic raw) {
    try {
      final dt = raw is DateTime ? raw : DateTime.parse(raw.toString()).toLocal();
      final y = dt.year.toString().padLeft(4, "0");
      final m = dt.month.toString().padLeft(2, "0");
      final d = dt.day.toString().padLeft(2, "0");
      int hh = dt.hour;
      final mm = dt.minute.toString().padLeft(2, "0");
      final ampm = hh >= 12 ? "PM" : "AM";
      hh = hh % 12;
      if (hh == 0) hh = 12;
      final hhs = hh.toString().padLeft(2, "0");
      return "$y-$m-$d  $hhs:$mm $ampm";
    } catch (_) {
      return raw?.toString() ?? "";
    }
  }

  Future<void> _loadEvents() async {
    setState(() => loading = true);
    try {
      // Upcoming this week by default (7 days)
      final list = await ApiService.getTeacherEvents(days: 7);
      events = list.cast<Map<String, dynamic>>();
    } catch (e) {
      _toast("$e");
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _openEventForm({Map<String, dynamic>? existing}) async {
    final isEdit = existing != null && (existing["_id"]?.toString().isNotEmpty ?? false);

    final titleCtrl = TextEditingController(text: existing?["title"]?.toString() ?? "");
    final noteCtrl = TextEditingController(text: existing?["note"]?.toString() ?? "");

    DateTime selected = DateTime.now().add(const Duration(days: 1));
    final existingStart = existing?["startAt"];
    if (existingStart != null) {
      try {
        selected = DateTime.parse(existingStart.toString()).toLocal();
      } catch (_) {}
    }

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
                            isEdit ? "Edit Meeting" : "Create Meeting",
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
                    _field(controller: titleCtrl, label: "Title", hint: "e.g., Parent-Teacher Meeting"),
                    const SizedBox(height: 10),
                    _field(controller: noteCtrl, label: "Note (optional)", hint: "e.g., Discuss progress with parents"),
                    const SizedBox(height: 12),

                    // Date/time pickers
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Start At", style: TextStyle(color: dark, fontWeight: FontWeight.w800, fontSize: 12.5)),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _fmtDateTime(selected.toIso8601String()),
                                  style: const TextStyle(color: grey, fontWeight: FontWeight.w700),
                                ),
                              ),
                              TextButton(
                                onPressed: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    firstDate: DateTime.now().subtract(const Duration(days: 1)),
                                    lastDate: DateTime.now().add(const Duration(days: 365)),
                                    initialDate: selected,
                                  );
                                  if (picked == null) return;
                                  setSheet(() {
                                    selected = DateTime(
                                      picked.year,
                                      picked.month,
                                      picked.day,
                                      selected.hour,
                                      selected.minute,
                                    );
                                  });
                                },
                                child: const Text("Date"),
                              ),
                              TextButton(
                                onPressed: () async {
                                  final picked = await showTimePicker(
                                    context: context,
                                    initialTime: TimeOfDay.fromDateTime(selected),
                                  );
                                  if (picked == null) return;
                                  setSheet(() {
                                    selected = DateTime(
                                      selected.year,
                                      selected.month,
                                      selected.day,
                                      picked.hour,
                                      picked.minute,
                                    );
                                  });
                                },
                                child: const Text("Time"),
                              ),
                            ],
                          ),
                        ],
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
                            text: isEdit ? "Save" : "Create",
                            onTap: () async {
                              final title = titleCtrl.text.trim();
                              final note = noteCtrl.text.trim();
                              if (title.isEmpty) {
                                _toast("Meeting title is required");
                                return;
                              }

                              try {
                                if (isEdit) {
                                  await ApiService.updateTeacherEvent(
                                    eventId: existing!["_id"].toString(),
                                    title: title,
                                    startAt: selected,
                                    note: note,
                                  );
                                } else {
                                  await ApiService.createTeacherEvent(
                                    title: title,
                                    startAt: selected,
                                    note: note,
                                  );
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
                );
              },
            ),
          ),
        );
      },
    );

    if (ok == true) {
      await _loadEvents();
      if (mounted) Navigator.pop(context, true); // tell dashboard something changed
    }
  }

  Future<void> _deleteEvent(Map<String, dynamic> e) async {
    final id = e["_id"]?.toString() ?? "";
    if (id.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete meeting?"),
        content: Text("This will remove '${e["title"] ?? "Meeting"}'."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Delete")),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ApiService.deleteTeacherEvent(eventId: id);
      await _loadEvents();
      if (mounted) Navigator.pop(context, true);
    } catch (err) {
      _toast("$err");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: bg,
        foregroundColor: dark,
        title: const Text("Upcoming This Week", style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          IconButton(
            onPressed: () => _openEventForm(),
            icon: const Icon(Icons.add_circle_outline_rounded),
            tooltip: "Add Meeting",
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _loadEvents,
        color: green,
        backgroundColor: Colors.white,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          children: [
            if (events.isEmpty)
              _empty(
                title: "No meetings scheduled",
                subtitle: "Create a meeting to see it here.",
                onTap: () => _openEventForm(),
              )
            else
              ...events.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _eventCard(e),
              )),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEventForm(),
        backgroundColor: green,
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  Widget _eventCard(Map<String, dynamic> e) {
    final title = (e["title"] ?? "Meeting").toString();
    final note = (e["note"] ?? "").toString();
    final startAt = _fmtDateTime(e["startAt"]);

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
                Text(title, style: const TextStyle(color: dark, fontSize: 13.5, fontWeight: FontWeight.w900)),
                const SizedBox(height: 3),
                Text(startAt, style: const TextStyle(color: grey, fontSize: 12, fontWeight: FontWeight.w700)),
                if (note.trim().isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    note,
                    style: const TextStyle(color: Color(0xFF9AA6AF), fontSize: 11.5, fontWeight: FontWeight.w600),
                  ),
                ],
              ],
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == "edit") _openEventForm(existing: e);
              if (v == "delete") _deleteEvent(e);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: "edit", child: Text("Edit")),
              PopupMenuItem(value: "delete", child: Text("Delete")),
            ],
            icon: const Icon(Icons.more_vert_rounded, color: Color(0xFF9CA3AF)),
          ),
        ],
      ),
    );
  }

  Widget _empty({
    required String title,
    required String subtitle,
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
            child: const Icon(Icons.event_available_outlined, color: dark),
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
                    child: const Text(
                      "Add Meeting",
                      style: TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.w900, fontSize: 12),
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