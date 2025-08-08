import 'package:flutter/material.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Log In'),
        centerTitle: true,
        leading: const BackButton(color: Colors.black),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 100),
            // Logo
            Center(
              child:
                Image.asset('assets/images/logo_icon.png', height: 220),
            ),
            const SizedBox(height: 48),

            // Username Field
            _InputField(
              hint: "UserName",
              obscure: false,
              icon: Icons.person_outline,
            ),
            const SizedBox(height: 16),

            // Password Field
            _InputField(
              hint: "Password",
              obscure: true,
              icon: Icons.lock_outline,
            ),
            const SizedBox(height: 24),

            // Log In Button
            ElevatedButton(
              onPressed: () {
                // TODO: handle login
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              child: const Text("Log In", style: TextStyle(fontSize: 16, color: Colors.white)),
            ),
            const SizedBox(height: 12),

            // Forgot password
            Center(
              child: TextButton(
                onPressed: () {
                  // TODO: forgot password
                },
                child: const Text(
                  "I forgot my password.",
                  style: TextStyle(
                    decoration: TextDecoration.underline,
                    fontSize: 13,
                    color: Colors.black87,
                  ),
                ),
              ),
            ),
            const Spacer(),

            // Continue with Google
            _SocialButton(
              label: "Continue with Google",
              iconPath: "assets/images/google.png",
              onTap: () {
                // TODO: Google login
              },
            ),
            const SizedBox(height: 12),

            // Continue with Apple
            _SocialButton(
              label: "Continue with Apple",
              iconPath: "assets/images/apple.png",
              onTap: () {
                // TODO: Apple login
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  final String hint;
  final bool obscure;
  final IconData icon;

  const _InputField({
    required this.hint,
    required this.obscure,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      obscureText: obscure,
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.grey.shade200,
        prefixIcon: Icon(icon),
        hintText: hint,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  final String label;
  final String iconPath;
  final VoidCallback onTap;

  const _SocialButton({
    required this.label,
    required this.iconPath,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        side: BorderSide(color: Colors.grey.shade300),
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),
      onPressed: onTap,
      icon: Image.asset(iconPath, height: 20),
      label: Text(label, style: const TextStyle(color: Colors.black)),
    );
  }
}
