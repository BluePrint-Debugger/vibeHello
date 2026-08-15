import 'package:flutter/material.dart';

import '../../chat/screens/private_chat_screen.dart';
import '../models/room_role.dart';
import '../../../core/app_theme.dart';

/// Lightweight "who is this" sheet for regular users - no destructive
/// admin actions, just a look at who's in the seat and a way to message
/// them. Admins get the fuller _showSeatAdminMenu instead.
Future<void> showMemberInfoSheet({
  required BuildContext context,
  required String userId,
  required String userName,
  required String userPhoto,
  required RoomRole role,
  required Color accentColor,
}) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: context.appColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 36,
                backgroundColor: accentColor.withValues(alpha: 0.18),
                backgroundImage: userPhoto.isNotEmpty
                    ? NetworkImage(userPhoto)
                    : null,
                child: userPhoto.isEmpty
                    ? const Icon(Icons.person, color: Colors.white, size: 32)
                    : null,
              ),
              const SizedBox(height: 12),
              Text(
                userName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                role.label,
                style: TextStyle(color: accentColor, fontSize: 13),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PrivateChatScreen(
                          receiverId: userId,
                          receiverName: userName,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: const Text('Message'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
