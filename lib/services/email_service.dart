import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:business_managment_app/services/supabase_service.dart';

class EmailSendResult {
  final bool success;
  final String message;
  final String subject;
  final String bodyText;
  final bool mailClientOpened;
  final bool sentViaSupabase;
  final String? edgeError;

  const EmailSendResult({
    required this.success,
    required this.message,
    required this.subject,
    required this.bodyText,
    this.mailClientOpened = false,
    this.sentViaSupabase = false,
    this.edgeError,
  });
}

class EmailService {
  static final EmailService _instance = EmailService._();
  factory EmailService() => _instance;
  EmailService._();

  /// Generate subject line for the invitation email
  String getInvitationSubject({
    required String organizationName,
    required String role,
  }) {
    final roleTitle = role.toLowerCase() == 'client' ? 'Client' : 'Team Member';
    return 'Invitation to join $organizationName as a $roleTitle';
  }

  /// Generate formatted plain-text invitation email body
  String getInvitationBody({
    required String receiverEmail,
    required String inviteCode,
    required String role,
    required String organizationName,
    String? inviterName,
  }) {
    final roleTitle = role.toLowerCase() == 'client' ? 'Client Lead' : 'Staff Employee';
    final inviter = inviterName != null && inviterName.isNotEmpty ? inviterName : 'The Administrator';

    return '''Hello,

$inviter has invited you to join "$organizationName" on the Business Management Suite as a $roleTitle.

====================================================
YOUR ACCESS INVITATION CODE:
$inviteCode
====================================================

HOW TO LOG IN USING YOUR CODE:
1. Open the Business Management Suite application.
2. On the Login screen, click "Join with Code" (or select Invitation).
3. Enter your Invitation Code: $inviteCode
4. Enter your email: $receiverEmail
5. Create your password and click "Login with Invitation Code" to access your dashboard.

IMPORTANT:
- This invitation code is unique to your email address ($receiverEmail).
- For security, this access code will expire in 7 days.

If you have any questions or did not expect this invitation, please contact $organizationName.

Best regards,
$organizationName Team
Business Management Suite
''';
  }

  /// Launch a URL in the default browser / system handler using url_launcher
  Future<bool> openUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (launched) return true;
      return await launchUrl(uri);
    } catch (e) {
      debugPrint('EmailService: Error opening URL with url_launcher: $e');
    }
    return false;
  }

  /// Open Gmail Web Compose with pre-filled To, Subject, and Body
  Future<bool> openGmailWeb({
    required String receiverEmail,
    required String subject,
    required String body,
  }) async {
    final gmailUrl =
        'https://mail.google.com/mail/?view=cm&fs=1&to=${Uri.encodeComponent(receiverEmail.trim())}&su=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}';
    final success = await openUrl(gmailUrl);
    if (!success) {
      // Fallback to mailto if browser URL launch failed
      return await openEmailClient(
        receiverEmail: receiverEmail,
        subject: subject,
        body: body,
      );
    }
    return true;
  }

  /// Open Outlook Web Compose with pre-filled To, Subject, and Body
  Future<bool> openOutlookWeb({
    required String receiverEmail,
    required String subject,
    required String body,
  }) async {
    final outlookUrl =
        'https://outlook.live.com/mail/0/deeplink/compose?to=${Uri.encodeComponent(receiverEmail.trim())}&subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}';
    final success = await openUrl(outlookUrl);
    if (!success) {
      return await openEmailClient(
        receiverEmail: receiverEmail,
        subject: subject,
        body: body,
      );
    }
    return true;
  }

  /// Launch the device's default email client (mailto:)
  Future<bool> openEmailClient({
    required String receiverEmail,
    required String subject,
    required String body,
  }) async {
    final uri = Uri(
      scheme: 'mailto',
      path: receiverEmail.trim(),
      queryParameters: {
        'subject': subject,
        'body': body,
      },
    );

    try {
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        return await launchUrl(uri);
      }
    } catch (e) {
      debugPrint('EmailService: Error launching mailto: $e');
    }
    return false;
  }

  /// Send an invitation email to the receiver
  Future<EmailSendResult> sendInvitationEmail({
    required String receiverEmail,
    required String inviteCode,
    required String role,
    required String organizationName,
    String? inviterName,
    bool launchClient = false,
  }) async {
    final cleanEmail = receiverEmail.trim().toLowerCase();
    final subject = getInvitationSubject(
      organizationName: organizationName,
      role: role,
    );
    final body = getInvitationBody(
      receiverEmail: cleanEmail,
      inviteCode: inviteCode,
      role: role,
      organizationName: organizationName,
      inviterName: inviterName,
    );

    bool clientOpened = false;

    // 1. Attempt system email client launch if explicitly requested
    if (launchClient) {
      clientOpened = await openEmailClient(
        receiverEmail: cleanEmail,
        subject: subject,
        body: body,
      );
    }

    // 2. Dispatch to Supabase Edge Function (send-invite-email) with Gmail
    bool sentViaSupabase = false;
    String? edgeErrorMsg;

    try {
      final res = await SupabaseService().client.functions.invoke(
        'send-invite-email',
        body: {
          'to': cleanEmail,
          'code': inviteCode,
          'role': role,
          'organization_name': organizationName,
          'subject': subject,
          'body': body,
        },
      );
      if (res.status == 200) {
        sentViaSupabase = true;
        debugPrint('EmailService: Dispatched via Supabase send-invite-email function!');
      } else {
        edgeErrorMsg = 'Supabase function returned status ${res.status}';
      }
    } catch (edgeErr) {
      edgeErrorMsg = edgeErr.toString();
      debugPrint('EmailService: Edge function notice: $edgeErr');
    }

    // 3. Record in public.notifications / activity log for audit
    try {
      final currentOrgId = SupabaseService().currentOrganizationId;
      final currentUserId = SupabaseService().currentUser?.id;
      if (currentOrgId != null && currentUserId != null) {
        await SupabaseService().client.from('notifications').insert({
          'organization_id': currentOrgId,
          'user_id': currentUserId,
          'title': 'Invitation Created for $cleanEmail',
          'body': 'Access code $inviteCode generated for $cleanEmail ($role).',
          'event_type': 'invitation_sent',
          'payload': {
            'email': cleanEmail,
            'role': role,
            'code': inviteCode,
            'timestamp': DateTime.now().toIso8601String(),
          },
        });
      }
    } catch (dbLogErr) {
      debugPrint('EmailService: Database log notice: $dbLogErr');
    }

    return EmailSendResult(
      success: true,
      message: sentViaSupabase
          ? 'Email sent directly via Supabase & Gmail to $cleanEmail!'
          : 'Invitation prepared for $cleanEmail',
      subject: subject,
      bodyText: body,
      mailClientOpened: clientOpened,
      sentViaSupabase: sentViaSupabase,
      edgeError: edgeErrorMsg,
    );
  }
}
