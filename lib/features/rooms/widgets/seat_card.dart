import 'package:flutter/material.dart';

import '../models/member_model.dart';
import '../models/room_role.dart';
import '../models/seat_model.dart';
import '../../../core/app_theme.dart';

typedef SeatTapCallback = Future<void> Function(SeatModel seat);
typedef SeatLongPressCallback = Future<void> Function(SeatModel seat);

class SeatCard extends StatelessWidget {
  final SeatModel seat;

  final MemberModel? member;

  final bool isCurrentUser;

  final bool isHost;

  final bool isAdmin;

  final Color accentColor;

  final SeatTapCallback? onTap;

  final SeatLongPressCallback? onLongPress;

  const SeatCard({
    super.key,
    required this.seat,
    required this.member,
    required this.accentColor,
    required this.isCurrentUser,
    required this.isHost,
    required this.isAdmin,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final locked = seat.state == SeatState.locked;
    final reserved = seat.state == SeatState.reserved;
    final occupied = seat.state == SeatState.occupied;
    final speaking = seat.isSpeaking;

    return GestureDetector(
      onTap: onTap == null ? null : () => onTap!(seat),
      onLongPress: !isAdmin ? null : () => onLongPress?.call(seat),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: const Color(0xff111827),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: _borderColor(occupied, locked, reserved, speaking),
            width: speaking ? 3 : 2,
          ),
          boxShadow: speaking
              ? [
                  BoxShadow(
                    color: Colors.greenAccent.withValues(alpha: 0.35),
                    blurRadius: 18,
                    spreadRadius: 2,
                  ),
                ]
              : [],
        ),
        child: Stack(
          children: [
            Positioned.fill(child: _buildCenter()),

            Positioned(
              top: 10,
              left: 10,
              child: _SeatNumber(number: seat.seatNumber),
            ),

            if (occupied)
              Positioned(
                top: 10,
                right: 10,
                child: _RoleBadge(role: member?.role ?? RoomRole.listener),
              ),

            if (occupied)
              Positioned(
                bottom: 10,
                right: 10,
                child: _MicBadge(
                  micOn: member?.micOn ?? false,
                  muted: member?.mutedByAdmin ?? false,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCenter() {
    if (seat.state == SeatState.locked) {
      return const Center(
        child: Icon(Icons.lock, color: Colors.amber, size: 36),
      );
    }

    if (seat.state == SeatState.reserved) {
      return const Center(
        child: Icon(Icons.bookmark, color: Colors.orange, size: 34),
      );
    }

    if (seat.state == SeatState.open) {
      return Center(
        child: Icon(Icons.add_circle_outline, color: accentColor, size: 40),
      );
    }

    return Center(
      child: _Avatar(member: member, speaking: seat.isSpeaking),
    );
  }

  Color _borderColor(bool occupied, bool locked, bool reserved, bool speaking) {
    if (locked) return Colors.amber;

    if (reserved) return Colors.orange;

    if (speaking) return Colors.greenAccent;

    if (occupied) return accentColor;

    return Colors.grey.shade700;
  }
}

class _SeatNumber extends StatelessWidget {
  final int number;

  const _SeatNumber({required this.number});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black45,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '#$number',
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  final RoomRole role;

  const _RoleBadge({required this.role});

  Color get _color {
    switch (role) {
      case RoomRole.host:
        return Colors.amber;
      case RoomRole.admin:
        return Colors.redAccent;
      case RoomRole.moderator:
        return Colors.deepPurpleAccent;
      case RoomRole.speaker:
        return Colors.greenAccent;
      case RoomRole.listener:
        return Colors.white38;
    }
  }

  IconData get _icon {
    switch (role) {
      case RoomRole.host:
        return Icons.star;
      case RoomRole.admin:
        return Icons.shield;
      case RoomRole.moderator:
        return Icons.verified_user;
      case RoomRole.speaker:
        return Icons.campaign;
      case RoomRole.listener:
        return Icons.hearing;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Listeners don't get a badge - keeps the seat visually uncluttered
    // for the common case.
    if (role == RoomRole.listener) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: const BoxDecoration(
        color: Colors.black54,
        shape: BoxShape.circle,
      ),
      child: Icon(_icon, size: 12, color: _color),
    );
  }
}

class _MicBadge extends StatelessWidget {
  final bool micOn;
  final bool muted;

  const _MicBadge({required this.micOn, required this.muted});

  @override
  Widget build(BuildContext context) {
    final isMuted = muted || !micOn;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isMuted
            ? Colors.redAccent.withValues(alpha: 0.85)
            : Colors.greenAccent.withValues(alpha: 0.85),
        shape: BoxShape.circle,
      ),
      child: Icon(
        isMuted ? Icons.mic_off : Icons.mic,
        size: 12,
        color: Colors.black,
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final MemberModel? member;
  final bool speaking;

  const _Avatar({required this.member, required this.speaking});

  @override
  Widget build(BuildContext context) {
    final hasPhoto = member?.photo.isNotEmpty ?? false;
    final initial = (member?.name.isNotEmpty ?? false)
        ? member!.name[0].toUpperCase()
        : '?';

    return CircleAvatar(
      radius: 28,
      backgroundColor: speaking
          ? Colors.greenAccent.withValues(alpha: 0.25)
          : context.appColors.surfaceVariant,
      backgroundImage: hasPhoto ? NetworkImage(member!.photo) : null,
      child: hasPhoto
          ? null
          : Text(
              initial,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
    );
  }
}
