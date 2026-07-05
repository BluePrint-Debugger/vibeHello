import 'package:cloud_firestore/cloud_firestore.dart';

class RoomSeatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> setupRoomSeats({
    required String roomId,
    required String creatorId,
    required String creatorName,
    required String creatorPhoto,
  }) async {
    final roomRef = _firestore.collection('rooms').doc(roomId);

    await roomRef.set({
      'seatLimit': 8,
      'maxSeatLimit': 16,
    }, SetOptions(merge: true));

    await roomRef.collection('admins').doc(creatorId).set({
      'userId': creatorId,
      'addedBy': creatorId,
      'createdAt': FieldValue.serverTimestamp(),
    });

    for (int i = 1; i <= 8; i++) {
      await roomRef.collection('seats').doc(i.toString()).set({
        'seatNumber': i,
        'isLocked': false,
        'userId': i == 1 ? creatorId : null,
        'userName': i == 1 ? creatorName : null,
        'userPhoto': i == 1 ? creatorPhoto : null,
        'isMicOn': i == 1,
        'isSpeaking': false,
        'mutedByAdmin': false,
      });
    }

    await addRoomEvent(
      roomId: roomId,
      text: '$creatorName created the room',
      type: 'system',
    );
  }

  Future<void> enterLobby({
    required String roomId,
    required String userId,
    required String userName,
    required String userPhoto,
  }) async {
    final roomRef = _firestore.collection('rooms').doc(roomId);

    await roomRef.collection('lobby').doc(userId).set({
      'userId': userId,
      'userName': userName,
      'userPhoto': userPhoto,
      'joinedAt': FieldValue.serverTimestamp(),
      'canMessage': true,
    }, SetOptions(merge: true));

    await addRoomEvent(
      roomId: roomId,
      text: '$userName entered the room',
      type: 'entered',
    );
  }

  Future<void> sitOnSeat({
    required String roomId,
    required int seatNumber,
    required String userId,
    required String userName,
    required String userPhoto,
  }) async {
    final roomRef = _firestore.collection('rooms').doc(roomId);
    final seatRef = roomRef.collection('seats').doc(seatNumber.toString());

    final seatDoc = await seatRef.get();
    final seatData = seatDoc.data() ?? {};

    if (seatData['isLocked'] == true || seatData['userId'] != null) {
      throw Exception('Seat is not available');
    }

    await removeUserFromAnySeat(roomId: roomId, userId: userId);

    await seatRef.update({
      'userId': userId,
      'userName': userName,
      'userPhoto': userPhoto,
      'isMicOn': true,
      'isSpeaking': false,
      'mutedByAdmin': false,
    });

    await roomRef.collection('lobby').doc(userId).delete();

    await addRoomEvent(
      roomId: roomId,
      text: '$userName took seat $seatNumber',
      type: 'seat_joined',
    );
  }

  Future<void> removeUserFromAnySeat({
    required String roomId,
    required String userId,
  }) async {
    final seats = await _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('seats')
        .where('userId', isEqualTo: userId)
        .get();

    for (final doc in seats.docs) {
      await doc.reference.update({
        'userId': null,
        'userName': null,
        'userPhoto': null,
        'isMicOn': false,
        'isSpeaking': false,
        'mutedByAdmin': false,
      });
    }
  }

  Future<void> leaveSeat({
    required String roomId,
    required int seatNumber,
    required String userName,
  }) async {
    await _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('seats')
        .doc(seatNumber.toString())
        .update({
          'userId': null,
          'userName': null,
          'userPhoto': null,
          'isMicOn': false,
          'isSpeaking': false,
          'mutedByAdmin': false,
        });

    await addRoomEvent(
      roomId: roomId,
      text: '$userName left seat $seatNumber',
      type: 'seat_left',
    );
  }

  Future<void> toggleSeatLock({
    required String roomId,
    required int seatNumber,
    required bool isLocked,
  }) async {
    await _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('seats')
        .doc(seatNumber.toString())
        .update({'isLocked': isLocked});
  }

  Future<void> toggleMic({
    required String roomId,
    required String userId,
    required bool isMicOn,
  }) async {
    final seats = await _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('seats')
        .where('userId', isEqualTo: userId)
        .get();

    for (final doc in seats.docs) {
      final data = doc.data();

      if (data['mutedByAdmin'] == true && isMicOn) {
        throw Exception('You are muted by admin');
      }

      await doc.reference.update({'isMicOn': isMicOn});
    }
  }

  Future<void> adminMuteUser({
    required String roomId,
    required int seatNumber,
    required bool muted,
  }) async {
    await _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('seats')
        .doc(seatNumber.toString())
        .update({
          'mutedByAdmin': muted,
          'isMicOn': muted ? false : FieldValue.delete(),
        });
  }

  Future<void> setSpeakingStatus({
    required String roomId,
    required String userId,
    required bool isSpeaking,
  }) async {
    final seats = await _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('seats')
        .where('userId', isEqualTo: userId)
        .get();

    for (final doc in seats.docs) {
      await doc.reference.update({'isSpeaking': isSpeaking});
    }
  }

  Future<void> makeAdmin({
    required String roomId,
    required String userId,
    required String addedBy,
  }) async {
    await _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('admins')
        .doc(userId)
        .set({
          'userId': userId,
          'addedBy': addedBy,
          'createdAt': FieldValue.serverTimestamp(),
        });
  }

  Future<void> setUserMessagePermission({
    required String roomId,
    required String userId,
    required bool canMessage,
  }) async {
    await _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('lobby')
        .doc(userId)
        .set({'canMessage': canMessage}, SetOptions(merge: true));
  }

  Future<void> extendSeats({
    required String roomId,
    required int newSeatLimit,
  }) async {
    if (newSeatLimit > 16) {
      throw Exception('Maximum 16 seats allowed');
    }

    final roomRef = _firestore.collection('rooms').doc(roomId);

    final currentSeats = await roomRef.collection('seats').get();
    final currentCount = currentSeats.docs.length;

    for (int i = currentCount + 1; i <= newSeatLimit; i++) {
      await roomRef.collection('seats').doc(i.toString()).set({
        'seatNumber': i,
        'isLocked': false,
        'userId': null,
        'userName': null,
        'userPhoto': null,
        'isMicOn': false,
        'isSpeaking': false,
        'mutedByAdmin': false,
      });
    }

    await roomRef.set({'seatLimit': newSeatLimit}, SetOptions(merge: true));
  }

  Future<void> addRoomEvent({
    required String roomId,
    required String text,
    required String type,
  }) async {
    await _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('room_events')
        .add({
          'text': text,
          'type': type,
          'createdAt': FieldValue.serverTimestamp(),
        });
  }
}
