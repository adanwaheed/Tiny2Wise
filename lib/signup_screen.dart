import 'package:flutter/material.dart';
import 'login_screen.dart';
import 'parent_dashboard_screen.dart';
import 'teacher_dashboard_screen.dart';
import 'services/api_service.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

enum UserRole { parent, teacher }

class _SignupScreenState extends State<SignupScreen> {
  static const Color bg = Color(0xFFEFF7ED);
  static const Color green = Color(0xFF27C267);
  static const Color dark = Color(0xFF1F2A2E);
  static const Color grey = Color(0xFF6E7B80);
  static const Color border = Color(0xFFE2E8E6);

  UserRole selectedRole = UserRole.parent;
  bool obscure = true;
  bool isLoading = false;

  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passController = TextEditingController();

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passController.dispose();
    super.dispose();
  }

  // ✅ Password validation: 8+ chars, at least 1 uppercase, 1 lowercase
  bool _isPasswordValid(String password) {
    if (password.length < 8) return false;
    final hasUpper = RegExp(r'[A-Z]').hasMatch(password);
    final hasLower = RegExp(r'[a-z]').hasMatch(password);
    return hasUpper && hasLower;
  }

  Future<void> _createAccount() async {
    final name = nameController.text.trim();
    final email = emailController.text.trim();
    final password = passController.text;

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all fields")),
      );
      return;
    }

    if (!_isPasswordValid(password)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Password must be at least 8 characters and include 1 uppercase & 1 lowercase letter.",
          ),
        ),
      );
      return;
    }

    final role = selectedRole == UserRole.parent ? "parent" : "teacher";

    setState(() => isLoading = true);

    try {
      // ✅ capture returned data (token + user)
      final data = await ApiService.signup(
        role: role,
        name: name,
        email: email,
        password: password,
      );

      if (!mounted) return;

      final userRole =
      (data["user"]?["role"] ?? role).toString().toLowerCase();
      final userName = (data["user"]?["name"] ?? name).toString();

      if (userRole == "parent") {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => ParentDashboardScreen(parentName: userName),
          ),
        );
      } else if (userRole == "teacher") {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => TeacherDashboardScreen(
              teacherName: (data["user"]?["name"] ?? name).toString(),
              teacherEmail: (data["user"]?["email"] ?? email).toString(),
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Signup success but role is invalid.")),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Signup failed: $e")),
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _googleSignup() {
    // TODO: Integrate Google Sign-In
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Google signup is not connected yet.")),
    );
  }

  void _appleSignup() {
    // TODO: Integrate Apple Sign-In
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Apple signup is not connected yet.")),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isParent = selectedRole == UserRole.parent;
    final isTeacher = selectedRole == UserRole.teacher;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Start their journey",
                  style: TextStyle(
                    color: dark,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  "Select your role to customize your\nlearning experience.",
                  style: TextStyle(
                    color: grey,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: _RoleCard(
                        active: isParent,
                        title: "Parent",
                        subtitle: "Track progress at home",
                        icon: Icons.group_outlined,
                        onTap: () =>
                            setState(() => selectedRole = UserRole.parent),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _RoleCard(
                        active: isTeacher,
                        title: "Teacher",
                        subtitle: "Classroom tools",
                        icon: Icons.school_outlined,
                        onTap: () =>
                            setState(() => selectedRole = UserRole.teacher),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                _InputField(
                  controller: nameController,
                  hint: "What's your full name?",
                  prefixIcon: Icons.person_outline,
                ),
                const SizedBox(height: 10),
                _InputField(
                  controller: emailController,
                  hint: "Enter your email",
                  prefixIcon: Icons.mail_outline,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 10),
                _InputField(
                  controller: passController,
                  hint: "Create a password",
                  prefixIcon: Icons.lock_outline,
                  obscure: obscure,
                  suffix: IconButton(
                    onPressed: () => setState(() => obscure = !obscure),
                    icon: Icon(
                      obscure
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: const Color(0xFF9AA6AC),
                      size: 22,
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                Container(
                  width: double.infinity,
                  padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF27C267).withOpacity(0.10),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF27C267).withOpacity(0.25),
                    ),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Password must contain:",
                        style: TextStyle(
                          color: Color(0xFF2E6B4D),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        "• At least 8 characters\n• One uppercase & one lowercase letter",
                        style: TextStyle(
                          color: Color(0xFF2E6B4D),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

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
                    onPressed: isLoading ? null : _createAccount,
                    child: isLoading
                        ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                        : const Text(
                      "Create Account",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                Row(
                  children: const [
                    Expanded(
                      child: Divider(color: Color(0xFFCBD5D1)),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        "Or continue with",
                        style: TextStyle(
                          color: grey,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Divider(color: Color(0xFFCBD5D1)),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // ✅ Google + Apple buttons (added back)
                Row(
                  children: [
                    Expanded(
                      child: _SocialButton(
                        bgColor: Colors.white,
                        borderColor: border,
                        onTap: _googleSignup,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.asset(
                              "assets/google.jpg",
                              width: 20,
                              height: 20,
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              "Google",
                              style: TextStyle(
                                color: dark,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _SocialButton(
                        bgColor: Colors.black,
                        borderColor: Colors.black,
                        onTap: _appleSignup,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.apple, color: Colors.white, size: 20),
                            SizedBox(width: 10),
                            Text(
                              "Apple",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                Center(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      );
                    },
                    child: RichText(
                      textAlign: TextAlign.center,
                      text: const TextSpan(
                        style: TextStyle(
                          color: grey,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                        children: [
                          TextSpan(text: "Already have an account? "),
                          TextSpan(
                            text: "Log in",
                            style: TextStyle(
                              color: green,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final bool active;
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _RoleCard({
    required this.active,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  static const Color green = Color(0xFF27C267);
  static const Color dark = Color(0xFF1F2A2E);
  static const Color grey = Color(0xFF6E7B80);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 150,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFFFF),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: active ? green : const Color(0xFFE2E8E6),
            width: active ? 1.6 : 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: active ? green : const Color(0xFFF2F4F3),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icon,
                size: 24,
                color: active ? Colors.white : const Color(0xFF9AA6AC),
              ),
            ),
            Column(
              children: [
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: dark,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: grey,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                  ),
                ),
              ],
            ),
            Icon(
              Icons.check_circle,
              size: 18,
              color: active ? green : const Color(0xFFE2E8E6),
            ),
          ],
        ),
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData prefixIcon;
  final bool obscure;
  final Widget? suffix;
  final TextInputType? keyboardType;

  const _InputField({
    required this.controller,
    required this.hint,
    required this.prefixIcon,
    this.obscure = false,
    this.suffix,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8E6)),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: Color(0xFF1F2A2E),
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(
            color: Color(0xFF9AA6AC),
            fontWeight: FontWeight.w600,
            fontSize: 14.5,
          ),
          prefixIcon: Icon(prefixIcon, color: Color(0xFF9AA6AC), size: 22),
          suffixIcon: suffix,
          border: InputBorder.none,
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        ),
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  final Color bgColor;
  final Color borderColor;
  final Widget child;
  final VoidCallback onTap;

  const _SocialButton({
    required this.bgColor,
    required this.borderColor,
    required this.child,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Ink(
        height: 50,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Center(child: child),
      ),
    );
  }
}
