import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class FeedbackService {
  FeedbackService._();

  static Future<void> submitFeedback(
      BuildContext context, String feedback, {String? email}) async {
    // In a real app, this would send to a backend or email
    // For now, we'll just open the email client or show a confirmation
    final uri = Uri.parse(
        'mailto:support@vibehello.com?subject=VibeHello Feedback&body=$feedback');

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }

    // Show confirmation
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Feedback submitted! Thank you for helping us improve.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}