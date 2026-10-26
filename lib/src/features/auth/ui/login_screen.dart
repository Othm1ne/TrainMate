import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../data/services/auth_service.dart';
import '../../../shared/widgets.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  /// Runs a sign-in call, then drops back to the root so AuthGate takes over.
  Future<void> _run(Future<Object?> Function() action) async {
    setState(() => _loading = true);
    try {
      final result = await action();
      if (!mounted) return;
      if (result != null) Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) {
      if (mounted) showSnack(context, authErrorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _login() {
    if (_email.text.trim().isEmpty || _password.text.isEmpty) {
      showSnack(context, 'Enter your email and password');
      return;
    }
    _run(() => AuthService.instance.signIn(_email.text, _password.text));
  }

  Future<void> _forgotPassword() async {
    final controller = TextEditingController(text: _email.text.trim());
    final email = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset password'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(hintText: 'Your email'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Send link'),
          ),
        ],
      ),
    );
    if (email == null || email.isEmpty || !mounted) return;
    try {
      await AuthService.instance.sendPasswordReset(email);
      if (mounted) showSnack(context, 'Reset link sent to $email');
    } catch (e) {
      if (mounted) showSnack(context, authErrorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final showApple = kIsWeb ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Log In'),
        centerTitle: true,
        leading: const BackButton(color: Colors.black),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 40),
                    // Logo
                    Center(
                      child: Image.asset('assets/images/logo_icon.png', height: 180),
                    ),
                    const SizedBox(height: 40),

                    // Email Field
                    _InputField(
                      controller: _email,
                      hint: "Email",
                      obscure: false,
                      icon: Icons.person_outline,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),

                    // Password Field
                    _InputField(
                      controller: _password,
                      hint: "Password",
                      obscure: true,
                      icon: Icons.lock_outline,
                      onSubmitted: (_) => _login(),
                    ),
                    const SizedBox(height: 24),

                    // Log In Button
                    ElevatedButton(
                      onPressed: _loading ? null : _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      child: _loading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Text("Log In",
                              style: TextStyle(fontSize: 16, color: Colors.white)),
                    ),
                    const SizedBox(height: 12),

                    // Forgot password
                    Center(
                      child: TextButton(
                        onPressed: _forgotPassword,
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
                    const SizedBox(height: 24),

                    // Continue with Google
                    _SocialButton(
                      label: "Continue with Google",
                      iconPath: "assets/images/google.png",
                      onTap: _loading
                          ? null
                          : () => _run(AuthService.instance.signInWithGoogle),
                    ),
                    const SizedBox(height: 12),

                    // Continue with Apple
                    if (showApple) ...[
                      _SocialButton(
                        label: "Continue with Apple",
                        iconPath: "assets/images/apple.png",
                        onTap: _loading
                            ? null
                            : () => _run(AuthService.instance.signInWithApple),
                      ),
                      const SizedBox(height: 12),
                    ],
                    const SizedBox(height: 12),
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

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool obscure;
  final IconData icon;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onSubmitted;

  const _InputField({
    required this.controller,
    required this.hint,
    required this.obscure,
    required this.icon,
    this.keyboardType,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      onSubmitted: onSubmitted,
      autocorrect: false,
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
  final VoidCallback? onTap;

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
