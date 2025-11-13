// lib/src/features/profile/ui/edit_profile_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:multi_select_flutter/multi_select_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/user_profile.dart';

const allSports = [
  "Running","Cycling","Swimming","Gym","CrossFit","Bodybuilding",
  "Yoga","Pilates","Meditation","Boxing","MMA","Karate",
  "Football","Basketball","Volleyball","Tennis","Badminton","Padel",
  "Hiking","Climbing","Surfing","Dance","Calisthenics","Rowing"
];

class EditProfileScreen extends StatefulWidget {
  final UserProfile profile;
  const EditProfileScreen({super.key, required this.profile});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _picker = ImagePicker();
  bool _saving = false;

  late TextEditingController _name;
  late TextEditingController _bio;
  late String _level;
  late List<String> _sports;
  String? _photoPath;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.profile.name);
    _bio = TextEditingController(text: widget.profile.bio);
    _level = widget.profile.level;
    _sports = [...widget.profile.sports];
    _photoPath = widget.profile.photoPath;
  }

  @override
  void dispose() {
    _name.dispose();
    _bio.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final x = await _picker.pickImage(source: ImageSource.gallery);
    if (x != null) setState(() => _photoPath = x.path);
  }

  Future<void> _saveProfile(BuildContext context) async {
    setState(() => _saving = true);

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception("User not logged in");

      String? photoUrl = widget.profile.photoPath;

      // 1️⃣ If user selected a new local image, upload to Firebase Storage
      if (_photoPath != null && !_photoPath!.startsWith('http')) {
        final file = File(_photoPath!);
        final ref = FirebaseStorage.instance.ref().child('profile_photos/$uid.jpg');
        await ref.putFile(file);
        photoUrl = await ref.getDownloadURL();
      }

      // 2️⃣ Update Firestore profile document
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'name': _name.text.trim(),
        'bio': _bio.text.trim(),
        'level': _level,
        'sports': _sports,
        'photoPath': photoUrl ?? '',
      });

      // 3️⃣ Create updated model to return to ProfileScreen
      final updated = widget.profile.copyWith(
        name: _name.text.trim(),
        bio: _bio.text.trim(),
        level: _level,
        sports: _sports,
        photoPath: photoUrl,
      );

      if (context.mounted) Navigator.pop(context, updated);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => _saveProfile(context),
            child: _saving
                ? const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
                : const Text('Save'),
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          children: [
            // Profile picture picker
            GestureDetector(
              onTap: _pickImage,
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  CircleAvatar(
                    radius: 48,
                    backgroundImage: _photoPath == null || _photoPath!.isEmpty
                        ? null
                        : (_photoPath!.startsWith('http')
                        ? NetworkImage(_photoPath!)
                        : FileImage(File(_photoPath!)) as ImageProvider),
                    child: (_photoPath == null || _photoPath!.isEmpty)
                        ? const Icon(Icons.person, size: 40, color: Colors.grey)
                        : null,
                    backgroundColor: const Color(0xFFEDEDED),
                  ),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: cs.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(Icons.add, size: 18, color: Colors.white),
                  )
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Text("Tap to change your profile picture"),

            const SizedBox(height: 16),
            TextField(controller: _name, decoration: _fieldDeco('Full Name')),
            const SizedBox(height: 12),

            DropdownButtonFormField<String>(
              value: _level.isNotEmpty ? _level : null,
              decoration: _fieldDeco('Level'),
              items: const [
                DropdownMenuItem(value: 'Beginner', child: Text('Beginner')),
                DropdownMenuItem(value: 'Intermediate', child: Text('Intermediate')),
                DropdownMenuItem(value: 'Expert', child: Text('Expert')),
              ],
              onChanged: (v) => setState(() => _level = v ?? _level),
            ),
            const SizedBox(height: 12),

            MultiSelectDialogField(
              items: allSports.map((s) => MultiSelectItem(s, s)).toList(),
              initialValue: _sports,
              listType: MultiSelectListType.CHIP,
              title: const Text('Preferred Sports'),
              buttonText: const Text('Preferred Sports'),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
              ),
              onConfirm: (vals) => _sports = vals.cast<String>(),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _bio,
              maxLines: 4,
              decoration: _fieldDeco('About me'),
            ),
            const SizedBox(height: 24),

            ListTile(
              leading: const Icon(Icons.location_on_outlined),
              title: const Text('Location'),
              subtitle: Text(widget.profile.location),
              trailing: const Text('(auto)'),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _fieldDeco(String hint) => InputDecoration(
    hintText: hint,
    filled: true,
    fillColor: Colors.grey.shade200,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
  );
}
