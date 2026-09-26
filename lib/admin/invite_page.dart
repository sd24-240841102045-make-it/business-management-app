import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:business_managment_app/services/supabase_service.dart';
import 'package:business_managment_app/services/app_data_store.dart';
import 'package:business_managment_app/services/email_service.dart';
import 'package:business_managment_app/services/invitation_service.dart';
import 'package:business_managment_app/services/notification_service.dart';
import 'package:business_managment_app/core/premium_theme.dart';
import 'dart:math';

class InvitePage extends StatefulWidget {
  const InvitePage({super.key});

  @override
  State<InvitePage> createState() => _InvitePageState();
}

class _InvitePageState extends State<InvitePage> {
  String _selectedRole = 'employee';
  final TextEditingController _emailController = TextEditingController();
  bool _isLoading = false;
  String? _generatedCode;
  String? _sentToEmail;
  String? _sentRole;
  EmailSendResult? _emailResult;
  String? _errorMessage;

  // Invitations history state
  List<InvitationModel> _invitations = [];
  bool _loadingHistory = true;

  @override
  void initState() {
    super.initState();
    _loadInvitationsHistory();
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadInvitationsHistory() async {
    setState(() => _loadingHistory = true);
    try {
      final list = await InvitationService().fetchInvitations();
      if (mounted) {
        setState(() {
          _invitations = list;
          _loadingHistory = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loadingHistory = false);
      }
    }
  }

  String _generateRandomCode(int length) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rnd = Random.secure();
    return String.fromCharCodes(Iterable.generate(
      length,
      (_) => chars.codeUnitAt(rnd.nextInt(chars.length)),
    ));
  }

  Future<void> _generateInvite() async {
    setState(() {
      _isLoading = true;
      _generatedCode = null;
      _sentToEmail = null;
      _emailResult = null;
      _errorMessage = null;
    });

    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() {
        _errorMessage = 'Please enter a valid email address.';
        _isLoading = false;
      });
      return;
    }

    try {
      final orgId = SupabaseService().currentOrganizationId ?? 'org_default';
      final userId = SupabaseService().currentUser?.id ?? 'admin_user';
      final orgName = SupabaseService().currentOrganization?['name'] as String? ?? 'Enterprise Workspace';
      final inviterName = SupabaseService().currentUser?.userMetadata?['full_name'] as String? ?? 'Administrator';

      // Generate a 6-character code e.g. "AB4X9Z"
      final code = _generateRandomCode(6);
      
      // Calculate expiration (7 days from now)
      final expiresAt = DateTime.now().add(const Duration(days: 7)).toIso8601String();
      
      try {
        await SupabaseService().client.from('invitations').insert({
          'organization_id': orgId,
          'token': code,
          'role': _selectedRole,
          'email': email,
          'invited_by': userId,
          'expires_at': expiresAt,
          'status': 'pending',
        });
      } catch (dbErr) {
        debugPrint('Invitations DB insert notice: $dbErr');
      }

      if (_selectedRole == 'client') {
        final namePart = email.contains('@') ? email.split('@').first : email;
        try {
          await SupabaseService().client.from('clients').upsert({
            'organization_id': orgId,
            'client_type': 'business',
            'contact_name': namePart,
            'company_name': namePart,
            'email': email,
            'status': 'Active',
          });
        } catch (e) {
          debugPrint('Error auto-upserting client record: $e');
        }
      }

      // Generate the invitation message & details
      final emailResult = await EmailService().sendInvitationEmail(
        receiverEmail: email,
        inviteCode: code,
        role: _selectedRole,
        organizationName: orgName,
        inviterName: inviterName,
        launchClient: false, // Don't block with native process; user can choose Gmail/Outlook/Mail app buttons
      );

      try {
        await AppDataStore().refreshFromSupabase();
      } catch (_) {}

      // Refresh invitations list
      _loadInvitationsHistory();

      setState(() {
        _generatedCode = code;
        _sentToEmail = email;
        _sentRole = _selectedRole;
        _emailResult = emailResult;
      });

      // Dispatch clean in-app notification & toast
      NotificationService().notifyLocal(
        type: NotificationType.invitationSent,
        title: '📩 Invitation Created for $email',
        body: 'Access Code: $code generated for ${_selectedRole.toUpperCase()}.',
        payload: {
          'email': email,
          'code': code,
          'role': _selectedRole,
        },
        saveToDatabase: false,
      );
    } catch (e) {
      final errText = e.toString().replaceAll('Exception: ', '');
      if (errText.contains('ClientException') || errText.contains('Failed host lookup') || errText.contains('SocketException')) {
        setState(() {
          _errorMessage = 'Network connection issue. Please check your internet connection and try again.';
        });
      } else {
        setState(() {
          _errorMessage = errText;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showMessageDialog(InvitationModel invite) {
    final orgName = SupabaseService().currentOrganization?['name'] as String? ?? 'Enterprise Workspace';
    final inviterName = SupabaseService().currentUser?.userMetadata?['full_name'] as String? ?? 'Administrator';

    final subject = EmailService().getInvitationSubject(
      organizationName: orgName,
      role: invite.role,
    );
    final body = EmailService().getInvitationBody(
      receiverEmail: invite.email,
      inviteCode: invite.token,
      role: invite.role,
      organizationName: orgName,
      inviterName: inviterName,
    );

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: kPremiumSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: kPremiumBorder),
        ),
        title: Row(
          children: [
            const Icon(Icons.mark_email_read_outlined, color: kPremiumGold, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Invitation Message for ${invite.email}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: kPremiumText),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 550,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Access Code Banner
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: kPremiumGold.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: kPremiumGold.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('ACCESS CODE', style: TextStyle(fontSize: 10, color: kPremiumMuted, fontWeight: FontWeight.bold)),
                          Text(
                            invite.token,
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 4, color: kPremiumGold),
                          ),
                        ],
                      ),
                      IconButton(
                        tooltip: 'Copy Code',
                        icon: const Icon(Icons.copy, color: kPremiumGold),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: invite.token));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Code copied to clipboard!'), backgroundColor: Colors.green),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Message Text
                const Text('Email Message Body:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: kPremiumMuted)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black38,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: SelectableText(
                    body,
                    style: const TextStyle(fontSize: 12, fontFamily: 'monospace', height: 1.4, color: kPremiumText),
                  ),
                ),
                const SizedBox(height: 16),

                // Dispatch Options
                const Text('Send / Share Options:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: kPremiumGold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent.shade700,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.email, size: 16),
                      label: const Text('Send via Gmail'),
                      onPressed: () async {
                        Clipboard.setData(ClipboardData(text: body));
                        await EmailService().openGmailWeb(
                          receiverEmail: invite.email,
                          subject: subject,
                          body: body,
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Opening Gmail... (Invitation text copied to clipboard as backup)'),
                              backgroundColor: Colors.blueAccent,
                              duration: Duration(seconds: 3),
                            ),
                          );
                        }
                      },
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0078D4),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.mail_outline, size: 16),
                      label: const Text('Send via Outlook'),
                      onPressed: () async {
                        Clipboard.setData(ClipboardData(text: body));
                        await EmailService().openOutlookWeb(
                          receiverEmail: invite.email,
                          subject: subject,
                          body: body,
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Opening Outlook... (Invitation text copied to clipboard)'),
                              backgroundColor: Colors.blueAccent,
                              duration: Duration(seconds: 3),
                            ),
                          );
                        }
                      },
                    ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: kPremiumGold),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.mark_email_unread_outlined, size: 16, color: kPremiumGold),
                      label: const Text('Default Mail App', style: TextStyle(color: kPremiumGold)),
                      onPressed: () => EmailService().openEmailClient(
                        receiverEmail: invite.email,
                        subject: subject,
                        body: body,
                      ),
                    ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.white.withOpacity(0.3)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.copy_all, size: 16, color: kPremiumText),
                      label: const Text('Copy Message', style: TextStyle(color: kPremiumText)),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: body));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Message copied to clipboard!'), backgroundColor: Colors.green),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Close', style: TextStyle(color: kPremiumMuted)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool canPop = Navigator.canPop(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: canPop
            ? Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: kPremiumGold.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: kPremiumGold.withOpacity(0.3)),
                    ),
                    child: const Icon(Icons.arrow_back, color: kPremiumGold, size: 20),
                  ),
                  onPressed: () => Navigator.pop(context),
                  tooltip: 'Back to Dashboard',
                ),
              )
            : null,
        title: const Text(
          'Invite Members & Access Codes',
          style: TextStyle(color: kPremiumText, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh Invitations',
            icon: const Icon(Icons.refresh, color: kPremiumGold),
            onPressed: _loadInvitationsHistory,
          ),
        ],
      ),
      body: SafeArea(
        bottom: true,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final bool isMobile = constraints.maxWidth < 600;
            final double cardPadding = isMobile ? 18.0 : 28.0;
            final double pagePadding = isMobile ? 12.0 : 20.0;
            final double bottomInset = MediaQuery.of(context).padding.bottom + 50.0;

            return SingleChildScrollView(
              padding: EdgeInsets.only(
                left: pagePadding,
                right: pagePadding,
                top: pagePadding,
                bottom: bottomInset,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 860),
                  child: Padding(
                    padding: EdgeInsets.all(pagePadding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const HeroBanner(
                          title: 'Invite Team & Clients',
                          subtitle: 'Generate access codes and send pre-formatted invitation emails',
                          badge: 'Access & Onboarding',
                        ),
                        const SizedBox(height: 20),

                        // MAIN INVITATION CREATION CARD
                        GlassCard(
                          padding: EdgeInsets.all(cardPadding),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: const [
                                  PremiumAvatar(
                                    icon: Icons.mark_email_read_outlined,
                                    style: AvatarStyle.glowIcon,
                                    size: 44,
                                  ),
                                  SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Generate Access Invitation',
                                          style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                            color: kPremiumText,
                                          ),
                                        ),
                                        SizedBox(height: 2),
                                        Text(
                                          'Generates a unique 6-character code and prepares the invitation message.',
                                          style: TextStyle(color: kPremiumMuted, fontSize: 13),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 32, color: Colors.white10),

                              // Email Input
                              const Text(
                                'Receiver Email Address',
                                style: TextStyle(fontWeight: FontWeight.bold, color: kPremiumText),
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                controller: _emailController,
                                style: const TextStyle(color: kPremiumText),
                                decoration: InputDecoration(
                                  hintText: 'e.g. member@company.com',
                                  hintStyle: const TextStyle(color: kPremiumMuted),
                                  prefixIcon: const Icon(Icons.email_outlined, color: kPremiumGold),
                                  filled: true,
                                  fillColor: kPremiumSurface.withOpacity(0.5),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(color: kPremiumGold),
                                  ),
                                ),
                                keyboardType: TextInputType.emailAddress,
                              ),
                              const SizedBox(height: 24),
                              
                              // Role Selector
                              const Text(
                                'Select Target Account Role',
                                style: TextStyle(fontWeight: FontWeight.bold, color: kPremiumText),
                              ),
                              const SizedBox(height: 10),
                              isMobile
                                  ? Column(
                                      children: [
                                        _roleOptionCard(
                                          title: 'Employee',
                                          subtitle: 'Full staff portal access',
                                          value: 'employee',
                                          icon: Icons.badge_outlined,
                                        ),
                                        const SizedBox(height: 10),
                                        _roleOptionCard(
                                          title: 'Client',
                                          subtitle: 'Client portal lead',
                                          value: 'client',
                                          icon: Icons.business_outlined,
                                        ),
                                      ],
                                    )
                                  : Row(
                                      children: [
                                        Expanded(
                                          child: _roleOptionCard(
                                            title: 'Employee',
                                            subtitle: 'Full staff portal access',
                                            value: 'employee',
                                            icon: Icons.badge_outlined,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: _roleOptionCard(
                                            title: 'Client',
                                            subtitle: 'Client portal lead',
                                            value: 'client',
                                            icon: Icons.business_outlined,
                                          ),
                                        ),
                                      ],
                                    ),
                              const SizedBox(height: 28),

                              // Generate Button
                              GoldButton(
                                label: 'Generate Code & Prepare Email',
                                icon: Icons.send_rounded,
                                isLoading: _isLoading,
                                onPressed: _generateInvite,
                              ),
                              
                              if (_errorMessage != null) ...[
                                const SizedBox(height: 20),
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          _errorMessage!,
                                          style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],

                              // ACTIVE GENERATED CODE & EMAIL CARD
                              if (_generatedCode != null && _sentToEmail != null) ...[
                                const SizedBox(height: 28),
                                Container(
                                  padding: EdgeInsets.all(isMobile ? 16 : 22),
                                  decoration: BoxDecoration(
                                    color: kPremiumSurface.withOpacity(0.7),
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(color: kPremiumGold.withOpacity(0.4), width: 1.5),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      // Status Header
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.green.withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: Colors.green.withOpacity(0.3)),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 22),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    _emailResult?.sentViaSupabase == true
                                                        ? 'Email Dispatched via Supabase & Gmail'
                                                        : 'Invitation Code Created & Message Ready',
                                                    style: const TextStyle(
                                                      color: Colors.greenAccent,
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    _emailResult?.sentViaSupabase == true
                                                        ? 'Email was sent directly to $_sentToEmail via Supabase & Gmail.'
                                                        : 'Invitation prepared for $_sentToEmail (${_sentRole ?? 'Member'}). Send it via Gmail or copy below:',
                                                    style: const TextStyle(color: kPremiumText, fontSize: 12),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 18),

                                      // The Code Box
                                      Center(
                                        child: Column(
                                          children: [
                                            const Text(
                                              'ACCESS INVITATION CODE',
                                              style: TextStyle(
                                                color: kPremiumMuted,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                letterSpacing: 1.5,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Container(
                                              padding: EdgeInsets.symmetric(
                                                horizontal: isMobile ? 18 : 32,
                                                vertical: 12,
                                              ),
                                              decoration: BoxDecoration(
                                                color: kPremiumGold.withOpacity(0.12),
                                                borderRadius: BorderRadius.circular(16),
                                                border: Border.all(color: kPremiumGold.withOpacity(0.4), width: 1.5),
                                              ),
                                              child: SelectableText(
                                                _generatedCode!,
                                                style: TextStyle(
                                                  fontSize: isMobile ? 28 : 38,
                                                  fontWeight: FontWeight.w900,
                                                  letterSpacing: isMobile ? 6 : 8,
                                                  color: kPremiumGold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 18),

                                      // ONE-CLICK SEND BUTTONS
                                      const Text(
                                        'Send Message To Invitee:',
                                        style: TextStyle(fontWeight: FontWeight.bold, color: kPremiumGold, fontSize: 13),
                                      ),
                                      const SizedBox(height: 10),
                                      Wrap(
                                        spacing: 10,
                                        runSpacing: 10,
                                        children: [
                                          // Gmail Web Button
                                          ElevatedButton.icon(
                                            onPressed: () async {
                                              if (_emailResult != null && _sentToEmail != null) {
                                                Clipboard.setData(ClipboardData(text: _emailResult!.bodyText));
                                                await EmailService().openGmailWeb(
                                                  receiverEmail: _sentToEmail!,
                                                  subject: _emailResult!.subject,
                                                  body: _emailResult!.bodyText,
                                                );
                                                if (context.mounted) {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    const SnackBar(
                                                      content: Text('Opening Gmail... (Invitation text copied to clipboard as backup)'),
                                                      backgroundColor: Colors.blueAccent,
                                                      duration: Duration(seconds: 3),
                                                    ),
                                                  );
                                                }
                                              }
                                            },
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.redAccent.shade700,
                                              foregroundColor: Colors.white,
                                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                            ),
                                            icon: const Icon(Icons.email, size: 17),
                                            label: const Text('Send via Gmail', style: TextStyle(fontWeight: FontWeight.bold)),
                                          ),

                                          // Outlook Web Button
                                          ElevatedButton.icon(
                                            onPressed: () async {
                                              if (_emailResult != null && _sentToEmail != null) {
                                                Clipboard.setData(ClipboardData(text: _emailResult!.bodyText));
                                                await EmailService().openOutlookWeb(
                                                  receiverEmail: _sentToEmail!,
                                                  subject: _emailResult!.subject,
                                                  body: _emailResult!.bodyText,
                                                );
                                                if (context.mounted) {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    const SnackBar(
                                                      content: Text('Opening Outlook... (Invitation text copied to clipboard)'),
                                                      backgroundColor: Colors.blueAccent,
                                                      duration: Duration(seconds: 3),
                                                    ),
                                                  );
                                                }
                                              }
                                            },
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(0xFF0078D4),
                                              foregroundColor: Colors.white,
                                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                            ),
                                            icon: const Icon(Icons.mail_outline, size: 17),
                                            label: const Text('Send via Outlook', style: TextStyle(fontWeight: FontWeight.bold)),
                                          ),

                                          // Default Mail App Button
                                          OutlinedButton.icon(
                                            onPressed: () async {
                                              if (_emailResult != null && _sentToEmail != null) {
                                                await EmailService().openEmailClient(
                                                  receiverEmail: _sentToEmail!,
                                                  subject: _emailResult!.subject,
                                                  body: _emailResult!.bodyText,
                                                );
                                              }
                                            },
                                            style: OutlinedButton.styleFrom(
                                              side: const BorderSide(color: kPremiumGold),
                                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                            ),
                                            icon: const Icon(Icons.mark_email_unread_outlined, size: 17, color: kPremiumGold),
                                            label: const Text('Default Mail App', style: TextStyle(color: kPremiumGold, fontWeight: FontWeight.bold)),
                                          ),

                                          // Copy Code Button
                                          ElevatedButton.icon(
                                            onPressed: () {
                                              Clipboard.setData(ClipboardData(text: _generatedCode!));
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(
                                                  content: Text('Access code copied to clipboard!'),
                                                  backgroundColor: Colors.green,
                                                  duration: Duration(seconds: 3),
                                                ),
                                              );
                                            },
                                            icon: const Icon(Icons.copy, size: 16, color: kPremiumBg),
                                            label: const Text('Copy Code', style: TextStyle(color: kPremiumBg, fontWeight: FontWeight.bold)),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: kPremiumGold,
                                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                            ),
                                          ),

                                          // Copy Entire Email Button
                                          OutlinedButton.icon(
                                            onPressed: () {
                                              if (_emailResult != null) {
                                                Clipboard.setData(ClipboardData(text: _emailResult!.bodyText));
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(
                                                    content: Text('Full invitation email text copied! Ready to paste into WhatsApp, Slack, or Email.'),
                                                    backgroundColor: Colors.green,
                                                    duration: Duration(seconds: 4),
                                                  ),
                                                );
                                              }
                                            },
                                            icon: const Icon(Icons.copy_all_outlined, size: 16, color: kPremiumGold),
                                            label: const Text('Copy Full Message', style: TextStyle(color: kPremiumGold, fontWeight: FontWeight.bold)),
                                            style: OutlinedButton.styleFrom(
                                              side: const BorderSide(color: kPremiumGold),
                                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 16),

                                      // In-App Email Message Preview Box
                                      Container(
                                        padding: const EdgeInsets.all(14),
                                        decoration: BoxDecoration(
                                          color: Colors.black45,
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: Colors.white12),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                const Text(
                                                  'PREVIEW OF INVITATION MESSAGE',
                                                  style: TextStyle(color: kPremiumGold, fontSize: 11, fontWeight: FontWeight.bold),
                                                ),
                                                Text(
                                                  'Subject: ${_emailResult?.subject ?? ''}',
                                                  style: const TextStyle(color: kPremiumMuted, fontSize: 11),
                                                ),
                                              ],
                                            ),
                                            const Divider(height: 16, color: Colors.white12),
                                            SelectableText(
                                              _emailResult?.bodyText ?? '',
                                              style: const TextStyle(
                                                color: kPremiumText,
                                                fontSize: 12,
                                                fontFamily: 'monospace',
                                                height: 1.45,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),

                        const SizedBox(height: 36),

                        // SENT INVITATIONS & MESSAGES HISTORY SECTION
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  'Sent Invitations & Access Codes',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: kPremiumText,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'View all generated access codes and their invitation messages.',
                                  style: TextStyle(color: kPremiumMuted, fontSize: 12),
                                ),
                              ],
                            ),
                            TextButton.icon(
                              onPressed: _loadInvitationsHistory,
                              icon: const Icon(Icons.refresh, size: 16, color: kPremiumGold),
                              label: const Text('Refresh', style: TextStyle(color: kPremiumGold, fontSize: 12)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        if (_loadingHistory)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(24.0),
                              child: CircularProgressIndicator(color: kPremiumGold),
                            ),
                          )
                        else if (_invitations.isEmpty)
                          GlassCard(
                            padding: const EdgeInsets.all(24),
                            child: Center(
                              child: Column(
                                children: const [
                                  Icon(Icons.inbox_outlined, size: 40, color: kPremiumMuted),
                                  SizedBox(height: 10),
                                  Text(
                                    'No invitations generated yet.',
                                    style: TextStyle(color: kPremiumText, fontWeight: FontWeight.bold),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Use the form above to invite employees or clients.',
                                    style: TextStyle(color: kPremiumMuted, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          Column(
                            children: _invitations.map((inv) => _buildInvitationItem(inv)).toList(),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildInvitationItem(InvitationModel invite) {
    final isAccepted = invite.status.toLowerCase() == 'accepted';
    final isExpired = invite.expiresAt.isBefore(DateTime.now()) || invite.status.toLowerCase() == 'expired';

    final Color statusColor = isAccepted
        ? Colors.greenAccent
        : isExpired
            ? Colors.redAccent
            : kPremiumGold;

    final String statusLabel = isAccepted
        ? 'Accepted'
        : isExpired
            ? 'Expired'
            : 'Pending (Valid)';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Role Icon
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: kPremiumGold.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                invite.role == 'client' ? Icons.business_outlined : Icons.badge_outlined,
                color: kPremiumGold,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),

            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          invite.email,
                          style: const TextStyle(fontWeight: FontWeight.bold, color: kPremiumText, fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: statusColor.withOpacity(0.3)),
                        ),
                        child: Text(
                          statusLabel,
                          style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      // Role chip
                      Text(
                        invite.role.toUpperCase(),
                        style: const TextStyle(fontSize: 11, color: kPremiumMuted, fontWeight: FontWeight.w600),
                      ),
                      const Text(' • ', style: TextStyle(color: kPremiumMuted)),
                      // Code with copy icon
                      InkWell(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: invite.token));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Code ${invite.token} copied to clipboard!'),
                              backgroundColor: Colors.green,
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                        child: Row(
                          children: [
                            const Text('Code: ', style: TextStyle(fontSize: 11, color: kPremiumMuted)),
                            Text(
                              invite.token,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: kPremiumGold,
                                letterSpacing: 1.5,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.copy, size: 13, color: kPremiumGold),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 10),

            // View Message Button
            IconButton(
              tooltip: 'View Message & Send',
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: kPremiumGold.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: kPremiumGold.withOpacity(0.3)),
                ),
                child: const Icon(Icons.mail_outline, size: 18, color: kPremiumGold),
              ),
              onPressed: () => _showMessageDialog(invite),
            ),
          ],
        ),
      ),
    );
  }

  Widget _roleOptionCard({
    required String title,
    required String subtitle,
    required String value,
    required IconData icon,
  }) {
    final bool isSelected = _selectedRole == value;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedRole = value;
          _generatedCode = null;
          _sentToEmail = null;
          _emailResult = null;
        });
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? kPremiumGold.withOpacity(0.15) : kPremiumSurface.withOpacity(0.4),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? kPremiumGold : Colors.white.withOpacity(0.1),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? kPremiumGold : kPremiumMuted,
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isSelected ? kPremiumGold : kPremiumText,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 11, color: kPremiumMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
