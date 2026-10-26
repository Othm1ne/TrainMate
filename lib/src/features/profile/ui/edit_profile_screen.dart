import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:multi_select_flutter/multi_select_flutter.dart';
import '../../../data/models/user_profile.dart';
import '../../../data/services/user_repository.dart';
import '../../../shared/sports.dart';
import '../../../shared/widgets.dart';

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
  late TextEditingController _age;
  late String _level;
  late List<String> _sports;
  String? _photoPath; // picked profile picture path or URL
  bool _saving = false;
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.profile.name);
    _bio  = TextEditingController(text: widget.profile.bio);
    _age = TextEditingController(
        text: widget.profile.age > 0 ? '${widget.profile.age}' : '');
    _level = widget.profile.level;
    _sports = [...widget.profile.sports];
    _photoPath = widget.profile.photoPath;
  }

  @override
  void dispose() {
    _name.dispose();
    _bio.dispose();
    _age.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final x = await _picker.pickImage(
        source: ImageSource.gallery, maxWidth: 1024, imageQuality: 85);
    if (x != null) setState(() => _photoPath = x.path);
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      showSnack(context, 'Name cannot be empty');
      return;
    }
    if (_sports.isEmpty) {
      showSnack(context, 'Pick at least one sport');
      return;
    }
    setState(() => _saving = true);
    try {
      await UserRepository.instance.update(widget.profile.copyWith(
        name: _name.text.trim(),
        bio: _bio.text.trim(),
        age: int.tryParse(_age.text.trim()) ?? widget.profile.age,
        level: _level,
        sports: _sports,
        photoPath: _photoPath,
      ));
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        showSnack(context, 'Could not save your profile. Try again.');
      }
    }
  }

  Future<void> _refreshLocation() async {
    setState(() => _locating = true);
    await UserRepository.instance.refreshLocation(widget.profile.uid);
    if (mounted) {
      setState(() => _locating = false);
      showSnack(context, 'Location updated');
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
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save'),
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
                  Avatar(url: _photoPath, radius: 48),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: cs.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Icon(Icons.add, size: 18, color: cs.onPrimary),
                  )
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Text("Tap to change your profile picture"),

            const SizedBox(height: 16),
            TextField(controller: _name, decoration: _fieldDeco('Full Name')),
            const SizedBox(height: 12),

            TextField(
              controller: _age,
              keyboardType: TextInputType.number,
              decoration: _fieldDeco('Age'),
            ),
            const SizedBox(height: 12),

            DropdownButtonFormField<String>(
              initialValue: _level,
              decoration: _fieldDeco('Level'),
              items: levels
                  .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                  .toList(),
              onChanged: (v) => setState(() => _level = v ?? _level),
            ),
            const SizedBox(height: 12),

            MultiSelectDialogField<String>(
              items: allSports.map((s) => MultiSelectItem(s, s)).toList(),
              initialValue: _sports,
              listType: MultiSelectListType.CHIP,
              title: const Text('Preferred Sports'),
              buttonText: const Text('Preferred Sports'),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
              ),
              onConfirm: (vals) => _sports = vals,
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _bio,
              maxLines: 4,
              maxLength: 300,
              textCapitalization: TextCapitalization.sentences,
              decoration: _fieldDeco('About me'),
            ),
            const SizedBox(height: 12),

            // Location (auto-detected)
            ListTile(
              leading: const Icon(Icons.location_on_outlined),
              title: const Text('Location'),
              subtitle: Text(widget.profile.location.isEmpty
                  ? 'Not detected yet'
                  : widget.profile.location),
              trailing: _locating
                  ? const SizedBox(
                      height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : IconButton(
                      icon: const Icon(Icons.my_location),
                      tooltip: 'Update location',
                      onPressed: _refreshLocation,
                    ),
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
