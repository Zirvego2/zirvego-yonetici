import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:logger/logger.dart';

/// Firebase Firestore ve Storage işlemleri için merkezi servis
class FirebaseService {
  FirebaseService._();
  static final FirebaseService instance = FirebaseService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final Logger _log = Logger();

  FirebaseFirestore get firestore => _firestore;
  FirebaseStorage get storage => _storage;

  // ── Firestore CRUD ────────────────────────────────────────

  /// Koleksiyona belge ekle (otomatik ID)
  Future<String?> addDocument({
    required String collection,
    required Map<String, dynamic> data,
  }) async {
    try {
      data['createdAt'] = FieldValue.serverTimestamp();
      data['updatedAt'] = FieldValue.serverTimestamp();
      final ref = await _firestore.collection(collection).add(data);
      _log.d('Belge eklendi: ${ref.id}');
      return ref.id;
    } catch (e) {
      _log.e('Belge eklenemedi', error: e);
      return null;
    }
  }

  /// Belirli ID ile belge ekle / güncelle
  Future<bool> setDocument({
    required String collection,
    required String docId,
    required Map<String, dynamic> data,
    bool merge = true,
  }) async {
    try {
      if (merge) {
        data['updatedAt'] = FieldValue.serverTimestamp();
      } else {
        data['createdAt'] = FieldValue.serverTimestamp();
        data['updatedAt'] = FieldValue.serverTimestamp();
      }
      await _firestore
          .collection(collection)
          .doc(docId)
          .set(data, SetOptions(merge: merge));
      return true;
    } catch (e) {
      _log.e('Belge ayarlanamadı', error: e);
      return false;
    }
  }

  /// Belgeyi kısmen güncelle
  Future<bool> updateDocument({
    required String collection,
    required String docId,
    required Map<String, dynamic> data,
  }) async {
    try {
      data['updatedAt'] = FieldValue.serverTimestamp();
      await _firestore.collection(collection).doc(docId).update(data);
      return true;
    } catch (e) {
      _log.e('Belge güncellenemedi', error: e);
      return false;
    }
  }

  /// Belgeyi sil
  Future<bool> deleteDocument({
    required String collection,
    required String docId,
  }) async {
    try {
      await _firestore.collection(collection).doc(docId).delete();
      return true;
    } catch (e) {
      _log.e('Belge silinemedi', error: e);
      return false;
    }
  }

  /// Tek belge getir
  Future<DocumentSnapshot?> getDocument({
    required String collection,
    required String docId,
  }) async {
    try {
      final doc = await _firestore.collection(collection).doc(docId).get();
      return doc.exists ? doc : null;
    } catch (e) {
      _log.e('Belge getirilemedi', error: e);
      return null;
    }
  }

  /// Koleksiyonu listele
  Future<List<QueryDocumentSnapshot>> getCollection({
    required String collection,
    List<List<dynamic>>? whereConditions,
    String? orderBy,
    bool descending = false,
    int? limit,
    DocumentSnapshot? startAfter,
  }) async {
    try {
      Query query = _firestore.collection(collection);

      if (whereConditions != null) {
        for (final condition in whereConditions) {
          if (condition.length == 3) {
            query = query.where(
              condition[0] as String,
              isEqualTo: condition[1] == '==' ? condition[2] : null,
              isGreaterThan: condition[1] == '>' ? condition[2] : null,
              isLessThan: condition[1] == '<' ? condition[2] : null,
              isGreaterThanOrEqualTo: condition[1] == '>=' ? condition[2] : null,
              isLessThanOrEqualTo: condition[1] == '<=' ? condition[2] : null,
            );
          }
        }
      }

      if (orderBy != null) {
        query = query.orderBy(orderBy, descending: descending);
      }

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      if (limit != null) {
        query = query.limit(limit);
      }

      final snapshot = await query.get();
      return snapshot.docs;
    } catch (e) {
      _log.e('Koleksiyon getirilemedi', error: e);
      return [];
    }
  }

  /// Gerçek zamanlı belge dinle
  Stream<DocumentSnapshot> watchDocument({
    required String collection,
    required String docId,
  }) {
    return _firestore.collection(collection).doc(docId).snapshots();
  }

  /// Gerçek zamanlı koleksiyon dinle
  Stream<QuerySnapshot> watchCollection({
    required String collection,
    String? orderBy,
    bool descending = false,
    int? limit,
  }) {
    Query query = _firestore.collection(collection);
    if (orderBy != null) {
      query = query.orderBy(orderBy, descending: descending);
    }
    if (limit != null) {
      query = query.limit(limit);
    }
    return query.snapshots();
  }

  // ── Storage ───────────────────────────────────────────────

  /// Dosya yükle
  Future<String?> uploadFile({
    required String path,
    required List<int> bytes,
    String? contentType,
  }) async {
    try {
      final ref = _storage.ref().child(path);
      final metadata = contentType != null
          ? SettableMetadata(contentType: contentType)
          : null;
      await ref.putData(Uint8List.fromList(bytes), metadata);
      final url = await ref.getDownloadURL();
      return url;
    } catch (e) {
      _log.e('Dosya yüklenemedi', error: e);
      return null;
    }
  }

  /// Dosyayı sil
  Future<bool> deleteFile({required String path}) async {
    try {
      await _storage.ref().child(path).delete();
      return true;
    } catch (e) {
      _log.e('Dosya silinemedi', error: e);
      return false;
    }
  }
}
