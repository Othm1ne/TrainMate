import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class StorageService {
  StorageService._();
  static final instance = StorageService._();

  /// Uploads [localPath] to [storagePath] and returns its download URL.
  /// URLs (already uploaded images) are returned unchanged.
  Future<String?> upload(String? localPath, String storagePath) async {
    if (localPath == null || localPath.isEmpty) return null;
    if (localPath.startsWith('http')) return localPath;
    final ref = FirebaseStorage.instance.ref(storagePath);
    // XFile works on every platform (including web blob URLs).
    final bytes = await XFile(localPath).readAsBytes();
    await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
    return ref.getDownloadURL();
  }
}
