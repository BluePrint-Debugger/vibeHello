enum RoomEventType {
  // Room lifecycle
  roomCreated,
  roomClosed,

  // User lifecycle
  joined,
  left,

  // Seat actions
  switchedSeat,
  seatLocked,
  seatUnlocked,
  seatReserved,
  seatOpened,

  // Voice
  micOn,
  micOff,
  speakingStarted,
  speakingStopped,
  muted,
  unMuted,

  // Permissions
  promoted,
  demoted,
  removed,

  // Lobby
  lobbyJoined,
  lobbyLeft,
  lobbyAccepted,
  lobbyRejected,

  // Invitations
  invited,

  // Chat moderation
  chatBlocked,
  chatUnblocked,

  // Ownership
  hostTransferred,
}
