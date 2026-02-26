import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Upload a file to Firebase Cloud Storage
  /// Returns the download URL
  Future<String> uploadFile({
    required String uid,
    required File file,
    required String fileName,
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final ref = _storage.ref().child('users/$uid/attachments/${timestamp}_$fileName');

    final uploadTask = ref.putFile(file);
    final snapshot = await uploadTask;
    return await snapshot.ref.getDownloadURL();
  }

  /// Upload raw bytes (for compressed images)
  Future<String> uploadBytes({
    required String uid,
    required List<int> bytes,
    required String fileName,
    required String mimeType,
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final ref = _storage.ref().child('users/$uid/attachments/${timestamp}_$fileName');

    final metadata = SettableMetadata(contentType: mimeType);
    final uploadTask = ref.putData(bytes as dynamic, metadata);
    final snapshot = await uploadTask;
    return await snapshot.ref.getDownloadURL();
  }

  /// Delete a file from storage
  Future<void> deleteFile(String url) async {
    try {
      final ref = _storage.refFromURL(url);
      await ref.delete();
    } catch (_) {
      // File might already be deleted
    }
  }

  /// Get total storage used by a user (in bytes)
  Future<int> getUserStorageUsed(String uid) async {
    int totalSize = 0;
    final result = await _storage.ref().child('users/$uid/attachments').listAll();
    for (final item in result.items) {
      final metadata = await item.getMetadata();
      totalSize += metadata.size ?? 0;
    }
    return totalSize;
  }
}
