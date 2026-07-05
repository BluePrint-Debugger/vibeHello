import '../repositories/room_repository.dart';
import '../services/seat_service.dart';

class RoomController {
  RoomController._();

  static final RoomController instance = RoomController._();

  final RoomRepository repository = RoomRepository.instance;

  final SeatService seatService = SeatService();
}
