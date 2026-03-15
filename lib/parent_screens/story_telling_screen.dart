import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import 'parent_setting_screen.dart';

import '../services/api_service.dart';

class StoryTellingScreen extends StatefulWidget {
  final VoidCallback? onHomeTap;
  final VoidCallback? onActivityTap;
  final VoidCallback? onBookmarkTap;
  final VoidCallback? onSettingsTap;
  final VoidCallback? onCenterTap;

  const StoryTellingScreen({
    super.key,
    this.onHomeTap,
    this.onActivityTap,
    this.onBookmarkTap,
    this.onSettingsTap,
    this.onCenterTap,
  });

  @override
  State<StoryTellingScreen> createState() => _StoryTellingScreenState();
}

class _StoryTellingScreenState extends State<StoryTellingScreen> {
  static const Color bg = Color(0xFFF4F4F4);
  static const Color card = Colors.white;
  static const Color dark = Color(0xFF1B2233);
  static const Color lightText = Color(0xFF8892A0);
  static const Color green = Color(0xFF18F400);
  static const Color border = Color(0xFFE8E8E8);

  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();
  final Stopwatch _stopwatch = Stopwatch();

  Timer? _ticker;
  bool _isRecording = false;
  bool _loading = true;
  bool _saving = false;

  String? _currentFilePath;
  String? _currentlyPlayingId;

  List<Map<String, dynamic>> _stories = [];
  List<Map<String, dynamic>> _toddlers = [];

  @override
  void initState() {
    super.initState();
    _loadAll();
    _player.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _currentlyPlayingId = null;
        });
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _player.dispose();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      final stories = await ApiService.getStories();
      final toddlers = await ApiService.getToddlers();

      setState(() {
        _stories = stories.map((e) => Map<String, dynamic>.from(e)).toList();
        _toddlers = toddlers.map((e) => Map<String, dynamic>.from(e)).toList();
      });
    } catch (e) {
      _showSnack(e.toString());
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      await _stopRecordingAndSave();
    } else {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    try {
      final micStatus = await Permission.microphone.request();
      if (!micStatus.isGranted) {
        _showSnack("Microphone permission is required.");
        return;
      }

      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) {
        _showSnack("Microphone permission is required.");
        return;
      }

      final dir = await getApplicationDocumentsDirectory();
      final filePath =
          "${dir.path}/story_${DateTime.now().millisecondsSinceEpoch}.m4a";

      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: filePath,
      );

      _currentFilePath = filePath;
      _stopwatch
        ..reset()
        ..start();

      _ticker?.cancel();
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });

      setState(() {
        _isRecording = true;
      });
    } catch (e) {
      _showSnack("Unable to start recording: $e");
    }
  }

  Future<void> _stopRecordingAndSave() async {
    try {
      final path = await _recorder.stop();

      _stopwatch.stop();
      _ticker?.cancel();

      setState(() {
        _isRecording = false;
      });

      final finalPath = path ?? _currentFilePath;
      if (finalPath == null || !File(finalPath).existsSync()) {
        _showSnack("Recording file not found.");
        return;
      }

      await _openSaveStorySheet(
        audioFile: File(finalPath),
        durationSec: _stopwatch.elapsed.inSeconds,
      );
    } catch (e) {
      _showSnack("Unable to stop recording: $e");
    }
  }

  Future<void> _openSaveStorySheet({
    required File audioFile,
    required int durationSec,
  }) async {
    final controller = TextEditingController();
    String selectedLanguage = "Urdu";
    bool isDraft = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setBottomState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 18,
                right: 18,
                top: 18,
                bottom: MediaQuery.of(context).viewInsets.bottom + 18,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Save Story",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: dark,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: controller,
                    decoration: InputDecoration(
                      hintText: "Enter story title",
                      filled: true,
                      fillColor: const Color(0xFFF7F7F7),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedLanguage,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFFF7F7F7),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(value: "Urdu", child: Text("Urdu")),
                      DropdownMenuItem(value: "English", child: Text("English")),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      setBottomState(() => selectedLanguage = v);
                    },
                  ),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: isDraft,
                    onChanged: (v) {
                      setBottomState(() => isDraft = v ?? false);
                    },
                    title: const Text("Save as draft"),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: green,
                        foregroundColor: dark,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: _saving
                          ? null
                          : () async {
                        final title = controller.text.trim();
                        if (title.isEmpty) {
                          _showSnack("Please enter story title.");
                          return;
                        }
                        Navigator.pop(context);
                        await _saveStory(
                          title: title,
                          audioFile: audioFile,
                          durationSec: durationSec,
                          language: selectedLanguage,
                          isDraft: isDraft,
                        );
                      },
                      child: const Text(
                        "Save Story",
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _saveStory({
    required String title,
    required File audioFile,
    required int durationSec,
    required String language,
    required bool isDraft,
  }) async {
    try {
      setState(() => _saving = true);

      await ApiService.createStory(
        title: title,
        durationSec: durationSec,
        audioFile: audioFile,
        language: language,
        isDraft: isDraft,
      );

      _showSnack("Story saved successfully.");
      await _loadAll();
    } catch (e) {
      _showSnack(e.toString());
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _deleteStory(String storyId) async {
    try {
      await ApiService.deleteStory(storyId);
      _showSnack("Story deleted.");
      await _loadAll();
    } catch (e) {
      _showSnack(e.toString());
    }
  }

  Future<void> _editStory(Map<String, dynamic> story) async {
    final controller = TextEditingController(text: "${story["title"] ?? ""}");
    String selectedLanguage = "${story["language"] ?? "Urdu"}";
    bool isDraft = story["isDraft"] == true;

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Edit Story"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  hintText: "Story title",
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedLanguage,
                items: const [
                  DropdownMenuItem(value: "Urdu", child: Text("Urdu")),
                  DropdownMenuItem(value: "English", child: Text("English")),
                ],
                onChanged: (v) {
                  if (v != null) {
                    selectedLanguage = v;
                  }
                },
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: isDraft,
                onChanged: (v) => isDraft = v ?? false,
                title: const Text("Draft"),
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                final title = controller.text.trim();
                if (title.isEmpty) {
                  _showSnack("Title is required.");
                  return;
                }

                Navigator.pop(context);

                try {
                  await ApiService.updateStory(
                    storyId: "${story["_id"]}",
                    title: title,
                    durationSec: (story["durationSec"] ?? 0) as int,
                    language: selectedLanguage,
                    isDraft: isDraft,
                  );
                  _showSnack("Story updated.");
                  await _loadAll();
                } catch (e) {
                  _showSnack(e.toString());
                }
              },
              child: const Text("Update"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _assignStory(Map<String, dynamic> story) async {
    final selectedIds = <String>{
      ...((story["assignedToddlerIds"] as List?)?.map((e) => "$e") ?? []),
    };
    bool assignToAll = story["assignedToAll"] == true;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setBottomState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 18,
                right: 18,
                top: 18,
                bottom: MediaQuery.of(context).viewInsets.bottom + 18,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Assign Story",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: assignToAll,
                    onChanged: (v) {
                      setBottomState(() {
                        assignToAll = v ?? false;
                      });
                    },
                    title: const Text("Assign to all toddlers"),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  if (!assignToAll)
                    ..._toddlers.map((t) {
                      final id = "${t["_id"]}";
                      final selected = selectedIds.contains(id);

                      return CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: selected,
                        onChanged: (v) {
                          setBottomState(() {
                            if (v == true) {
                              selectedIds.add(id);
                            } else {
                              selectedIds.remove(id);
                            }
                          });
                        },
                        title: Text("${t["name"] ?? "Toddler"}"),
                        subtitle: Text(
                          "Age ${t["age"] ?? 0}",
                          style: const TextStyle(fontSize: 12),
                        ),
                        controlAffinity: ListTileControlAffinity.leading,
                      );
                    }),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: green,
                        foregroundColor: dark,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () async {
                        Navigator.pop(context);
                        try {
                          await ApiService.assignStory(
                            storyId: "${story["_id"]}",
                            assignToAll: assignToAll,
                            toddlerIds: selectedIds.toList(),
                          );
                          _showSnack("Story assigned successfully.");
                          await _loadAll();
                        } catch (e) {
                          _showSnack(e.toString());
                        }
                      },
                      child: const Text(
                        "Save Assignment",
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _playOrStopStory(Map<String, dynamic> story) async {
    final storyId = "${story["_id"]}";

    if (_currentlyPlayingId == storyId) {
      await _player.stop();
      if (mounted) {
        setState(() {
          _currentlyPlayingId = null;
        });
      }
      return;
    }

    try {
      final url = ApiService.storyAudioUrl(storyId);
      final headers = await ApiService.getAuthHeaders();

      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      );

      if (response.statusCode != 200) {
        throw "Failed to load audio";
      }

      final dir = await getTemporaryDirectory();
      final filePath = "${dir.path}/story_play_$storyId.m4a";
      final file = File(filePath);

      await file.writeAsBytes(response.bodyBytes, flush: true);

      await _player.stop();
      await _player.play(
        DeviceFileSource(file.path),
      );

      if (mounted) {
        setState(() {
          _currentlyPlayingId = storyId;
        });
      }
    } catch (e) {
      _showSnack("Unable to play story: $e");
    }
  }

  String _formatDuration(int seconds) {
    final min = seconds ~/ 60;
    final sec = seconds % 60;
    return "$min:${sec.toString().padLeft(2, '0')}";
  }

  String _bigMinutes() => _stopwatch.elapsed.inMinutes.toString().padLeft(2, '0');
  String _bigSeconds() => (_stopwatch.elapsed.inSeconds % 60).toString().padLeft(2, '0');

  String _storySubtitle(Map<String, dynamic> story) {
    final duration = _formatDuration((story["durationSec"] ?? 0) as int);
    final date = DateTime.tryParse("${story["createdAt"] ?? ""}");
    final suffix = story["isDraft"] == true
        ? "Draft"
        : date == null
        ? ""
        : "${date.day}-${date.month}-${date.year}";
    return suffix.isEmpty ? duration : "$duration • $suffix";
  }

  IconData _storyIcon(Map<String, dynamic> story) {
    final title = "${story["title"] ?? ""}".toLowerCase();
    if (title.contains("twinkle")) return Icons.music_note_rounded;
    if (story["isDraft"] == true) return Icons.description_outlined;
    return Icons.menu_book_outlined;
  }

  Color _storyIconBg(Map<String, dynamic> story) {
    final icon = _storyIcon(story);
    if (icon == Icons.music_note_rounded) return const Color(0xFFF0E3FF);
    if (icon == Icons.description_outlined) return const Color(0xFFE2EEFF);
    return const Color(0xFFFCEADE);
  }

  Widget _buildStoryCard(Map<String, dynamic> story) {
    final storyId = "${story["_id"]}";
    final assignedToAll = story["assignedToAll"] == true;
    final assignedToddlerIds = (story["assignedToddlerIds"] as List?) ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _storyIconBg(story),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _storyIcon(story),
                  size: 20,
                  color: _storyIcon(story) == Icons.music_note_rounded
                      ? const Color(0xFFAE71FF)
                      : _storyIcon(story) == Icons.description_outlined
                      ? const Color(0xFF6AA5FF)
                      : const Color(0xFFF09952),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "${story["title"] ?? "Untitled"}",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: dark,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _storySubtitle(story),
                      style: const TextStyle(
                        color: lightText,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                color: Colors.white,
                icon: const Icon(Icons.more_vert, color: Color(0xFF95A1B2)),
                onSelected: (value) async {
                  if (value == "edit") {
                    await _editStory(story);
                  } else if (value == "delete") {
                    final ok = await _confirmDelete();
                    if (ok == true) {
                      await _deleteStory(storyId);
                    }
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: "edit",
                    child: Text("Edit"),
                  ),
                  PopupMenuItem(
                    value: "delete",
                    child: Text("Delete"),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _smallActionButton(
                icon: _currentlyPlayingId == storyId ? Icons.stop : Icons.play_arrow_rounded,
                onTap: () => _playOrStopStory(story),
              ),
              const SizedBox(width: 8),
              _smallActionButton(
                icon: Icons.close_rounded,
                onTap: () async {
                  if (_currentlyPlayingId == storyId) {
                    await _player.stop();
                    setState(() => _currentlyPlayingId = null);
                  }
                },
              ),
              const SizedBox(width: 8),
              _smallActionButton(
                icon: Icons.delete_outline,
                onTap: () async {
                  final ok = await _confirmDelete();
                  if (ok == true) {
                    await _deleteStory(storyId);
                  }
                },
              ),
              const Spacer(),
              InkWell(
                onTap: () => _assignStory(story),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                    color: assignedToAll ? const Color(0xFF24C768) : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: assignedToAll ? const Color(0xFF24C768) : const Color(0xFFDADFE6),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.person_add_alt_1_outlined,
                        size: 16,
                        color: assignedToAll ? Colors.white : dark,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        assignedToAll
                            ? "Assign to All"
                            : assignedToddlerIds.isNotEmpty
                            ? "Assigned (${assignedToddlerIds.length})"
                            : "Assign",
                        style: TextStyle(
                          color: assignedToAll ? Colors.white : dark,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _smallActionButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: Container(
        width: 31,
        height: 31,
        decoration: BoxDecoration(
          color: const Color(0xFFF2F4F7),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Icon(icon, size: 16, color: const Color(0xFF485262)),
      ),
    );
  }

  Future<bool?> _confirmDelete() {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Delete Story"),
          content: const Text("Are you sure you want to delete this story?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Delete"),
            ),
          ],
        );
      },
    );
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      bottomNavigationBar: _ParentBottomBar(
        activeIndex: 0,
        onHomeTap: widget.onHomeTap ??
                () {
              Navigator.pop(context);
            },
        onActivityTap: widget.onActivityTap,
        onBookmarkTap: widget.onBookmarkTap,
        onSettingsTap: widget.onSettingsTap ??
                () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ParentSettingScreen(
                    onHomeTap: () {
                      Navigator.pop(context);
                    },
                    onActivityTap: () {
                      Navigator.pop(context);
                    },
                    onBookmarkTap: () {},
                    onSettingsTap: () {},
                    onCenterTap: () {},
                  ),
                ),
              );
            },
        onCenterTap: widget.onCenterTap,
      ),
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: dark, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Story Studio",
          style: TextStyle(
            color: dark,
            fontSize: 20,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadAll,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              decoration: BoxDecoration(
                color: card,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: border),
              ),
              child: Column(
                children: [
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        color: dark,
                        fontWeight: FontWeight.w800,
                        fontSize: 28,
                        letterSpacing: 0.5,
                      ),
                      children: [
                        TextSpan(text: _bigMinutes()),
                        const TextSpan(text: " : "),
                        TextSpan(text: _bigSeconds()),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 70,
                        child: Text(
                          "MINUTES",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: lightText,
                            fontSize: 10,
                            letterSpacing: 1,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      SizedBox(width: 16),
                      SizedBox(
                        width: 70,
                        child: Text(
                          "SECONDS",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: lightText,
                            fontSize: 10,
                            letterSpacing: 1,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    _isRecording
                        ? "Recording in progress..."
                        : "Tap to start recording a story",
                    style: const TextStyle(
                      color: Color(0xFF5E6673),
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 18),
                  GestureDetector(
                    onTap: _toggleRecording,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        color: _isRecording ? const Color(0xFF22C55E) : green,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.14),
                            blurRadius: 14,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Icon(
                        _isRecording ? Icons.stop_rounded : Icons.mic_none_rounded,
                        color: dark,
                        size: 34,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                const Text(
                  "My Stories",
                  style: TextStyle(
                    color: dark,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {},
                  child: const Text(
                    "View All",
                    style: TextStyle(
                      color: Color(0xFF33C766),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.only(top: 40),
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_stories.isEmpty)
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: border),
                ),
                child: const Text(
                  "No stories yet. Record your first story.",
                  style: TextStyle(
                    fontSize: 14,
                    color: lightText,
                  ),
                ),
              )
            else
              ..._stories.map(_buildStoryCard),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _ParentBottomBar extends StatelessWidget {
  final int activeIndex;
  final VoidCallback? onHomeTap;
  final VoidCallback? onActivityTap;
  final VoidCallback? onBookmarkTap;
  final VoidCallback? onSettingsTap;
  final VoidCallback? onCenterTap;

  static const Color green = Color(0xFF22C55E);

  const _ParentBottomBar({
    required this.activeIndex,
    this.onHomeTap,
    this.onActivityTap,
    this.onBookmarkTap,
    this.onSettingsTap,
    this.onCenterTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 78,
      padding: const EdgeInsets.only(left: 18, right: 18, bottom: 10, top: 10),
      decoration: const BoxDecoration(
        color: Color(0xFF0F1D14),
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _NavIcon(
                icon: Icons.home_rounded,
                active: activeIndex == 0,
                onTap: onHomeTap,
              ),
              _NavIcon(
                icon: Icons.bar_chart_rounded,
                active: activeIndex == 1,
                onTap: onActivityTap,
              ),
              const SizedBox(width: 46),
              _NavIcon(
                icon: Icons.bookmark_border_rounded,
                active: activeIndex == 2,
                onTap: onBookmarkTap,
              ),
              _NavIcon(
                icon: Icons.settings_rounded,
                active: activeIndex == 3,
                onTap: onSettingsTap,
              ),
            ],
          ),
          Positioned(
            bottom: 10,
            child: _Pressable(
              onTap: onCenterTap,
              borderRadius: BorderRadius.circular(999),
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: green,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: green.withOpacity(0.35),
                      blurRadius: 18,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Icon(Icons.add_rounded, color: Colors.white, size: 26),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavIcon extends StatelessWidget {
  final IconData icon;
  final bool active;
  final VoidCallback? onTap;

  const _NavIcon({
    required this.icon,
    required this.active,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _Pressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: 34,
        height: 34,
        child: Icon(
          icon,
          size: 22,
          color: active ? const Color(0xFF22C55E) : Colors.white70,
        ),
      ),
    );
  }
}

class _Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final BorderRadius borderRadius;

  const _Pressable({
    required this.child,
    this.onTap,
    required this.borderRadius,
  });

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool _down = false;

  void _setDown(bool v) {
    if (!mounted) return;
    setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _down ? 0.98 : 1,
      duration: const Duration(milliseconds: 110),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: widget.borderRadius,
          onTap: widget.onTap,
          onTapDown: (_) => _setDown(true),
          onTapUp: (_) => _setDown(false),
          onTapCancel: () => _setDown(false),
          child: widget.child,
        ),
      ),
    );
  }
}