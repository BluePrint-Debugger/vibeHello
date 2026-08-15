import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/room_event_type.dart';
import '../../repositories/room_repository.dart';

class EventEngine {
  EventEngine(this._repository);

  final RoomRepository _repository;

  //============================================================
  // CREATE EVENT
  //============================================================

  Future<void> createEvent({
    required String roomId,
    required RoomEventType type,
    String? uid,
    String? userName,
    int? seatNumber,
    Map<String, dynamic>? extra,
  }) async {
    await _repository.addEvent(roomId, {
      "type": type.name,
      "uid": uid,
      "userName": userName,
      "seatNumber": seatNumber,
      ...?extra,
    });
  }

  //============================================================
  // EVENT STREAM
  //============================================================

  Stream<QuerySnapshot<Map<String, dynamic>>> streamEvents(String roomId) {
    return _repository.eventStream(roomId);
  }

  //============================================================
  // DELETE EVENT
  //============================================================

  Future<void> deleteEvent({
    required String roomId,
    required String eventId,
  }) async {
    await _repository.events(roomId).doc(eventId).delete();
  }

  //============================================================
  // CLEAR ALL EVENTS
  //============================================================

  Future<void> clearEvents({required String roomId}) async {
    final snapshot = await _repository.events(roomId).get();

    final batch = FirebaseFirestore.instance.batch();

    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
  }
}
