import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/api_service.dart';
import '../startup_screens/login_screen.dart';

class TeacherSettingScreen extends StatefulWidget {
  const TeacherSettingScreen({super.key});

  @override
  State<TeacherSettingScreen> createState() => _TeacherSettingScreenState();
}

class _TeacherSettingScreenState extends State<TeacherSettingScreen> {
  static const Color dark = Color(0xFF111827);
  static const Color grey = Color(0xFF6B7280);
  static const Color border = Color(0xFFE5E7EB);
  static const Color green = Color(0xFF22C55E);

  static const Color navBg = Color(0xFF0B1220);
  static const Color navInactive = Color(0xFF9CA3AF);

  bool loading = true;
  bool uploading = false;

  int _navIndex = 3;
  Map<String, dynamic>? me;

  // toggles (UI only)
  bool allowAudio = true;
  bool contributeSpeech = true;
  bool enableFaceId = true;

  // ✅ token cache for authenticated images
  String? _token;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _token = await ApiService.getToken(); // ✅ read token once
    await _loadMe();
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

  Future<void> _loadMe() async {
    setState(() => loading = true);
    try {
      final data = await ApiService.getMe();
      setState(() => me = data["user"] as Map<String, dynamic>?);
    } catch (e) {
      _toast("$e");
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  String get _name => (me?["name"] ?? "Teacher").toString();
  String get _email => (me?["email"] ?? "").toString();
  String get _photoUrl => (me?["photoUrl"] ?? "").toString();
  bool get _hasPhoto => (me?["hasPhoto"] ?? false) == true;

  // ✅ FIXED: compress + resize image before upload
  Future<void> _pickAndUploadImage() async {
    if (uploading) return;

    try {
      final picker = ImagePicker();

      final XFile? x = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 65,
        maxWidth: 800,
        maxHeight: 800,
      );

      if (x == null) return;

      final file = File(x.path);
      if (!await file.exists()) {
        _toast("Selected image not found.");
        return;
      }

      setState(() => uploading = true);

      await ApiService.uploadMyProfilePhoto(photoFile: file);

      // refresh token (in case cleared) + reload profile
      _token = await ApiService.getToken();
      await _loadMe();

      // ✅ force refresh image cache for the same URL
      if (mounted) {
        imageCache.clear();
        imageCache.clearLiveImages();
      }

      _toast("Profile photo updated");
    } catch (e) {
      _toast("Upload failed: $e");
    } finally {
      if (mounted) setState(() => uploading = false);
    }
  }

  Future<void> _openChangePassword() async {
    final oldCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();

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
                  decoration: BoxDecoration(color: const Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(99)),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        "Change Password",
                        style: TextStyle(color: dark, fontSize: 15, fontWeight: FontWeight.w900),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context, false),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _passwordField(controller: oldCtrl, label: "Current Password"),
                const SizedBox(height: 10),
                _passwordField(controller: newCtrl, label: "New Password"),
                const SizedBox(height: 10),
                _passwordField(controller: confirmCtrl, label: "Confirm New Password"),
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
                        text: "Update",
                        onTap: () async {
                          final oldPass = oldCtrl.text.trim();
                          final newPass = newCtrl.text.trim();
                          final confirm = confirmCtrl.text.trim();

                          if (oldPass.isEmpty || newPass.isEmpty || confirm.isEmpty) {
                            _toast("Please fill all fields");
                            return;
                          }
                          if (newPass != confirm) {
                            _toast("New password and confirmation do not match");
                            return;
                          }

                          try {
                            await ApiService.changeMyPassword(
                              currentPassword: oldPass,
                              newPassword: newPass,
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
            ),
          ),
        );
      },
    );

    if (ok == true) _toast("Password updated");
  }

  Future<void> _logout() async {
    await ApiService.clearToken();
    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
          (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final authHeaders = (_token == null || _token!.isEmpty)
        ? const <String, String>{}
        : <String, String>{"Authorization": "Bearer $_token"};

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
            onRefresh: _loadMe,
            color: green,
            backgroundColor: Colors.white,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              children: [
                const Text(
                  "Profile & Settings",
                  style: TextStyle(color: dark, fontWeight: FontWeight.w900, fontSize: 14.5),
                ),
                const SizedBox(height: 14),

                Center(
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: _pickAndUploadImage,
                        child: Stack(
                          children: [
                            Container(
                              width: 86,
                              height: 86,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: const Color(0xFFE5E7EB), width: 2),
                                color: const Color(0xFFF3F4F6),
                              ),
                              child: ClipOval(
                                child: (_hasPhoto && _photoUrl.trim().isNotEmpty)
                                    ? Image.network(
                                  ApiService.absoluteUrl(_photoUrl),
                                  fit: BoxFit.cover,
                                  headers: authHeaders, // ✅ IMPORTANT FIX
                                  errorBuilder: (_, __, ___) => Container(color: const Color(0xFFF3F4F6)),
                                )
                                    : Container(color: const Color(0xFFF3F4F6)),
                              ),
                            ),
                            Positioned(
                              right: 4,
                              bottom: 4,
                              child: Container(
                                width: 22,
                                height: 22,
                                decoration: const BoxDecoration(color: green, shape: BoxShape.circle),
                                child: uploading
                                    ? const Padding(
                                  padding: EdgeInsets.all(4),
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                                    : const Icon(Icons.check_rounded, color: Colors.white, size: 16),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(_name, style: const TextStyle(color: dark, fontWeight: FontWeight.w900, fontSize: 14)),
                      const SizedBox(height: 3),
                      Text(_email, style: const TextStyle(color: grey, fontWeight: FontWeight.w700, fontSize: 12)),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8FFF2),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: const Color(0xFFBBF7D0)),
                        ),
                        child: const Text(
                          "TEACHER ACCOUNT",
                          style: TextStyle(color: green, fontWeight: FontWeight.w900, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                const Text("DATA & PRIVACY", style: TextStyle(color: grey, fontWeight: FontWeight.w900, fontSize: 11.5)),
                const SizedBox(height: 10),
                _card(
                  children: [
                    _switchRow(
                      icon: Icons.mic_rounded,
                      title: "Allow Child\nAudio Recording",
                      subtitle: "Audio is encrypted and\nused for better listening",
                      value: allowAudio,
                      onChanged: (v) => setState(() => allowAudio = v),
                    ),
                    const Divider(height: 1, color: border),
                    _switchRow(
                      icon: Icons.bar_chart_rounded,
                      title: "Contribute to\nSpeech Model",
                      subtitle: "Share anonymous data\nto improve it",
                      value: contributeSpeech,
                      onChanged: (v) => setState(() => contributeSpeech = v),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                const Text("APP PREFERENCES", style: TextStyle(color: grey, fontWeight: FontWeight.w900, fontSize: 11.5)),
                const SizedBox(height: 10),
                _card(
                  children: [
                    _arrowRow(
                      icon: Icons.library_books_rounded,
                      title: "Open News Summarization",
                      subtitle: "Detailed",
                      onTap: () => _toast("Coming soon"),
                    ),
                    const Divider(height: 1, color: border),
                    _arrowRow(
                      icon: Icons.mail_outline_rounded,
                      title: "Classroom Updates",
                      subtitle: "Daily Digest",
                      onTap: () => _toast("Coming soon"),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                const Text("SECURITY", style: TextStyle(color: grey, fontWeight: FontWeight.w900, fontSize: 11.5)),
                const SizedBox(height: 10),
                _card(
                  children: [
                    _arrowRow(
                      icon: Icons.lock_outline_rounded,
                      title: "Change Password",
                      subtitle: "",
                      onTap: _openChangePassword,
                    ),
                    const Divider(height: 1, color: border),
                    _switchRow(
                      icon: Icons.face_rounded,
                      title: "Enable FaceID",
                      subtitle: "",
                      value: enableFaceId,
                      onChanged: (v) => setState(() => enableFaceId = v),
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                Center(
                  child: TextButton.icon(
                    onPressed: _logout,
                    icon: const Icon(Icons.logout_rounded, color: Color(0xFFEF4444)),
                    label: const Text(
                      "Log Out",
                      style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w900),
                    ),
                  ),
                ),

                const SizedBox(height: 6),
                const Center(
                  child: Text(
                    "TinyWise v2.4.0",
                    style: TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.w700, fontSize: 11.5),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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
          _navItem(index: 0, icon: Icons.home_rounded, label: "Home", onTap: () => Navigator.pop(context, true)),
          _navItem(index: 1, icon: Icons.bar_chart_rounded, label: "Activity", onTap: () => _toast("Activity coming soon")),
          _navItem(index: 2, icon: Icons.group_outlined, label: "Students", onTap: () => Navigator.pop(context, true)),
          _navItem(index: 3, icon: Icons.settings_rounded, label: "Settings", onTap: () => setState(() => _navIndex = 3)),
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
      onTap: () {
        setState(() => _navIndex = index);
        onTap();
      },
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: 72,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  Widget _card({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [BoxShadow(color: Color(0x11000000), blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: Column(children: children),
    );
  }

  Widget _switchRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: dark, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: dark, fontWeight: FontWeight.w900, fontSize: 12.5)),
                if (subtitle.trim().isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(subtitle, style: const TextStyle(color: grey, fontWeight: FontWeight.w700, fontSize: 11.5)),
                ],
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged, activeColor: green),
        ],
      ),
    );
  }

  Widget _arrowRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: dark, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: dark, fontWeight: FontWeight.w900, fontSize: 12.5)),
                  if (subtitle.trim().isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(subtitle, style: const TextStyle(color: grey, fontWeight: FontWeight.w700, fontSize: 11.5)),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF9CA3AF)),
          ],
        ),
      ),
    );
  }

  Widget _passwordField({
    required TextEditingController controller,
    required String label,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: dark, fontWeight: FontWeight.w800, fontSize: 12.5)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: true,
          decoration: InputDecoration(
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
        child: Text(text, style: TextStyle(color: filled ? Colors.white : dark, fontWeight: FontWeight.w900, fontSize: 13)),
      ),
    );
  }
}