import 'dart:io';
import 'dart:math';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:multi_select_flutter/multi_select_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});
  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;

  // Controllers
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();

  // Pickers / selections
  File? _profileImage;
  final ImagePicker _picker = ImagePicker();
  final _selectedLevel = ValueNotifier<String?>(null);
  final _selectedSports = ValueNotifier<List<String>>([]);

  final _allSports = const [
    "Running","Cycling","Swimming","Gym","CrossFit","Bodybuilding",
    "Yoga","Pilates","Meditation","Boxing","MMA","Karate",
    "Football","Basketball","Volleyball","Tennis","Badminton","Padel",
    "Hiking","Climbing","Surfing","Dance","Calisthenics","Rowing"
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _ageCtrl.dispose();
    _selectedLevel.dispose();
    _selectedSports.dispose();
    super.dispose();
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  // ===== Email/Password flow =====
  Future<void> _submitEmailPassword() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedLevel.value == null) {
      _snack('Please choose your level');
      return;
    }
    if (_selectedSports.value.isEmpty) {
      _snack('Please choose at least one sport');
      return;
    }

    setState(() => _loading = true);
    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text.trim(),
      );
      await _postSignInProfile(cred.user, overrideName: _nameCtrl.text.trim());
      _snack('Account created! Welcome 👋');
      if (mounted) Navigator.of(context).pop();
    } on FirebaseAuthException catch (e) {
      _snack(_friendlyAuthError(e));
    } catch (_) {
      _snack('Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ===== Google sign-in =====
  Future<void> _signInWithGoogle() async {
    setState(() => _loading = true);
    try {
      final gUser = await GoogleSignIn().signIn();
      if (gUser == null) { setState(() => _loading = false); return; }
      final gAuth = await gUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: gAuth.accessToken,
        idToken: gAuth.idToken,
      );
      final cred = await FirebaseAuth.instance.signInWithCredential(credential);
      // If form has name, prefer it when provider didn't return a name
      await _postSignInProfile(cred.user,
          overrideName: _nameCtrl.text.trim().isNotEmpty ? _nameCtrl.text.trim() : null);
      _snack('Signed in with Google');
      if (mounted) Navigator.of(context).pop();
    } on FirebaseAuthException catch (e) {
      _snack(_friendlyAuthError(e));
    } catch (_) {
      _snack('Google sign-in failed.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ===== Apple sign-in (iOS only) =====
  Future<void> _signInWithApple() async {
    if (!Platform.isIOS) { _snack('Apple Sign In is iOS only.'); return; }
    setState(() => _loading = true);
    try {
      final rawNonce = _generateNonce();
      final nonce = _sha256ofString(rawNonce);
      final appleCred = await SignInWithApple.getAppleIDCredential(
        scopes: [AppleIDAuthorizationScopes.email, AppleIDAuthorizationScopes.fullName],
        nonce: nonce,
      );
      final oauthCred = OAuthProvider('apple.com').credential(
        idToken: appleCred.identityToken,
        rawNonce: rawNonce,
      );
      final cred = await FirebaseAuth.instance.signInWithCredential(oauthCred);

      // Apple may only provide name on first auth; fallback to form name
      String? name;
      if ((appleCred.givenName ?? '').isNotEmpty || (appleCred.familyName ?? '').isNotEmpty) {
        name = '${appleCred.givenName ?? ''} ${appleCred.familyName ?? ''}'.trim();
      } else if (_nameCtrl.text.trim().isNotEmpty) {
        name = _nameCtrl.text.trim();
      }

      await _postSignInProfile(cred.user, overrideName: name);
      _snack('Signed in with Apple');
      if (mounted) Navigator.of(context).pop();
    } on FirebaseAuthException catch (e) {
      _snack(_friendlyAuthError(e));
    } catch (_) {
      _snack('Apple sign-in failed.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ===== Common profile merge after any sign-in =====
  Future<void> _postSignInProfile(User? user, {String? overrideName}) async {
    if (user == null) return;

    // Upload selected profile image if we have one (even for SSO)
    String? photoURL = user.photoURL;
    if (_profileImage != null) {
      final ref = FirebaseStorage.instance.ref('users/${user.uid}/profile.jpg');
      await ref.putFile(_profileImage!, SettableMetadata(contentType: 'image/jpeg'));
      photoURL = await ref.getDownloadURL();
      await user.updatePhotoURL(photoURL);
    }

    // Update name if we have a better one
    if (overrideName != null && overrideName.isNotEmpty && user.displayName != overrideName) {
      await user.updateDisplayName(overrideName);
    }

    // Merge extra fields into Firestore
    final age = int.tryParse(_ageCtrl.text.trim());
    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'displayName': overrideName ?? user.displayName,
      'photoURL': photoURL,
      'email': user.email,
      'level': _selectedLevel.value ?? 'Beginner',
      'sports': _selectedSports.value,
      'age': age,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ===== Helpers =====
  String _friendlyAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use': return 'This email is already in use.';
      case 'invalid-email': return 'Please enter a valid email.';
      case 'weak-password': return 'Password is too weak (min 6 chars).';
      case 'operation-not-allowed': return 'Provider is disabled in Firebase.';
      default: return e.message ?? 'Authentication error.';
    }
  }

  String _generateNonce([int length = 32]) {
    const charset = '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final rand = Random.secure();
    return List.generate(length, (_) => charset[rand.nextInt(charset.length)]).join();
  }
  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked != null) setState(() => _profileImage = File(picked.path));
  }

  @override
  Widget build(BuildContext context) {
    final deco = (String hint) => InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.grey.shade200,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Account'),
        centerTitle: true,
        leading: const BackButton(color: Colors.black),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  // Profile pic
                  GestureDetector(
                    onTap: _pickImage,
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        CircleAvatar(
                          radius: 48,
                          backgroundColor: const Color(0xFFEDEDED),
                          backgroundImage: _profileImage != null ? FileImage(_profileImage!) : null,
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
                  const SizedBox(height: 24),

                  // Email/Password inputs
                  TextFormField(
                    controller: _nameCtrl,
                    validator: (v) => (v == null || v.trim().length < 2) ? 'Enter your name' : null,
                    decoration: deco('Full Name'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) => (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
                    decoration: deco('Email'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _passCtrl,
                    obscureText: true,
                    validator: (v) => (v == null || v.length < 6) ? 'Min 6 characters' : null,
                    decoration: deco('Password'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _ageCtrl,
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v == null || v.isEmpty) return null; // optional
                      final n = int.tryParse(v);
                      if (n == null || n < 13 || n > 100) return 'Enter a valid age (13–100)';
                      return null;
                    },
                    decoration: deco('Age (optional)'),
                  ),
                  const SizedBox(height: 12),

                  // Level
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
                        decoration: deco('Level'),
                      );
                    },
                  ),
                  const SizedBox(height: 12),

                  // Sports (multi-select)
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
                        onConfirm: (values) { _selectedSports.value = values.cast<String>(); },
                      );
                    },
                  ),

                  const SizedBox(height: 20),
                  // Email/Password submit
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _submitEmailPassword,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      ),
                      child: const Text("Create Account", style: TextStyle(fontSize: 16)),
                    ),
                  ),

                  const SizedBox(height: 12),
                  // Divider
                  Row(
                    children: const [
                      Expanded(child: Divider()),
                      Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('or')),
                      Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Social buttons
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _loading ? null : _signInWithGoogle,
                      icon: const Icon(Icons.g_mobiledata, size: 24),
                      label: const Text('Continue with Google'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (Platform.isIOS)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _loading ? null : _signInWithApple,
                        icon: const Icon(Icons.apple, size: 24),
                        label: const Text('Continue with Apple'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        ),
                      ),
                    ),

                  const SizedBox(height: 12),
                  Text.rich(
                    TextSpan(
                      text: "By signing in, you agree to our ",
                      children: [
                        TextSpan(
                          text: "Term of Service",
                          style: const TextStyle(color: Colors.blue, decoration: TextDecoration.underline),
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
          ),

          if (_loading)
            Container(color: Colors.black45, child: const Center(child: CircularProgressIndicator())),
        ],
      ),
    );
  }
}
// you have to complete linking the front with the back especially with appstore connection