import 'package:flutter/material.dart';
import '../models/report_model.dart';
import '../services/report_service.dart';
import '../services/block_service.dart';

/// Call this from anywhere a user's name/avatar is tappable, e.g.:
///
///   onLongPress: () => showReportUserSheet(
///     context,
///     reportedUserId: member.uid,
///     context_: 'room:${widget.room.id}',
///   ),
///
/// (Renamed the context string param to context_ to avoid clashing with
/// BuildContext context — rename freely on your end.)
Future<void> showReportUserSheet(
  BuildContext context, {
  required String reportedUserId,
  required String context_,
}) async {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => _ReportSheet(
      reportedUserId: reportedUserId,
      contextTag: context_,
    ),
  );
}

class _ReportSheet extends StatefulWidget {
  final String reportedUserId;
  final String contextTag;

  const _ReportSheet({required this.reportedUserId, required this.contextTag});

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  String? _selectedReason;
  bool _submitting = false;

  Future<void> _submit() async {
    if (_selectedReason == null) return;
    setState(() => _submitting = true);
    try {
      await ReportService.instance.submitReport(
        reportedUserId: widget.reportedUserId,
        reason: _selectedReason!,
        context: widget.contextTag,
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report submitted. Thank you.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _block() async {
    try {
      await BlockService.instance.blockUser(widget.reportedUserId);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User blocked.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Report user', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            RadioGroup<String>(
              groupValue: _selectedReason,
              onChanged: (v) => setState(() => _selectedReason = v),
              child: Column(
                children: kReportReasons
                    .map((r) => RadioListTile<String>(title: Text(r), value: r))
                    .toList(),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _block,
                    child: const Text('Block user'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _selectedReason == null || _submitting ? null : _submit,
                    child: _submitting
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Submit report'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
