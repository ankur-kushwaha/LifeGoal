import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';
import '../models/notification_model.dart';

abstract class BaseNotificationService {
  Stream<List<AppNotification>> streamNotifications(String familyId);
  Future<List<AppNotification>> getRecentNotifications(String familyId, {int limit = 5});
  Future<void> saveNotification(String familyId, AppNotification notification);
  Future<void> markAsRead(String familyId, String notificationId);
  Future<void> markAllAsRead(String familyId);
  Future<void> deleteNotification(String familyId, String notificationId);
  Future<void> clearAllNotifications(String familyId);
}

class FirestoreNotificationService implements BaseNotificationService {
  FirestoreNotificationService()
      : _firestore = FirebaseFirestore.instanceFor(
          app: Firebase.app(),
          databaseId: kFirestoreDatabaseId,
        );

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _ref(String familyId) =>
      _firestore.collection('families').doc(familyId).collection('notifications');

  @override
  Stream<List<AppNotification>> streamNotifications(String familyId) {
    return _ref(familyId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(_fromDoc).toList());
  }

  @override
  Future<List<AppNotification>> getRecentNotifications(
    String familyId, {
    int limit = 5,
  }) async {
    final snapshot = await _ref(familyId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return snapshot.docs.map(_fromDoc).toList();
  }

  @override
  Future<void> saveNotification(String familyId, AppNotification notification) async {
    await _ref(familyId).doc(notification.id).set(notification.toJson());
  }

  @override
  Future<void> markAsRead(String familyId, String notificationId) async {
    await _ref(familyId).doc(notificationId).update({'isRead': true});
  }

  @override
  Future<void> markAllAsRead(String familyId) async {
    final snapshot = await _ref(familyId).where('isRead', isEqualTo: false).get();
    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  @override
  Future<void> deleteNotification(String familyId, String notificationId) async {
    await _ref(familyId).doc(notificationId).delete();
  }

  @override
  Future<void> clearAllNotifications(String familyId) async {
    final snapshot = await _ref(familyId).get();
    if (snapshot.docs.isEmpty) return;

    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  AppNotification _fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = Map<String, dynamic>.from(doc.data());
    if (data['id'] == null) {
      data['id'] = doc.id;
    }
    return AppNotification.fromJson(data);
  }
}

class SharedPreferencesNotificationService implements BaseNotificationService {
  final Map<String, StreamController<List<AppNotification>>> _controllers = {};

  String _key(String familyId) => 'notifications_$familyId';

  StreamController<List<AppNotification>> _controller(String familyId) {
    return _controllers.putIfAbsent(familyId, () {
      final controller = StreamController<List<AppNotification>>.broadcast();
      _load(familyId).then((list) => controller.add(list));
      return controller;
    });
  }

  Future<List<AppNotification>> _load(String familyId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key(familyId));
      if (raw == null) return [];
      final decoded = json.decode(raw) as List;
      final list = decoded
          .map((item) => AppNotification.fromJson(item as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    } catch (_) {
      return [];
    }
  }

  Future<void> _persist(String familyId, List<AppNotification> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key(familyId),
      json.encode(list.map((n) => n.toJson()).toList()),
    );
    _controller(familyId).add(list);
  }

  @override
  Stream<List<AppNotification>> streamNotifications(String familyId) {
    return _controller(familyId).stream;
  }

  @override
  Future<List<AppNotification>> getRecentNotifications(
    String familyId, {
    int limit = 5,
  }) async {
    final list = await _load(familyId);
    return list.take(limit).toList();
  }

  @override
  Future<void> saveNotification(String familyId, AppNotification notification) async {
    final list = await _load(familyId);
    final updated = [notification, ...list.where((n) => n.id != notification.id)];
    updated.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    await _persist(familyId, updated);
  }

  @override
  Future<void> markAsRead(String familyId, String notificationId) async {
    final list = await _load(familyId);
    final updated = list
        .map((n) => n.id == notificationId ? n.copyWith(isRead: true) : n)
        .toList();
    await _persist(familyId, updated);
  }

  @override
  Future<void> markAllAsRead(String familyId) async {
    final list = await _load(familyId);
    final updated = list.map((n) => n.copyWith(isRead: true)).toList();
    await _persist(familyId, updated);
  }

  @override
  Future<void> deleteNotification(String familyId, String notificationId) async {
    final list = await _load(familyId);
    final updated = list.where((n) => n.id != notificationId).toList();
    await _persist(familyId, updated);
  }

  @override
  Future<void> clearAllNotifications(String familyId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(familyId));
    _controller(familyId).add([]);
  }
}
