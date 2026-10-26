import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../data/services/auth_service.dart';
import '../../../shared/widgets.dart';
import '../../profile/ui/edit_profile_screen.dart';
import '../data/store_repository.dart';

/// "Get verified" (spec §3): email + phone (SMS) + photo/name.
/// The badge itself is set by the `refreshVerification` Cloud Function.
class VerifyScreen extends StatelessWidget {
  const VerifyScreen({super.key});

  @override
  Widget build(BuildContext context) => MeBuilder(builder: (context, me) {
        final user = AuthService.instance.currentUser!;
        return _VerifyBody(
          emailVerified: user.emailVerified,
          phone: user.phoneNumber,
          hasPhotoAndName: (me.photoPath ?? '').isNotEmpty && me.name.trim().isNotEmpty,
          verified: me.verified,
          onEditProfile: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => EditProfileScreen(profile: me)),
          ),
        );
      });
}

class _VerifyBody extends StatefulWidget {
  final bool emailVerified;
  final String? phone;
  final bool hasPhotoAndName;
  final bool verified;
  final VoidCallback onEditProfile;
  const _VerifyBody({
    required this.emailVerified,
    required this.phone,
    required this.hasPhotoAndName,
    required this.verified,
    required this.onEditProfile,
  });

  @override
  State<_VerifyBody> createState() => _VerifyBodyState();
}

class _VerifyBodyState extends State<_VerifyBody> {
  late bool _emailOk = widget.emailVerified;
  late String? _phone = widget.phone;
  final _phoneCtrl = TextEditingController(text: '+33 ');
  final _codeCtrl = TextEditingController();
  String? _verificationId; // mobile
  ConfirmationResult? _webConfirmation; // web
  bool _busy = false;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  User get _user => AuthService.instance.currentUser!;

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } on FirebaseAuthException catch (e) {
      if (mounted) showSnack(context, _phoneError(e));
    } catch (e) {
      if (mounted) showSnack(context, storeError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _phoneError(FirebaseAuthException e) => switch (e.code) {
        'invalid-phone-number' => 'That phone number is not valid. Use the format +33 6 12 34 56 78.',
        'invalid-verification-code' => 'Wrong code. Check the SMS and try again.',
        'credential-already-in-use' || 'account-exists-with-different-credential' =>
          'This phone number is already used by another account.',
        'provider-already-linked' => 'A phone number is already linked to your account.',
        'too-many-requests' => 'Too many attempts. Try again later.',
        'operation-not-allowed' => 'Phone verification is not enabled yet. Please try again later.',
        _ => authErrorMessage(e),
      };

  Future<void> _checkEmail() => _run(() async {
        await _user.reload();
        final ok = AuthService.instance.currentUser!.emailVerified;
        setState(() => _emailOk = ok);
        if (!ok && mounted) showSnack(context, 'Not verified yet. Open the link in the email first.');
      });

  Future<void> _resendEmail() => _run(() async {
        await _user.sendEmailVerification();
        if (mounted) showSnack(context, 'Verification email sent to ${_user.email}');
      });

  Future<void> _sendCode() => _run(() async {
        final number = _phoneCtrl.text.replaceAll(RegExp(r'[\s.-]'), '');
        if (kIsWeb) {
          _webConfirmation = await _user.linkWithPhoneNumber(number);
          setState(() {});
          return;
        }
        await FirebaseAuth.instance.verifyPhoneNumber(
          phoneNumber: number,
          verificationCompleted: (cred) => _link(cred), // Android auto-retrieval
          verificationFailed: (e) {
            if (mounted) showSnack(context, _phoneError(e));
          },
          codeSent: (id, _) => setState(() => _verificationId = id),
          codeAutoRetrievalTimeout: (id) => _verificationId = id,
        );
      });

  Future<void> _confirmCode() => _run(() async {
        final code = _codeCtrl.text.trim();
        if (kIsWeb) {
          await _webConfirmation!.confirm(code);
          await _afterPhoneLinked();
        } else {
          await _link(PhoneAuthProvider.credential(verificationId: _verificationId!, smsCode: code));
        }
      });

  Future<void> _link(PhoneAuthCredential cred) async {
    await _user.linkWithCredential(cred);
    await _afterPhoneLinked();
  }

  Future<void> _afterPhoneLinked() async {
    await _user.reload();
    setState(() {
      _phone = AuthService.instance.currentUser!.phoneNumber;
      _verificationId = null;
      _webConfirmation = null;
    });
    await _finish();
  }

  Future<void> _finish() async {
    final r = await StoreRepository.instance.refreshVerification();
    if (!mounted) return;
    if (r.verified) {
      showSnack(context, "You're verified ✅");
    } else {
      showSnack(context, 'Still missing: ${r.missing.join(', ')}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final codeSent = _verificationId != null || _webConfirmation != null;
    return Scaffold(
      appBar: AppBar(title: const Text('Get verified')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (widget.verified)
            const Card(
              color: Color(0xFFE3F2FD),
              child: ListTile(
                leading: Icon(Icons.verified, color: Colors.blue),
                title: Text("You're verified"),
                subtitle: Text('You can rent out equipment and open a pro shop.'),
              ),
            )
          else
            const Text(
              'Verified members can rent out equipment. It builds trust: renters know who they deal with.',
            ),
          const SizedBox(height: 16),
          _StepTile(
            done: _emailOk,
            title: 'Email address',
            subtitle: _emailOk ? _user.email ?? '' : 'Open the link we sent to ${_user.email}',
            actions: _emailOk
                ? null
                : [
                    TextButton(onPressed: _busy ? null : _resendEmail, child: const Text('Resend')),
                    FilledButton.tonal(onPressed: _busy ? null : _checkEmail, child: const Text("I've verified")),
                  ],
          ),
          _StepTile(
            done: _phone != null,
            title: 'Phone number',
            subtitle: _phone ?? 'We send you a code by SMS. Your number is never shown to others.',
            body: _phone != null
                ? null
                : Column(children: [
                    TextField(
                      controller: _phoneCtrl,
                      enabled: !codeSent,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(labelText: 'Mobile number'),
                    ),
                    if (codeSent)
                      TextField(
                        controller: _codeCtrl,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        decoration: const InputDecoration(labelText: 'Code from SMS'),
                      ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.tonal(
                        onPressed: _busy ? null : (codeSent ? _confirmCode : _sendCode),
                        child: Text(codeSent ? 'Confirm code' : 'Send code'),
                      ),
                    ),
                  ]),
          ),
          _StepTile(
            done: widget.hasPhotoAndName,
            title: 'Profile photo and full name',
            subtitle: widget.hasPhotoAndName ? 'Done' : 'Add a clear photo of yourself.',
            actions: widget.hasPhotoAndName
                ? null
                : [FilledButton.tonal(onPressed: widget.onEditProfile, child: const Text('Edit profile'))],
          ),
          const SizedBox(height: 16),
          if (!widget.verified)
            FilledButton(
              onPressed: _busy ? null : () => _run(_finish),
              child: _busy
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Check my verification'),
            ),
        ],
      ),
    );
  }
}

class _StepTile extends StatelessWidget {
  final bool done;
  final String title;
  final String subtitle;
  final List<Widget>? actions;
  final Widget? body;
  const _StepTile({required this.done, required this.title, required this.subtitle, this.actions, this.body});

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(done ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: done ? Colors.green : Colors.grey),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text(subtitle, style: const TextStyle(fontSize: 13)),
                ]),
              ),
            ]),
            if (body != null) Padding(padding: const EdgeInsets.only(top: 8), child: body),
            if (actions != null)
              Align(
                alignment: Alignment.centerRight,
                child: Wrap(spacing: 8, children: actions!),
              ),
          ]),
        ),
      );
}
