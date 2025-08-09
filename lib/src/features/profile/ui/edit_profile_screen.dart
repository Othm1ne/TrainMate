import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:multi_select_flutter/multi_select_flutter.dart';
import 'profile_screen.dart';

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

  late TextEditingController _name;
  late TextEditingController _bio;
  late String _level;
  late List<String> _sports;
  String? _photoPath; // picked profile picture path or URL

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.profile.name);
    _bio  = TextEditingController(text: widget.profile.bio);
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        actions: [
          TextButton(
            onPressed: () {
              final updated = widget.profile.copyWith(
                name: _name.text.trim(),
                bio: _bio.text.trim(),
                level: _level,
                sports: _sports,
                photoPath: _photoPath,
              );
              Navigator.pop(context, updated);
            },
            child: const Text('Save'),
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          children: [
            // profile picture picker
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
              value: _level,
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

            // Location (read-only)
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
