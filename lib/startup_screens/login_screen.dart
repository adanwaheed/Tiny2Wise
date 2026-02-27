import 'package:flutter/material.dart';
import 'signup_screen.dart';
import '../parent_screens/parent_dashboard_screen.dart';
import '../teacher_screens/teacher_dashboard_screen.dart';
import '../services/api_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const Color bg = Color(0xFFEFF7ED);
  static const Color green = Color(0xFF27C267);
  static const Color dark = Color(0xFF1F2A2E);
  static const Color grey = Color(0xFF6E7B80);

  bool rememberMe = false;
  bool obscure = true;
  bool isLoading = false;

  final emailController = TextEditingController();
  final passController = TextEditingController();

  @override
  void dispose() {
    emailController.dispose();
    passController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email = emailController.text.trim();
    final pass = passController.text;

    if (email.isEmpty || pass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter email and password")),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final data = await ApiService.login(email: email, password: pass);

      final role = (data["user"]?["role"] ?? "").toString().toLowerCase();

      if (!mounted) return;

      if (role == "parent") {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => ParentDashboardScreen(parentName: data["user"]["name"] ?? "Parent"),
          ),
        );
      } else if (role == "teacher") {
        final teacherName = (data["user"]?["name"] ?? "").toString().trim();
        final teacherEmail = (data["user"]?["email"] ?? email).toString();

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => TeacherDashboardScreen(
              teacherName: teacherName.isEmpty ? teacherEmail.split("@").first : teacherName,
              teacherEmail: teacherEmail,
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Login success but role is invalid.")),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Login failed: $e")),
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 10),

                // Top soft circles background
                Stack(
                  children: [
                    Align(
                      alignment: Alignment.topLeft,
                      child: Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          color: green.withOpacity(0.10),
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.account_circle_outlined,
                            size: 64,
                            color: Color(0xFFB6DCC6),
                          ),
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.topRight,
                      child: Container(
                        width: 110,
                        height: 110,
                        decoration: BoxDecoration(
                          color: green.withOpacity(0.09),
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.child_care_sharp,
                            size: 64,
                            color: Color(0xFFB6DCC6),
                          ),
                        ),
                      ),
                    ),

                    // Center content
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Column(
                        children: [
                          // App icon
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              color: const Color(0xFF86E39A),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.08),
                                  blurRadius: 18,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Image.asset(
                                "assets/logo.png",
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),

                          const SizedBox(height: 14),

                          // Tiny2Wise title
                          RichText(
                            text: TextSpan(
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w700,
                                color: dark,
                              ),
                              children: const [
                                TextSpan(text: "Tiny"),
                                TextSpan(
                                  text: "2",
                                  style: TextStyle(
                                    color: green,
                                    fontSize: 50,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                TextSpan(text: "Wise"),
                              ],
                            ),
                          ),

                          const SizedBox(height: 6),

                          const Text(
                            "Voice Across Generations",
                            style: TextStyle(
                              color: grey,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),

                          const SizedBox(height: 22),

                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              "Welcome Back!",
                              style: TextStyle(
                                color: dark,
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),

                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              "Let's continue learning & growing together.",
                              style: TextStyle(
                                color: grey,
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),

                          const SizedBox(height: 18),

                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              "Email Address",
                              style: TextStyle(
                                color: dark,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),

                          _InputField(
                            controller: emailController,
                            hint: "parent@gmail.com",
                            prefixIcon: Icons.mail_outline,
                            obscure: false,
                          ),

                          const SizedBox(height: 14),

                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              "Password",
                              style: TextStyle(
                                color: dark,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),

                          _InputField(
                            controller: passController,
                            hint: "••••••••",
                            prefixIcon: Icons.lock_outline,
                            obscure: obscure,
                            suffix: IconButton(
                              onPressed: () {
                                setState(() => obscure = !obscure);
                              },
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

                          Row(
                            children: [
                              Transform.scale(
                                scale: 1.08,
                                child: Checkbox(
                                  value: rememberMe,
                                  activeColor: green,
                                  onChanged: (v) {
                                    setState(() => rememberMe = v ?? false);
                                  },
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ),
                              const Text(
                                "Remember me",
                                style: TextStyle(
                                  color: grey,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const Spacer(),
                              TextButton(
                                onPressed: () {},
                                child: const Text(
                                  "Forgot Password?",
                                  style: TextStyle(
                                    color: green,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 6),

                          // Login button (connected to API)
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
                              onPressed: isLoading ? null : _login,
                              child: isLoading
                                  ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.6,
                                  color: Colors.white,
                                ),
                              )
                                  : const Row(
                                mainAxisAlignment:
                                MainAxisAlignment.center,
                                children: [
                                  Text(
                                    "Login to Account",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  SizedBox(width: 10),
                                  Icon(Icons.arrow_forward,
                                      color: Colors.white, size: 20),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 18),

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

                          Row(
                            children: [
                              Expanded(
                                child: _SocialButton(
                                  bgColor: Colors.white,
                                  borderColor: const Color(0xFFE2E8E6),
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
                                  onTap: () {},
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _SocialButton(
                                  bgColor: Colors.black,
                                  borderColor: Colors.black,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: const [
                                      Icon(Icons.apple,
                                          color: Colors.white, size: 20),
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
                                  onTap: () {},
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          GestureDetector(
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (_) => const SignupScreen()),
                              );
                            },
                            child: RichText(
                              textAlign: TextAlign.center,
                              text: const TextSpan(
                                style: TextStyle(
                                  color: grey,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                                children: [
                                  TextSpan(text: "Don't have an account? "),
                                  TextSpan(
                                    text: "Sign Up",
                                    style: TextStyle(
                                      color: green,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 18),

                          const Opacity(
                            opacity: 0.15,
                            child: Icon(
                              Icons.eco_outlined,
                              size: 70,
                              color: Color(0xFF27C267),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
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

  const _InputField({
    required this.controller,
    required this.hint,
    required this.prefixIcon,
    required this.obscure,
    this.suffix,
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
        style: const TextStyle(
          fontSize: 15.5,
          fontWeight: FontWeight.w600,
          color: Color(0xFF1F2A2E),
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(
            color: Color(0xFF9AA6AC),
            fontWeight: FontWeight.w600,
            fontSize: 15,
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
