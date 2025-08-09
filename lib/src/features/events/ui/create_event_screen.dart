// lib/src/features/events/ui/create_event_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'events_list_screen.dart';
import '../../../shared/sports.dart';

class CreateEventScreen extends StatefulWidget {
  const CreateEventScreen({super.key});
  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  final _title = TextEditingController();
  final _place = TextEditingController();
  final _distance = TextEditingController();
  final _desc = TextEditingController();                // <-- NEW
  String _category = allSports.first;
  DateTime _dateTime = DateTime.now().add(const Duration(days: 1));
  String? _coverPath;

  final _picker = ImagePicker();

  @override
  void dispose() {
    _title.dispose();
    _place.dispose();
    _distance.dispose();
    _desc.dispose();                                    // <-- NEW
    super.dispose();
  }

  Future<void> _pickCover() async {
    final x = await _picker.pickImage(source: ImageSource.gallery);
    if (x != null) setState(() => _coverPath = x.path);
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDate: _dateTime,
    );
    if (date == null) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dateTime),
    );
    if (time == null) return;
    setState(() {
      _dateTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  void _create() {
    if (_title.text.trim().isEmpty || _place.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Please enter title and place')));
      return;
    }
    final dist = double.tryParse(_distance.text.trim()) ?? 0.0;

    final item = EventItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: _title.text.trim(),
      category: _category,
      dateTime: _dateTime,
      place: _place.text.trim(),
      distanceKm: dist,
      cover: _coverPath ?? 'https://picsum.photos/seed/new/1200/800',
      attendees: 0,
      attendeePhotos: const [],
      description: _desc.text.trim(),                   // <-- NEW
    );
    Navigator.pop(context, item);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Create Event')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // cover picker
            GestureDetector(
              onTap: _pickCover,
              child: Container(
                height: 160,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                  image: _coverPath == null
                      ? null
                      : DecorationImage(
                    image: FileImage(File(_coverPath!)),
                    fit: BoxFit.cover,
                  ),
                ),
                child: _coverPath == null
                    ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.add_photo_alternate_outlined, size: 36),
                    SizedBox(height: 6),
                    Text('Add cover photo'),
                  ],
                )
                    : null,
              ),
            ),
            const SizedBox(height: 16),

            TextField(controller: _title, decoration: _deco('Title')),
            const SizedBox(height: 12),

            DropdownButtonFormField<String>(
              value: _category,
              decoration: _deco('Category'),
              items: allSports.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: (v) => setState(() => _category = v ?? _category),
            ),
            const SizedBox(height: 12),

            TextField(controller: _place, decoration: _deco('Place')),
            const SizedBox(height: 12),

            // Description (multi-line)
            TextField(
              controller: _desc,
              minLines: 3,
              maxLines: 6,
              decoration: _deco('Description (details, meeting point, pace, etc.)'),
            ),
            const SizedBox(height: 12),

            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today_outlined),
              title: const Text('Date & time'),
              subtitle: Text(_format(_dateTime)),
              trailing: TextButton(onPressed: _pickDateTime, child: const Text('Change')),
            ),

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _create,
                style: ElevatedButton.styleFrom(
                  backgroundColor: cs.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Create Event'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _deco(String hint) => InputDecoration(
    hintText: hint,
    filled: true,
    fillColor: Colors.grey.shade200,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
  );

  String _format(DateTime dt) {
    final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final m = months[dt.month - 1];
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final ampm = dt.hour < 12 ? 'AM' : 'PM';
    return '$m ${dt.day}, $hour:${dt.minute.toString().padLeft(2, "0")} $ampm';
  }
}
