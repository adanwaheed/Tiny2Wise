import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/api_service.dart';
import '../startup_screens/login_screen.dart';

class ParentSettingScreen extends StatefulWidget {
  final VoidCallback? onHomeTap;
  final VoidCallback? onActivityTap;
  final VoidCallback? onBookmarkTap;
  final VoidCallback? onSettingsTap;
  final VoidCallback? onCenterTap;

  const ParentSettingScreen({
    super.key,
    this.onHomeTap,
    this.onActivityTap,
    this.onBookmarkTap,
    this.onSettingsTap,
    this.onCenterTap,
  });

  @override
  State<ParentSettingScreen> createState() => _ParentSettingScreenState();
}

class _ParentSettingScreenState extends State<ParentSettingScreen> {
  static const Color bg = Color(0xFFF4F5F6);
  static const Color dark = Color(0xFF1A1D1F);
  static const Color textGrey = Color(0xFF7B8087);
  static const Color border = Color(0xFFE7E9EC);
  static const Color green = Color(0xFF22C55E);
  static const Color lightGreen = Color(0xFFEAF8EF);
  static const Color red = Color(0xFFFF4D4F);

  bool _loading = true;
  bool _uploadingPhoto = false;
  bool _changingPassword = false;

  bool allowChildAudio = true;
  bool contributeSpeech = true;
  bool enableFaceId = true;

  String parentName = "";
  String parentEmail = "";
  Uint8List? _profileBytes;
  bool _hasPhoto = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      setState(() => _loading = true);

      final me = await ApiService.getMe();
      final user = (me["user"] as Map<String, dynamic>? ?? {});

      final name = (user["name"] ?? "").toString();
      final email = (user["email"] ?? "").toString();
      final hasPhoto = user["hasPhoto"] == true;

      Uint8List? bytes;
      if (hasPhoto) {
        bytes = await ApiService.getMyProfilePhotoBytes();
      }

      if (!mounted) return;
      setState(() {
        parentName = name;
        parentEmail = email;
        _hasPhoto = hasPhoto;
        _profileBytes = bytes;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _profileBytes = null;
        _hasPhoto = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _pickAndUploadImage() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (picked == null) return;

      setState(() => _uploadingPhoto = true);

      final file = File(picked.path);

      await ApiService.uploadMyProfilePhoto(photoFile: file);

      final localBytes = await file.readAsBytes();

      if (!mounted) return;
      setState(() {
        _profileBytes = localBytes;
        _hasPhoto = true;
      });

      await _loadProfile();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Profile image updated successfully")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) {
        setState(() => _uploadingPhoto = false);
      }
    }
  }

  Future<void> _logout() async {
    await ApiService.clearToken();

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
    );
  }

  Future<void> _showChangePasswordSheet() async {
    final currentController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();

    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> submit() async {
              final currentPassword = currentController.text.trim();
              final newPassword = newController.text.trim();
              final confirmPassword = confirmController.text.trim();

              if (currentPassword.isEmpty ||
                  newPassword.isEmpty ||
                  confirmPassword.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Please fill all fields")),
                );
                return;
              }

              if (newPassword != confirmPassword) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("New passwords do not match")),
                );
                return;
              }

              try {
                setState(() => _changingPassword = true);

                await ApiService.changeMyPassword(
                  currentPassword: currentPassword,
                  newPassword: newPassword,
                );

                if (!mounted) return;
                Navigator.pop(sheetContext);

                ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(content: Text("Password updated successfully")),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(this.context).showSnackBar(
                  SnackBar(content: Text(e.toString())),
                );
              } finally {
                if (mounted) {
                  setState(() => _changingPassword = false);
                }
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 18,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 5,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD7DBE0),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    "Change Password",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: dark,
                    ),
                  ),
                  const SizedBox(height: 18),
                  _PasswordField(
                    controller: currentController,
                    label: "Current Password",
                    obscureText: obscureCurrent,
                    onToggle: () {
                      setModalState(() => obscureCurrent = !obscureCurrent);
                    },
                  ),
                  const SizedBox(height: 12),
                  _PasswordField(
                    controller: newController,
                    label: "New Password",
                    obscureText: obscureNew,
                    onToggle: () {
                      setModalState(() => obscureNew = !obscureNew);
                    },
                  ),
                  const SizedBox(height: 12),
                  _PasswordField(
                    controller: confirmController,
                    label: "Confirm New Password",
                    obscureText: obscureConfirm,
                    onToggle: () {
                      setModalState(() => obscureConfirm = !obscureConfirm);
                    },
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _changingPassword ? null : submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: green,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        _changingPassword ? "Updating..." : "Update Password",
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
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

  Widget _buildProfileAvatar() {
    return GestureDetector(
      onTap: _uploadingPhoto ? null : _pickAndUploadImage,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 86,
            height: 86,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x12000000),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: ClipOval(
              child: _profileBytes != null
                  ? Image.memory(
                _profileBytes!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _fallbackAvatar(),
              )
                  : _fallbackAvatar(),
            ),
          ),
          Positioned(
            right: -1,
            bottom: 2,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: green,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: _uploadingPhoto
                  ? const Padding(
                padding: EdgeInsets.all(4),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
                  : const Icon(
                Icons.check,
                color: Colors.white,
                size: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fallbackAvatar() {
    return Container(
      color: const Color(0xFFF2F4F7),
      child: const Icon(
        Icons.person,
        size: 38,
        color: Color(0xFF9AA1A9),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      bottomNavigationBar: _ParentBottomBar(
        activeIndex: 3,
        onHomeTap: widget.onHomeTap,
        onActivityTap: widget.onActivityTap,
        onBookmarkTap: widget.onBookmarkTap,
        onSettingsTap: widget.onSettingsTap,
        onCenterTap: widget.onCenterTap,
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Color(0xFFE6E8EB),
                    width: 1,
                  ),
                ),
              ),
              child: const Text(
                "Profile & Settings",
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                  color: dark,
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(14, 18, 14, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _buildProfileAvatar(),
                    const SizedBox(height: 12),
                    Text(
                      parentName.isEmpty ? "Parent User" : parentName,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: dark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      parentEmail,
                      style: const TextStyle(
                        fontSize: 13,
                        color: textGrey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: lightGreen,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        "PARENT ACCOUNT",
                        style: TextStyle(
                          fontSize: 11,
                          letterSpacing: 0.2,
                          fontWeight: FontWeight.w700,
                          color: green,
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    _SectionTitle(title: "DATA & PRIVACY"),
                    _CardShell(
                      child: Column(
                        children: [
                          _SwitchTileCard(
                            icon: Icons.mic_none_rounded,
                            title: "Allow Child Audio Recording",
                            subtitle:
                            "Audio is encrypted and used for better listening",
                            value: allowChildAudio,
                            onChanged: (v) {
                              setState(() => allowChildAudio = v);
                            },
                          ),
                          const Divider(height: 1, color: border),
                          _SwitchTileCard(
                            icon: Icons.bar_chart_rounded,
                            title: "Contribute to\nSpeech Model",
                            subtitle:
                            "Share anonymous data\nto improve it",
                            value: contributeSpeech,
                            onChanged: (v) {
                              setState(() => contributeSpeech = v);
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    _SectionTitle(title: "APP PREFERENCES"),
                    _CardShell(
                      child: Column(
                        children: const [
                          _ActionTileCard(
                            icon: Icons.menu_book_rounded,
                            title: "Urdu News Summary Level",
                            subtitle: "Detailed",
                          ),
                          Divider(height: 1, color: border),
                          _ActionTileCard(
                            icon: Icons.calendar_today_rounded,
                            title: "Classroom Updates",
                            subtitle: "Daily Digest",
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    _SectionTitle(title: "SECURITY"),
                    _CardShell(
                      child: Column(
                        children: [
                          _ActionTileCard(
                            icon: Icons.lock_outline_rounded,
                            title: "Change Password",
                            subtitle: "",
                            onTap: _showChangePasswordSheet,
                          ),
                          const Divider(height: 1, color: border),
                          _SwitchTileCard(
                            icon: Icons.camera_alt_outlined,
                            title: "Enable FaceID",
                            subtitle: "",
                            value: enableFaceId,
                            onChanged: (v) {
                              setState(() => enableFaceId = v);
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    InkWell(
                      onTap: _logout,
                      borderRadius: BorderRadius.circular(12),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.logout_rounded, color: red, size: 18),
                            SizedBox(width: 6),
                            Text(
                              "Log Out",
                              style: TextStyle(
                                color: red,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      "TinyWise v2.4.0",
                      style: TextStyle(
                        color: Color(0xFFB6BBC3),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(left: 2, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Color(0xFF8D949C),
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _CardShell extends StatelessWidget {
  final Widget child;

  const _CardShell({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE7E9EC)),
      ),
      child: child,
    );
  }
}

class _ActionTileCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _ActionTileCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: const Color(0xFFF3F5F7),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Icon(icon, color: const Color(0xFF67707A), size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFF202428),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFF8B929A),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFF9EA4AB),
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

class _SwitchTileCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchTileCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFFF3F5F7),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Icon(icon, color: const Color(0xFF67707A), size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFF202428),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFF8B929A),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        height: 1.25,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Transform.scale(
            scale: 0.93,
            child: Switch(
              value: value,
              onChanged: onChanged,
              activeColor: Colors.white,
              activeTrackColor: const Color(0xFF19D15F),
              inactiveThumbColor: Colors.white,
              inactiveTrackColor: const Color(0xFFD4D8DD),
            ),
          ),
        ],
      ),
    );
  }
}

class _PasswordField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool obscureText;
  final VoidCallback onToggle;

  const _PasswordField({
    required this.controller,
    required this.label,
    required this.obscureText,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: const Color(0xFFF7F8FA),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF22C55E)),
        ),
        suffixIcon: IconButton(
          onPressed: onToggle,
          icon: Icon(
            obscureText ? Icons.visibility_off_outlined : Icons.visibility_outlined,
          ),
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