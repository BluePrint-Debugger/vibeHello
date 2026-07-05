enum RoomRole { host, admin, moderator, speaker, listener }

class PermissionService {
  static bool canManageRoom(RoomRole role) {
    return role == RoomRole.host ||
        role == RoomRole.admin ||
        role == RoomRole.moderator;
  }

  static bool canMute(RoomRole role) {
    return canManageRoom(role);
  }

  static bool canRemove(RoomRole role) {
    return canManageRoom(role);
  }

  static bool canInvite(RoomRole role) {
    return canManageRoom(role);
  }

  static bool canLockSeat(RoomRole role) {
    return role == RoomRole.host || role == RoomRole.admin;
  }

  static bool canUnlockSeat(RoomRole role) {
    return role == RoomRole.host || role == RoomRole.admin;
  }

  static bool canPromoteAdmin(RoomRole role) {
    return role == RoomRole.host;
  }

  static bool canTransferHost(RoomRole role) {
    return role == RoomRole.host;
  }

  static bool canDeleteMessage(RoomRole role) {
    return canManageRoom(role);
  }

  static bool canMuteChat(RoomRole role) {
    return role == RoomRole.host || role == RoomRole.admin;
  }

  static bool canSpeak(RoomRole role) {
    return role != RoomRole.listener;
  }
}
