import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'services/api_service.dart';

class ParentDashboardScreen extends StatefulWidget {
  final String parentName;
  const ParentDashboardScreen({super.key, required this.parentName});

  @override
  State<ParentDashboardScreen> createState() => _ParentDashboardScreenState();
}

class _ParentDashboardScreenState extends State<ParentDashboardScreen>
    with TickerProviderStateMixin {
  // Green + White theme
  static const Color bg = Color(0xFFF4FFF6);
  static const Color green = Color(0xFF27C267);
  static const Color greenDark = Color(0xFF179C4C);
  static const Color dark = Color(0xFF14201A);
  static const Color grey = Color(0xFF6E7B80);
  static const Color border = Color(0xFFE2EFE7);

  bool loading = true;
  List<dynamic> toddlers = [];
  String? activeToddlerId;

  double speechAccuracy = 0; // 0-100
  String progressNote = "Loading...";
  bool progressLoading = false;

  // ✅ Safe from LateInitializationError
  AnimationController? _pulseController;
  Animation<double> _pulseScale = const AlwaysStoppedAnimation(1.0);

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _pulseScale = Tween<double>(begin: 0.96, end: 1.03).animate(
      CurvedAnimation(
        parent: _pulseController!,
        curve: Curves.easeInOut,
      ),
    );

    _loadToddlers();
  }

  @override
  void dispose() {
    _pulseController?.dispose();
    super.dispose();
  }

  Future<void> _loadToddlers() async {
    setState(() => loading = true);
    try {
      final list = await ApiService.getToddlers();
      toddlers = list;

      final active = toddlers.cast<Map>().firstWhere(
            (t) => (t["isActive"] == true),
        orElse: () => toddlers.isNotEmpty ? toddlers[0] : {},
      );

      if (toddlers.isNotEmpty) {
        activeToddlerId = (active["_id"] ?? active["\u005fid"]).toString();
        await _loadProgress(activeToddlerId!);
      } else {
        activeToddlerId = null;
        speechAccuracy = 0;
        progressNote = "Add a child to see progress.";
      }
    } catch (e) {
      _toast("Failed: $e");
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _loadProgress(String toddlerId) async {
    setState(() => progressLoading = true);
    try {
      final p = await ApiService.getToddlerProgress(toddlerId);
      speechAccuracy = (p["speechAccuracy"] ?? 0).toDouble();
      progressNote = (p["note"] ?? "").toString();
      if (progressNote.trim().isEmpty) {
        progressNote = "Keep going — small steps, big progress!";
      }
    } catch (e) {
      _toast("Progress error: $e");
    } finally {
      if (mounted) setState(() => progressLoading = false);
    }
  }

  Future<void> _setActiveToddler(String toddlerId) async {
    try {
      HapticFeedback.selectionClick();
      await ApiService.setActiveToddler(toddlerId);
      activeToddlerId = toddlerId;

      for (final t in toddlers) {
        final id = (t["_id"] ?? t["\u005fid"]).toString();
        t["isActive"] = (id == toddlerId);
      }

      setState(() {});
      await _loadProgress(toddlerId);
    } catch (e) {
      _toast("Failed: $e");
    }
  }

  String _activeName() {
    if (activeToddlerId == null) return "No Child";
    final found = toddlers.cast<Map>().firstWhere(
          (t) => ((t["_id"] ?? t["\u005fid"]).toString() == activeToddlerId),
      orElse: () => {},
    );
    return (found["name"] ?? "Child").toString();
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

  // -------------------- ADD CHILD (interactive) --------------------

  Future<void> _addChildFlow() async {
    HapticFeedback.lightImpact();
    final res = await showModalBottomSheet<_ChildFormResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AddChildSheet(),
    );

    if (res == null) return;

    try {
      HapticFeedback.mediumImpact();
      await ApiService.createToddler(
        name: res.name,
        schoolName: res.schoolName,
        className: res.className,
        age: res.age,
        photoFile: res.imageFile,
      );

      // reload list (will include photoUrl)
      await _loadToddlers();
      _toast("Child added: ${res.name}");
    } catch (e) {
      _toast("Add child failed: $e");
    }
  }

  // -------------------- UI --------------------

  @override
  Widget build(BuildContext context) {
    final activeName = _activeName();
    final percentText = "${speechAccuracy.toStringAsFixed(0)}%";
    final progressValue = (speechAccuracy.clamp(0, 100)) / 100;

    return Theme(
      data: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: bg,
        colorScheme: ColorScheme.fromSeed(seedColor: green).copyWith(
          primary: green,
          secondary: greenDark,
          surface: Colors.white,
          onSurface: dark,
        ),
        splashFactory: InkSparkle.splashFactory,
      ),
      child: Scaffold(
        backgroundColor: bg,
        bottomNavigationBar: _BottomNav(
          onCenterTap: () {
            HapticFeedback.lightImpact();
            _toast("Center + tapped");
          },
        ),
        body: SafeArea(
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
            color: green,
            backgroundColor: Colors.white,
            onRefresh: _loadToddlers,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        Expanded(
                          child: RichText(
                            text: TextSpan(
                              style: const TextStyle(
                                color: dark,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                height: 1.1,
                              ),
                              children: [
                                const TextSpan(text: "Assalam-o-Alaikum,\n"),
                                TextSpan(
                                  text: widget.parentName,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                    color: green,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        _GlowIconButton(
                          icon: Icons.notifications_none_rounded,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            _toast("Notifications");
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // Switch profile row
                    Row(
                      children: [
                        const Text(
                          "Switch Profile",
                          style: TextStyle(
                            color: dark,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const Spacer(),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: green.withOpacity(0.10),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: green.withOpacity(0.18), width: 1),
                          ),
                          child: Text(
                            toddlers.isEmpty ? "No Child" : "Managing $activeName",
                            style: const TextStyle(
                              color: greenDark,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Toddlers row
                    SizedBox(
                      height: 110,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          ...toddlers.map((t) {
                            final id = (t["_id"] ?? t["\u005fid"]).toString();
                            final name = (t["name"] ?? "Child").toString();
                            final active = (id == activeToddlerId);

                            // ✅ FIX: server returns `photoUrl` not `imageUrl`
                            final rawPhoto = (t["photoUrl"] ?? t["imageUrl"] ?? "").toString();
                            final photoUrl = rawPhoto.isEmpty ? null : ApiService.absoluteUrl(rawPhoto);

                            return Padding(
                              padding: const EdgeInsets.only(right: 14),
                              child: _ToddlerAvatar(
                                name: name,
                                imageUrl: photoUrl,
                                active: active,
                                onTap: () => _setActiveToddler(id),
                                onLongPress: () {
                                  HapticFeedback.lightImpact();
                                  _toast("Hold: $name");
                                },
                              ),
                            );
                          }),
                          _AddChildAvatar(onTap: _addChildFlow),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Current progress header
                    Row(
                      children: [
                        const Text(
                          "Current Progress",
                          style: TextStyle(color: dark, fontSize: 14, fontWeight: FontWeight.w900),
                        ),
                        const Spacer(),
                        _TextChipButton(
                          label: "See Analytics",
                          onTap: () {
                            HapticFeedback.selectionClick();
                            _toast("Analytics");
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // Progress card
                    _PressableCard(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        _toast("Open progress details");
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: border),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Colors.white, green.withOpacity(0.06)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 18,
                              offset: const Offset(0, 12),
                            )
                          ],
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: green.withOpacity(0.10),
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(color: green.withOpacity(0.18)),
                                    ),
                                    child: const Text(
                                      "SPEECH ACCURACY",
                                      style: TextStyle(
                                        color: greenDark,
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        percentText,
                                        style: const TextStyle(
                                          color: dark,
                                          fontSize: 28,
                                          fontWeight: FontWeight.w900,
                                          height: 1,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Padding(
                                        padding: EdgeInsets.only(bottom: 3),
                                        child: Icon(Icons.trending_up_rounded, color: green, size: 18),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 250),
                                    child: Text(
                                      progressLoading ? "Loading..." : progressNote,
                                      key: ValueKey(progressLoading ? "loading" : progressNote),
                                      style: const TextStyle(
                                        color: grey,
                                        fontSize: 12.8,
                                        fontWeight: FontWeight.w700,
                                        height: 1.25,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _PrimaryButton(
                                          label: "View Details",
                                          icon: Icons.arrow_forward_rounded,
                                          onTap: () {
                                            HapticFeedback.mediumImpact();
                                            _toast("View Details");
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 14),
                            SizedBox(
                              width: 74,
                              height: 74,
                              child: Stack(
                                children: [
                                  Center(
                                    child: TweenAnimationBuilder<double>(
                                      tween: Tween<double>(begin: 0, end: progressValue),
                                      duration: const Duration(milliseconds: 650),
                                      curve: Curves.easeOutCubic,
                                      builder: (_, v, __) {
                                        return CircularProgressIndicator(
                                          value: v,
                                          strokeWidth: 8,
                                          backgroundColor: const Color(0xFFE6F6EA),
                                          color: green,
                                        );
                                      },
                                    ),
                                  ),
                                  Center(
                                    child: ScaleTransition(
                                      scale: _pulseScale,
                                      child: Container(
                                        width: 38,
                                        height: 38,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: green.withOpacity(0.12),
                                          border: Border.all(color: green.withOpacity(0.25)),
                                        ),
                                        child: const Icon(Icons.record_voice_over_rounded, color: green),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    const Text(
                      "Start an Activity",
                      style: TextStyle(color: dark, fontSize: 14, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: _ActivityCard(
                            icon: Icons.quiz_outlined,
                            title: "Mockup Test",
                            subtitle: "Child Quiz",
                            bg: const Color(0xFFFFFFFF),
                            iconBg: green,
                            borderColor: border,
                            onTap: () {
                              HapticFeedback.selectionClick();
                              _toast("Mockup Test");
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _ActivityCard(
                            icon: Icons.videogame_asset_rounded,
                            title: "Games",
                            subtitle: "Play Time",
                            bg: const Color(0xFFFFFFFF),
                            iconBg: green,
                            borderColor: border,
                            onTap: () {
                              HapticFeedback.selectionClick();
                              _toast("Games");
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _ActivityCard(
                            icon: Icons.mic_rounded,
                            title: "Story Telling",
                            subtitle: "Stories for Child",
                            bg: const Color(0xFFFFFFFF),
                            iconBg: green,
                            borderColor: border,
                            onTap: () {
                              HapticFeedback.selectionClick();
                              _toast("Story Telling");
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _ActivityCard(
                            icon: Icons.article_rounded,
                            title: "News",
                            subtitle: "Read & Listen",
                            bg: const Color(0xFFFFFFFF),
                            iconBg: green,
                            borderColor: border,
                            onTap: () {
                              HapticFeedback.selectionClick();
                              _toast("News");
                            },
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 22),

                    Text(
                      "Active: $activeName",
                      style: const TextStyle(color: grey, fontSize: 12.5, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// -------------------- Add Child Sheet --------------------

class _ChildFormResult {
  final String name;
  final String schoolName;
  final String className;
  final int age;
  final File? imageFile;

  const _ChildFormResult({
    required this.name,
    required this.schoolName,
    required this.className,
    required this.age,
    required this.imageFile,
  });
}

class _AddChildSheet extends StatefulWidget {
  const _AddChildSheet();

  @override
  State<_AddChildSheet> createState() => _AddChildSheetState();
}

class _AddChildSheetState extends State<_AddChildSheet> {
  static const Color green = Color(0xFF27C267);
  static const Color dark = Color(0xFF14201A);
  static const Color grey = Color(0xFF6E7B80);

  final _name = TextEditingController();
  final _school = TextEditingController();
  final _className = TextEditingController();
  final _age = TextEditingController();

  File? pickedImage;
  bool saving = false;

  @override
  void dispose() {
    _name.dispose();
    _school.dispose();
    _className.dispose();
    _age.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    HapticFeedback.selectionClick();
    final picker = ImagePicker();
    final x = await picker.pickImage(source: ImageSource.gallery, imageQuality: 75);
    if (x == null) return;
    setState(() => pickedImage = File(x.path));
  }

  void _submit() {
    final name = _name.text.trim();
    final school = _school.text.trim();
    final cls = _className.text.trim();
    final ageStr = _age.text.trim();

    if (name.isEmpty || school.isEmpty || cls.isEmpty || ageStr.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all fields")),
      );
      return;
    }

    final age = int.tryParse(ageStr);
    if (age == null || age < 1 || age > 12) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a valid age (1-12)")),
      );
      return;
    }

    HapticFeedback.mediumImpact();
    Navigator.pop(
      context,
      _ChildFormResult(
        name: name,
        schoolName: school,
        className: cls,
        age: age,
        imageFile: pickedImage,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 220),
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    "Add Child Details",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: dark),
                  ),
                  const Spacer(),
                  _GlowIconButton(
                    icon: Icons.close_rounded,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      Navigator.pop(context);
                    },
                    size: 40,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Center(
                child: _Pressable(
                  onTap: _pickImage,
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    width: 98,
                    height: 98,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFF3FBF6),
                      border: Border.all(color: green.withOpacity(0.35), width: 1.6),
                    ),
                    child: ClipOval(
                      child: pickedImage == null
                          ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.add_a_photo_outlined, color: grey),
                          SizedBox(height: 4),
                          Text(
                            "Add Photo",
                            style: TextStyle(color: grey, fontSize: 11.5, fontWeight: FontWeight.w800),
                          )
                        ],
                      )
                          : Image.file(pickedImage!, fit: BoxFit.cover),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _Field(controller: _name, hint: "Child full name", icon: Icons.person_outline),
              const SizedBox(height: 10),
              _Field(controller: _school, hint: "School name", icon: Icons.school_outlined),
              const SizedBox(height: 10),
              _Field(controller: _className, hint: "Class (e.g., KG-1)", icon: Icons.class_outlined),
              const SizedBox(height: 10),
              _Field(
                controller: _age,
                hint: "Age (e.g., 5)",
                icon: Icons.cake_outlined,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: green,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: saving ? null : _submit,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.save_rounded, color: Colors.white, size: 18),
                      SizedBox(width: 10),
                      Text("Save Child", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;

  const _Field({
    required this.controller,
    required this.hint,
    required this.icon,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2EFE7)),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: Color(0xFF14201A)),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Color(0xFF9AA6AC), fontWeight: FontWeight.w600, fontSize: 13.5),
          prefixIcon: Icon(icon, color: const Color(0xFF9AA6AC), size: 22),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
      ),
    );
  }
}

// ---------------- UI widgets ----------------

class _ToddlerAvatar extends StatelessWidget {
  final String name;
  final String? imageUrl; // ✅ absolute url
  final bool active;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  static const Color green = Color(0xFF27C267);
  static const Color greenDark = Color(0xFF179C4C);
  static const Color dark = Color(0xFF14201A);
  static const Color grey = Color(0xFF6E7B80);

  const _ToddlerAvatar({
    required this.name,
    required this.active,
    required this.onTap,
    this.onLongPress,
    this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    final initials = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : "C";

    Widget innerAvatar;
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      // ✅ Photo endpoint is protected => add Authorization header
      innerAvatar = FutureBuilder<String?>(
        future: ApiService.getToken(),
        builder: (context, snap) {
          final token = snap.data;
          return ClipOval(
            child: SizedBox(
              width: double.infinity,
              height: double.infinity,
              child: Image.network(
                imageUrl!,
                fit: BoxFit.cover,
                headers: token == null ? null : {"Authorization": "Bearer $token"},
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                },
                errorBuilder: (_, __, ___) => Center(
                  child: Text(
                    initials,
                    style: TextStyle(
                      color: active ? greenDark : dark,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );
    } else {
      innerAvatar = Center(
        child: Text(
          initials,
          style: TextStyle(color: active ? greenDark : dark, fontWeight: FontWeight.w900, fontSize: 18),
        ),
      );
    }

    return _Pressable(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(18),
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            width: 58,
            height: 58,
            padding: const EdgeInsets.all(2.2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: active ? const LinearGradient(colors: [green, greenDark]) : null,
              color: active ? null : const Color(0xFFF1FAF4),
              boxShadow: [
                BoxShadow(
                  color: active ? green.withOpacity(0.25) : Colors.black.withOpacity(0.06),
                  blurRadius: active ? 18 : 10,
                  offset: const Offset(0, 8),
                )
              ],
            ),
            child: Container(
              decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
              clipBehavior: Clip.antiAlias,
              child: innerAvatar,
            ),
          ),
          const SizedBox(height: 7),
          SizedBox(
            width: 68,
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: active ? dark : grey,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 2),
          AnimatedOpacity(
            opacity: active ? 1 : 0,
            duration: const Duration(milliseconds: 180),
            child: const Text("Active", style: TextStyle(color: greenDark, fontSize: 11, fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }
}

class _AddChildAvatar extends StatelessWidget {
  final VoidCallback onTap;
  static const Color grey = Color(0xFF6E7B80);
  static const Color green = Color(0xFF27C267);

  const _AddChildAvatar({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _Pressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFCBD5D1), width: 1.6),
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: green.withOpacity(0.10),
                  blurRadius: 14,
                  offset: const Offset(0, 8),
                )
              ],
            ),
            child: const Icon(Icons.add_rounded, color: grey),
          ),
          const SizedBox(height: 7),
          const SizedBox(
            width: 70,
            child: Text(
              "Add Child",
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(color: grey, fontSize: 12, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color bg;
  final Color iconBg;
  final Color borderColor;
  final VoidCallback onTap;

  static const Color dark = Color(0xFF14201A);
  static const Color grey = Color(0xFF6E7B80);

  const _ActivityCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.bg,
    required this.iconBg,
    required this.borderColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _PressableCard(
      onTap: onTap,
      child: Container(
        height: 108,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(
              color: iconBg.withOpacity(0.08),
              blurRadius: 16,
              offset: const Offset(0, 10),
            )
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: iconBg,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: iconBg.withOpacity(0.20),
                    blurRadius: 14,
                    offset: const Offset(0, 10),
                  )
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(title, style: const TextStyle(color: dark, fontSize: 14.5, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(color: grey, fontSize: 11.5, fontWeight: FontWeight.w800)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF9FB1A8)),
          ],
        ),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final VoidCallback onCenterTap;
  static const Color green = Color(0xFF27C267);

  const _BottomNav({required this.onCenterTap});

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
              _NavIcon(icon: Icons.home_rounded, active: true, onTap: () => HapticFeedback.selectionClick()),
              _NavIcon(icon: Icons.bar_chart_rounded, active: false, onTap: () => HapticFeedback.selectionClick()),
              const SizedBox(width: 46),
              _NavIcon(icon: Icons.bookmark_border_rounded, active: false, onTap: () => HapticFeedback.selectionClick()),
              _NavIcon(icon: Icons.settings_rounded, active: false, onTap: () => HapticFeedback.selectionClick()),
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
                    )
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
  final VoidCallback onTap;

  const _NavIcon({required this.icon, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = active ? const Color(0xFF27C267) : Colors.white54;
    return _Pressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Icon(icon, color: c),
      ),
    );
  }
}

// -------------------- micro-interactions helpers --------------------

class _Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final BorderRadius borderRadius;

  const _Pressable({
    required this.child,
    required this.onTap,
    required this.borderRadius,
    this.onLongPress,
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
      curve: Curves.easeOut,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: widget.borderRadius,
          onTap: widget.onTap,
          onLongPress: widget.onLongPress,
          onTapDown: (_) => _setDown(true),
          onTapCancel: () => _setDown(false),
          onTapUp: (_) => _setDown(false),
          child: widget.child,
        ),
      ),
    );
  }
}

class _PressableCard extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;

  const _PressableCard({required this.child, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _Pressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: child,
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  static const Color green = Color(0xFF27C267);

  const _PrimaryButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _Pressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          gradient: const LinearGradient(colors: [green, Color(0xFF179C4C)]),
          boxShadow: [
            BoxShadow(
              color: green.withOpacity(0.25),
              blurRadius: 16,
              offset: const Offset(0, 10),
            )
          ],
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13),
              ),
              const SizedBox(width: 8),
              Icon(icon, color: Colors.white, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _TextChipButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  static const Color green = Color(0xFF27C267);

  const _TextChipButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _Pressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: green.withOpacity(0.10),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: green.withOpacity(0.16)),
        ),
        child: Text(
          label,
          style: const TextStyle(color: green, fontSize: 12.5, fontWeight: FontWeight.w900),
        ),
      ),
    );
  }
}

class _GlowIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double size;

  static const Color green = Color(0xFF27C267);

  const _GlowIconButton({
    required this.icon,
    required this.onTap,
    this.size = 44,
  });

  @override
  Widget build(BuildContext context) {
    return _Pressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFE2EFE7)),
          boxShadow: [
            BoxShadow(
              color: green.withOpacity(0.10),
              blurRadius: 14,
              offset: const Offset(0, 10),
            )
          ],
        ),
        child: Icon(icon, color: const Color(0xFF14201A)),
      ),
    );
  }
}
