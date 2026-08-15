enum RoomRole { listener, speaker, moderator, admin, host }

extension RoomRoleX on RoomRole {
  String get value => name;

  String get label {
    switch (this) {
      case RoomRole.host:
        return 'Host';
      case RoomRole.admin:
        return 'Admin';
      case RoomRole.moderator:
        return 'Moderator';
      case RoomRole.speaker:
        return 'Speaker';
      case RoomRole.listener:
        return 'Listener';
    }
  }

  static RoomRole fromString(String? value) {
    switch (value) {
      case 'host':
        return RoomRole.host;

      case 'admin':
        return RoomRole.admin;

      case 'moderator':
        return RoomRole.moderator;

      case 'speaker':
        return RoomRole.speaker;

      default:
        return RoomRole.listener;
    }
  }
}
