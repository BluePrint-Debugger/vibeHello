import 'package:cloud_firestore/cloud_firestore.dart';

class RoomRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get rooms =>
      _firestore.collection('rooms');

  DocumentReference<Map<String, dynamic>> room(String roomId) =>
      rooms.doc(roomId);

  CollectionReference<Map<String, dynamic>> seats(String roomId) =>
      room(roomId).collection('seats');

  CollectionReference<Map<String, dynamic>> lobby(String roomId) =>
      room(roomId).collection('lobby');

  CollectionReference<Map<String, dynamic>> admins(String roomId) =>
      room(roomId).collection('admins');

  CollectionReference<Map<String, dynamic>> messages(String roomId) =>
      room(roomId).collection('messages');

  CollectionReference<Map<String, dynamic>> events(String roomId) =>
      room(roomId).collection('room_events');

  CollectionReference<Map<String, dynamic>> members(String roomId) =>
      room(roomId).collection('members');
}
