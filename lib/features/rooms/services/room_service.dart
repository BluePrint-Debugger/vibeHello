import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/room_model.dart';
import 'room_seat_service.dart';

class RoomService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final RoomSeatService _seatService = RoomSeatService();

  Stream<List<RoomModel>> getRooms() {
    return _firestore
        .collection('rooms')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => RoomModel.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  Future<void> createRoom({
    required String title,
    required String createdBy,
    required bool isPrivate,
    String? password,
    required String roomType,
  }) async {
    final roomRef = await _firestore.collection('rooms').add({
      'title': title,
      'createdBy': createdBy,
      'usersCount': 0,
      'isPrivate': isPrivate,
      'password': password,
      'roomType': roomType,
      'seatLimit': 8,
      'maxSeatLimit': 12,
      'createdAt': FieldValue.serverTimestamp(),
    });

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(createdBy)
        .get();

    final userData = userDoc.data() ?? {};

    await _seatService.setupRoomSeats(
      roomId: roomRef.id,
      creatorId: createdBy,
      creatorName: userData['name'] ?? 'Player',
      creatorPhoto: userData['photo'] ?? '',
    );
  }
}
