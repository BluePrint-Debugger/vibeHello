import 'package:cloud_firestore/cloud_firestore.dart';

class RoomRepository {
  RoomRepository._();

  static final RoomRepository instance = RoomRepository._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  //============================================================
  // Root Collections
  //============================================================

  CollectionReference<Map<String, dynamic>> get rooms =>
      _firestore.collection('rooms');

  //============================================================
  // Room References
  //============================================================

  DocumentReference<Map<String, dynamic>> room(String roomId) =>
      rooms.doc(roomId);

  CollectionReference<Map<String, dynamic>> seats(String roomId) =>
      room(roomId).collection('seats');

  CollectionReference<Map<String, dynamic>> members(String roomId) =>
      room(roomId).collection('members');

  CollectionReference<Map<String, dynamic>> lobby(String roomId) =>
      room(roomId).collection('lobby');

  CollectionReference<Map<String, dynamic>> admins(String roomId) =>
      room(roomId).collection('admins');

  CollectionReference<Map<String, dynamic>> messages(String roomId) =>
      room(roomId).collection('messages');

  CollectionReference<Map<String, dynamic>> events(String roomId) =>
      room(roomId).collection('room_events');

  //============================================================
  // Transactions
  //============================================================

  Future<T> runTransaction<T>(
    Future<T> Function(Transaction transaction) action,
  ) {
    return _firestore.runTransaction(action);
  }

  WriteBatch batch() => _firestore.batch();

  //============================================================
  // Room
  //============================================================

  Future<DocumentSnapshot<Map<String, dynamic>>> getRoom(String roomId) {
    return room(roomId).get();
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> roomStream(String roomId) {
    return room(roomId).snapshots();
  }

  Future<void> updateRoom(String roomId, Map<String, dynamic> data) {
    return room(roomId).set(data, SetOptions(merge: true));
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> roomsStream() {
    return rooms.orderBy('createdAt', descending: true).snapshots();
  }

  Future<DocumentReference<Map<String, dynamic>>> createRoom(
    Map<String, dynamic> data,
  ) {
    return rooms.add({...data, 'createdAt': FieldValue.serverTimestamp()});
  }

  //============================================================
  // Seats
  //============================================================

  DocumentReference<Map<String, dynamic>> seatRef(
    String roomId,
    int seatNumber,
  ) {
    return seats(roomId).doc("seat_$seatNumber");
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> getSeat(
    String roomId,
    int seatNumber,
  ) {
    return seatRef(roomId, seatNumber).get();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> seatStream(String roomId) {
    return seats(roomId).orderBy("seatNumber").snapshots();
  }

  Future<void> updateSeat(
    String roomId,
    int seatNumber,
    Map<String, dynamic> data,
  ) {
    return seatRef(roomId, seatNumber).set(data, SetOptions(merge: true));
  }

  Future<void> deleteSeat(String roomId, int seatNumber) {
    return seatRef(roomId, seatNumber).delete();
  }

  //============================================================
  // Members
  //============================================================

  DocumentReference<Map<String, dynamic>> memberRef(String roomId, String uid) {
    return members(roomId).doc(uid);
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> getMember(
    String roomId,
    String uid,
  ) {
    return memberRef(roomId, uid).get();
  }

  Future<QuerySnapshot<Map<String, dynamic>>> getMembers(String roomId) {
    return members(roomId).get();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> memberStream(String roomId) {
    return members(roomId).snapshots();
  }

  Future<void> updateMember(
    String roomId,
    String uid,
    Map<String, dynamic> data,
  ) {
    return memberRef(roomId, uid).set(data, SetOptions(merge: true));
  }

  Future<void> deleteMember(String roomId, String uid) {
    return memberRef(roomId, uid).delete();
  }

  //============================================================
  // Lobby
  //============================================================

  DocumentReference<Map<String, dynamic>> lobbyRef(String roomId, String uid) {
    return lobby(roomId).doc(uid);
  }

  Future<void> updateLobbyUser(
    String roomId,
    String uid,
    Map<String, dynamic> data,
  ) {
    return lobbyRef(roomId, uid).set(data, SetOptions(merge: true));
  }

  Future<void> deleteLobbyUser(String roomId, String uid) {
    return lobbyRef(roomId, uid).delete();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> lobbyStream(String roomId) {
    return lobby(roomId).orderBy("joinedAt").snapshots();
  }

  //============================================================
  // Admins
  //============================================================

  Future<void> updateAdmin(
    String roomId,
    String uid,
    Map<String, dynamic> data,
  ) {
    return admins(roomId).doc(uid).set(data, SetOptions(merge: true));
  }

  Future<void> deleteAdmin(String roomId, String uid) {
    return admins(roomId).doc(uid).delete();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> adminStream(String roomId) {
    return admins(roomId).snapshots();
  }

  //============================================================
  // Messages
  //============================================================

  Future<DocumentReference<Map<String, dynamic>>> addMessage(
    String roomId,
    Map<String, dynamic> data,
  ) {
    return messages(
      roomId,
    ).add({...data, "createdAt": FieldValue.serverTimestamp()});
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> messageStream(String roomId) {
    return messages(roomId).orderBy("createdAt").snapshots();
  }

  //============================================================
  // Events
  //============================================================

  Future<DocumentReference<Map<String, dynamic>>> addEvent(
    String roomId,
    Map<String, dynamic> data,
  ) {
    return events(
      roomId,
    ).add({...data, "createdAt": FieldValue.serverTimestamp()});
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> eventStream(String roomId) {
    return events(roomId).orderBy("createdAt", descending: true).snapshots();
  }
}
