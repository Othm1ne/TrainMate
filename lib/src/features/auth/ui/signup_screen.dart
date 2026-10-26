import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:multi_select_flutter/multi_select_flutter.dart';
import '../../../data/models/user_profile.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/location_service.dart';
import '../../../data/services/user_repository.dart';
import '../../../shared/sports.dart';
import '../../../shared/widgets.dart';

class SignUpScreen extends StatefulWidget {
  /// True for Google/Apple users who are signed in but have no profile yet:
  /// hides email/password and offers "Sign out" instead of going back.
  final bool completeProfile;
  const SignUpScreen({super.key, this.completeProfile = false});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  String? _profileImage;
  final ImagePicker _picker = ImagePicker();

  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _age = TextEditingController();
  final _selectedLevel = ValueNotifier<String?>(null);
  final _selectedSports = ValueNotifier<List<String>>([]);
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.completeProfile) {
      final user = AuthService.instance.currentUser;
      _name.text = user?.displayName ?? '';
      _email.text = user?.email ?? '';
      _profileImage = user?.photoURL;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _age.dispose();
    _selectedLevel.dispose();
    _selectedSports.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(
        source: ImageSource.gallery, maxWidth: 1024, imageQuality: 85);
    if (picked != null) {
      setState(() {
        _profileImage = picked.path;
      });
    }
  }

  String? _validate() {
    if (_name.text.trim().isEmpty) return 'Enter your full name';
    if (!widget.completeProfile) {
      if (!_email.text.contains('@')) return 'Enter a valid email';
      if (_password.text.length < 6) return 'Password must be at least 6 characters';
    }
    if (_selectedLevel.value == null) return 'Choose your level';
    final age = int.tryParse(_age.text.trim());
    if (age == null || age < 13 || age > 100) return 'Enter a valid age';
    if (_selectedSports.value.isEmpty) return 'Pick at least one sport';
    return null;
  }

  Future<void> _submit() async {
    final error = _validate();
    if (error != null) {
      showSnack(context, error);
      return;
    }
    setState(() => _loading = true);
    try {
      final auth = AuthService.instance;
      final user = widget.completeProfile
          ? auth.currentUser!
          : (await auth.signUp(_email.text, _password.text)).user!;
      final loc = await LocationService.instance.current();
      await UserRepository.instance.create(UserProfile(
        uid: user.uid,
        name: _name.text.trim(),
        email: user.email ?? _email.text.trim(),
        age: int.parse(_age.text.trim()),
        location: loc?.label ?? '',
        lat: loc?.lat,
        lng: loc?.lng,
        joinedYear: DateTime.now().year,
        level: _selectedLevel.value!,
        bio: '',
        sports: _selectedSports.value,
        badges: const [],
        photoPath: _profileImage,
      ));
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) {
      if (mounted) showSnack(context, authErrorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.completeProfile ? 'Complete Profile' : 'Create Account'),
        centerTitle: true,
        leading: widget.completeProfile ? null : const BackButton(color: Colors.black),
        automaticallyImplyLeading: !widget.completeProfile,
        actions: [
          if (widget.completeProfile)
            TextButton(
              onPressed: AuthService.instance.signOut,
              child: const Text('Sign out'),
            ),
        ],
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            const SizedBox(height: 16),
            // Profile picture picker
            GestureDetector(
              onTap: _pickImage,
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Avatar(url: _profileImage, radius: 48),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.teal,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: const Icon(Icons.add, size: 20, color: Colors.white),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Text("Add a profile picture"),

            const SizedBox(height: 32),
            _InputField(controller: _name, hint: "Full Name"),
            const SizedBox(height: 12),
            if (!widget.completeProfile) ...[
              _InputField(
                controller: _email,
                hint: "Email",
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              _InputField(controller: _password, hint: "Password", obscure: true),
              const SizedBox(height: 12),
            ],

            // Level dropdown
            ValueListenableBuilder<String?>(
              valueListenable: _selectedLevel,
              builder: (_, value, __) {
                return DropdownButtonFormField<String>(
                  initialValue: value,
                  items: levels
                      .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                      .toList(),
                  onChanged: (v) => _selectedLevel.value = v,
                  decoration: InputDecoration(
                    hintText: "Level",
                    filled: true,
                    fillColor: Colors.grey.shade200,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),

            _InputField(
              controller: _age,
              hint: "Age",
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),

            // Preferred Sport(s) multiselect
            ValueListenableBuilder<List<String>>(
              valueListenable: _selectedSports,
              builder: (_, selected, __) {
                return MultiSelectDialogField<String>(
                  items: allSports.map((s) => MultiSelectItem(s, s)).toList(),
                  title: const Text("Preferred Sports"),
                  buttonText: const Text("Preferred Sport(s)"),
                  buttonIcon: const Icon(Icons.sports),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  listType: MultiSelectListType.CHIP,
                  initialValue: selected,
                  onConfirm: (values) {
                    _selectedSports.value = values;
                  },
                );
              },
            ),

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
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
                    : Text(
                        widget.completeProfile ? "Continue" : "Create Account",
                        style: const TextStyle(fontSize: 16),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            const Text.rich(
              TextSpan(
                text: "By signing in, you agree to our ",
                children: [
                  TextSpan(
                    text: "Term of Service",
                    style: TextStyle(
                      color: Colors.blue,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                  TextSpan(text: "."),
                ],
              ),
              style: TextStyle(fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool obscure;
  final TextInputType? keyboardType;

  const _InputField({
    required this.controller,
    required this.hint,
    this.obscure = false,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.grey.shade200,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
