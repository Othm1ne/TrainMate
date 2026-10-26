import 'package:flutter/material.dart';
import '../../../shared/widgets.dart';
import '../data/store_repository.dart';

/// Rate the other side of a rental or sale. Returns true when submitted.
Future<bool> showReviewSheet(
  BuildContext context, {
  required String reviewContext,
  required String refId,
  required String otherName,
}) async =>
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ReviewSheet(reviewContext: reviewContext, refId: refId, otherName: otherName),
    ) ??
    false;

class _ReviewSheet extends StatefulWidget {
  final String reviewContext; // rental | sale
  final String refId;
  final String otherName;
  const _ReviewSheet({required this.reviewContext, required this.refId, required this.otherName});

  @override
  State<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends State<_ReviewSheet> {
  int _stars = 0;
  final _text = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() => _sending = true);
    try {
      final revealed = await StoreRepository.instance
          .submitReview(widget.reviewContext, widget.refId, _stars, _text.text.trim());
      if (!mounted) return;
      showSnack(
          context,
          revealed
              ? 'Thanks! Both reviews are now visible.'
              : 'Thanks! Your review appears once ${widget.otherName} reviews too (or in 14 days).');
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _sending = false);
        showSnack(context, storeError(e));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('How was it with ${widget.otherName}?', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (var i = 1; i <= 5; i++)
            IconButton(
              iconSize: 36,
              onPressed: () => setState(() => _stars = i),
              icon: Icon(i <= _stars ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: Colors.amber.shade700),
            ),
        ]),
        TextField(
          controller: _text,
          minLines: 2,
          maxLines: 5,
          maxLength: 500,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Comment (optional)'),
        ),
        const SizedBox(height: 8),
        const Text('Reviews are hidden until you both have reviewed, so be honest.',
            style: TextStyle(fontSize: 12)),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _stars == 0 || _sending ? null : _send,
            child: const Text('Submit review'),
          ),
        ),
      ]),
    );
  }
}
