import 'package:flutter/material.dart';

class PlayerVoiceAvatar extends StatelessWidget {
  final String photo;
  final bool micOn;
  final String name;
  final IconData genderIcon;
  final bool isLeftSide;

  const PlayerVoiceAvatar({
    super.key,
    required this.photo,
    required this.micOn,
    required this.name,
    required this.genderIcon,
    required this.isLeftSide,
  });

  @override
  Widget build(BuildContext context) {
    final avatar = Stack(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundImage: photo.isNotEmpty ? NetworkImage(photo) : null,
          child: photo.isEmpty ? const Icon(Icons.person, size: 18) : null,
        ),
        Positioned(
          right: 0,
          bottom: 0,
          child: CircleAvatar(
            radius: 7,
            backgroundColor: micOn ? Colors.greenAccent : Colors.grey,
            child: Icon(
              micOn ? Icons.mic : Icons.mic_off,
              size: 9,
              color: Colors.black,
            ),
          ),
        ),
      ],
    );

    final userInfo = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          name,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 4),
        Icon(genderIcon, size: 14, color: Colors.white70),
      ],
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: isLeftSide
          ? [avatar, const SizedBox(width: 8), userInfo]
          : [userInfo, const SizedBox(width: 8), avatar],
    );
  }
}
