import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:multi_select_flutter/multi_select_flutter.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  File? _profileImage;
  final ImagePicker _picker = ImagePicker();

  final _selectedLevel = ValueNotifier<String?>(null);
  final _selectedSports = ValueNotifier<List<String>>([]);

  final _allSports = const [
    "Running", "Cycling", "Swimming", "Gym", "CrossFit", "Bodybuilding",
    "Yoga", "Pilates", "Meditation", "Boxing", "MMA", "Karate",
    "Football", "Basketball", "Volleyball", "Tennis", "Badminton", "Padel",
    "Hiking", "Climbing", "Surfing", "Dance", "Calisthenics", "Rowing"
  ];

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _profileImage = File(picked.path);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Account'),
        centerTitle: true,
        leading: const BackButton(color: Colors.black),
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
                  CircleAvatar(
                    radius: 48,
                    backgroundColor: const Color(0xFFEDEDED),
                    backgroundImage: _profileImage != null
                        ? FileImage(_profileImage!)
                        : null,
                    child: _profileImage == null
                        ? const Icon(Icons.person, size: 40, color: Colors.grey)
                        : null,
                  ),
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
            _InputField(hint: "Full Name"),
            const SizedBox(height: 12),
            _InputField(hint: "Email"),
            const SizedBox(height: 12),
            _InputField(hint: "Password", obscure: true),
            const SizedBox(height: 12),

            // Level dropdown
            ValueListenableBuilder<String?>(
              valueListenable: _selectedLevel,
              builder: (_, value, __) {
                return DropdownButtonFormField<String>(
                  value: value,
                  items: const [
                    DropdownMenuItem(value: "Beginner", child: Text("Beginner")),
                    DropdownMenuItem(value: "Intermediate", child: Text("Intermediate")),
                    DropdownMenuItem(value: "Expert", child: Text("Expert")),
                  ],
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

            _InputField(hint: "Age"),
            const SizedBox(height: 12),

            // Preferred Sport(s) multiselect
            ValueListenableBuilder<List<String>>(
              valueListenable: _selectedSports,
              builder: (_, selected, __) {
                return MultiSelectDialogField(
                  items: _allSports.map((s) => MultiSelectItem(s, s)).toList(),
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
                    _selectedSports.value = values.cast<String>();
                  },
                );
              },
            ),

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  // TODO: Submit form data
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                child: const Text("Create Account", style: TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(height: 12),
            Text.rich(
              TextSpan(
                text: "By signing in, you agree to our ",
                children: [
                  TextSpan(
                    text: "Term of Service",
                    style: const TextStyle(
                      color: Colors.blue,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                  const TextSpan(text: "."),
                ],
              ),
              style: const TextStyle(fontSize: 12),
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
  final String hint;
  final bool obscure;

  const _InputField({required this.hint, this.obscure = false});

  @override
  Widget build(BuildContext context) {
    return TextField(
      obscureText: obscure,
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
