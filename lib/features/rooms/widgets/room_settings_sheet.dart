import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/room_seat_service.dart';
import 'seat_shape.dart';
import '../../../core/app_theme.dart';

/// Opens the admin room-settings bottom sheet: change the room-wide seat
/// shape, or add more seats. Only call this from admin-gated UI - it
/// doesn't check permissions itself.
Future<void> showRoomSettingsSheet({
  required BuildContext context,
  required String roomId,
  required Color accentColor,
  required SeatDesign currentDesign,
  required int currentSeatLimit,
}) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: context.appColors.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _RoomSettingsSheet(
      roomId: roomId,
      accentColor: accentColor,
      currentDesign: currentDesign,
      currentSeatLimit: currentSeatLimit,
    ),
  );
}

class _RoomSettingsSheet extends StatefulWidget {
  final String roomId;
  final Color accentColor;
  final SeatDesign currentDesign;
  final int currentSeatLimit;

  const _RoomSettingsSheet({
    required this.roomId,
    required this.accentColor,
    required this.currentDesign,
    required this.currentSeatLimit,
  });

  @override
  State<_RoomSettingsSheet> createState() => _RoomSettingsSheetState();
}

class _RoomSettingsSheetState extends State<_RoomSettingsSheet> {
  late SeatDesign _selectedDesign = widget.currentDesign;
  bool _savingDesign = false;
  bool _extendingSeats = false;

  Future<void> _applyDesign(SeatDesign design) async {
    setState(() {
      _selectedDesign = design;
      _savingDesign = true;
    });

    await FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.roomId)
        .set({'seatDesign': design.storageValue}, SetOptions(merge: true));

    if (mounted) setState(() => _savingDesign = false);
  }

  Future<void> _extendSeats() async {
    if (widget.currentSeatLimit >= 16) return;

    setState(() => _extendingSeats = true);

    final newLimit = (widget.currentSeatLimit + 4).clamp(1, 16);
    try {
      await RoomSeatService().extendSeats(
        roomId: widget.roomId,
        newSeatLimit: newLimit,
      );
    } finally {
      if (mounted) setState(() => _extendingSeats = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Room Settings',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Seat design',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 10),
            Row(
              children: SeatDesign.values.map((design) {
                final selected = design == _selectedDesign;
                return Expanded(
                  child: GestureDetector(
                    onTap: _savingDesign ? null : () => _applyDesign(design),
                    child: Container(
                      margin: const EdgeInsets.only(right: 10),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: selected
                            ? widget.accentColor.withValues(alpha: 0.18)
                            : context.appColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: selected
                              ? widget.accentColor
                              : Colors.white12,
                          width: selected ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            design.previewIcon,
                            color: selected
                                ? widget.accentColor
                                : Colors.white54,
                            size: 26,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            design.label,
                            style: TextStyle(
                              color: selected
                                  ? Colors.white
                                  : Colors.white54,
                              fontSize: 12,
                              fontWeight: selected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Seats',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${widget.currentSeatLimit} of 16 max',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: widget.currentSeatLimit >= 16 || _extendingSeats
                      ? null
                      : _extendSeats,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.accentColor,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                  ),
                  child: _extendingSeats
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('+4 Seats'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
