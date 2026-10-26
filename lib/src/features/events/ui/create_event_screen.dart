// lib/src/features/events/ui/create_event_screen.dart
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../data/models/event_item.dart';
import '../../../data/models/user_profile.dart';
import '../../../data/services/event_repository.dart';
import '../../../shared/sports.dart';
import '../../../shared/widgets.dart';

class CreateEventScreen extends StatefulWidget {
  final UserProfile creator;
  const CreateEventScreen({super.key, required this.creator});
  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  final _title = TextEditingController();
  final _place = TextEditingController();
  final _desc = TextEditingController();
  late String _category = widget.creator.sports.isNotEmpty
      ? widget.creator.sports.first
      : allSports.first;
  DateTime _dateTime = DateTime.now().add(const Duration(days: 1));
  String? _coverPath;
  bool _saving = false;

  final _picker = ImagePicker();

  @override
  void dispose() {
    _title.dispose();
    _place.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _pickCover() async {
    final x = await _picker.pickImage(
        source: ImageSource.gallery, maxWidth: 1600, imageQuality: 85);
    if (x != null) setState(() => _coverPath = x.path);
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDate: _dateTime,
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dateTime),
    );
    if (time == null) return;
    setState(() {
      _dateTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _create() async {
    if (_title.text.trim().isEmpty || _place.text.trim().isEmpty) {
      showSnack(context, 'Please enter title and place');
      return;
    }
    if (_dateTime.isBefore(DateTime.now())) {
      showSnack(context, 'Pick a date in the future');
      return;
    }
    setState(() => _saving = true);
    try {
      final item = await EventRepository.instance.create(
        EventItem(
          id: '',
          title: _title.text.trim(),
          category: _category,
          dateTime: _dateTime,
          place: _place.text.trim(),
          cover: _coverPath ?? '',
          description: _desc.text.trim(),
        ),
        widget.creator,
      );
      if (mounted) Navigator.pop(context, item);
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        showSnack(context, 'Could not create the event. Try again.');
      }
    }
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
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _coverPath == null
                    ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add_photo_alternate_outlined, size: 36),
                            SizedBox(height: 6),
                            Text('Add cover photo'),
                          ],
                        ),
                      )
                    : SizedBox.expand(child: coverImage(_coverPath!)),
              ),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _title,
              textCapitalization: TextCapitalization.sentences,
              decoration: _deco('Title'),
            ),
            const SizedBox(height: 12),

            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: _deco('Category'),
              items: allSports.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: (v) => setState(() => _category = v ?? _category),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _place,
              decoration: _deco('Place (address or venue, city)'),
            ),
            const SizedBox(height: 12),

            // Description (multi-line)
            TextField(
              controller: _desc,
              minLines: 3,
              maxLines: 6,
              textCapitalization: TextCapitalization.sentences,
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
                onPressed: _saving ? null : _create,
                style: ElevatedButton.styleFrom(
                  backgroundColor: cs.primary,
                  foregroundColor: cs.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Create Event'),
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
