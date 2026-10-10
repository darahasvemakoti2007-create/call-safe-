import 'dart:async';
import 'package:flutter/material.dart';
import '../../app/app_theme.dart';
import '../../core/services/auth_state.dart';
import '../../core/services/family_alert_service.dart';
import '../../core/services/family_relationship_service.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/risk_badge.dart';
import '../../core/widgets/section_header.dart';
import '../detection/risk_analysis.dart';
import 'caregiver_alert_detail_dialog.dart';

/// The Trusted Family Circle management view.
///
/// Supports:
/// 1. Elderly View: Managing trusted caregivers, authorization status, invitations, and privacy.
/// 2. Caregiver View: Detailed threat telemetry and alert actions for protected family members.
class FamilyScreen extends StatefulWidget {
  const FamilyScreen({super.key});

  @override
  State<FamilyScreen> createState() => _FamilyScreenState();
}

class _FamilyScreenState extends State<FamilyScreen> {
  int _selectedViewIndex = 0; // 0 = Elderly View, 1 = Caregiver View
  bool _isLoading = false;
  String? _isAcceptingId;

  List<FamilyRelationship> _relationships = [];
  List<FamilyInvitation> _invitations = [];
  List<FamilyAlertRecord> _caregiverAlerts = [];
  List<FamilyInvitation> _caregiverPendingInvitations = [];
  List<FamilyRelationship> _caregiverRelationships = [];
  StreamSubscription<FamilyAlertRecord>? _alertSubscription;
  StreamSubscription<FamilyRelationship>? _relationshipSubscription;

  @override
  void initState() {
    super.initState();
    _loadData();
    _alertSubscription = FamilyAlertService.instance.onAlertCreated.listen((_) {
      if (mounted) _loadData();
    });
    _relationshipSubscription =
        FamilyRelationshipService.instance.onRelationshipChanged.listen((_) {
      if (mounted) _loadData();
    });
  }

  @override
  void dispose() {
    _alertSubscription?.cancel();
    _relationshipSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final rels = await FamilyRelationshipService.instance.getMyRelationships();
      final invs = await FamilyRelationshipService.instance.getMyInvitations();
      final alerts = await FamilyAlertService.instance.getCaregiverAlerts();

      final caregiverEmail = AuthState.instance.currentUser?.email;
      final caregiverInvs = await FamilyRelationshipService.instance
          .getPendingInvitationsForCaregiver(email: caregiverEmail);
      final caregiverRels = await FamilyRelationshipService.instance
          .getCaregiverRelationships(
            caregiverUserId: AuthState.instance.currentUser?.id,
          );

      if (mounted) {
        setState(() {
          _relationships = rels;
          _invitations = invs;
          _caregiverAlerts = alerts;
          _caregiverPendingInvitations = caregiverInvs;
          _caregiverRelationships = caregiverRels;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showInviteCaregiverSheet(BuildContext context) {
    final messenger = ScaffoldMessenger.of(context);
    final emailController = TextEditingController();
    final relationshipController = TextEditingController(text: 'Daughter');
    final nameController = TextEditingController();
    String? emailError;
    String? relError;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.navySurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 24,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Add Family Member',
                          style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                                color: AppTheme.textPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: AppTheme.textSecondary),
                          onPressed: () => Navigator.of(ctx).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Demo Simulation Notice
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.riskSuspicious.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppTheme.riskSuspicious.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.info_outline,
                            color: AppTheme.riskSuspicious,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Demo Invitation Created',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.riskSuspicious,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Invitation delivery is simulated in this prototype. Adding an email creates a pending authorization record. In production, caregivers must authenticate and accept before access is granted.',
                                  style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                                        color: AppTheme.textPrimary,
                                        height: 1.4,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Display Name (Optional)
                    TextField(
                      controller: nameController,
                      style: const TextStyle(color: AppTheme.textPrimary),
                      decoration: InputDecoration(
                        labelText: 'Caregiver Name (Optional)',
                        labelStyle: const TextStyle(color: AppTheme.textSecondary),
                        hintText: 'e.g. Sarah Jenkins',
                        hintStyle: const TextStyle(color: AppTheme.textMuted),
                        filled: true,
                        fillColor: AppTheme.navySurfaceLight,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppTheme.navyBorder),
                        ),
                        prefixIcon: const Icon(Icons.badge_outlined, color: AppTheme.tealPrimary),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Caregiver Email (Required)
                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(color: AppTheme.textPrimary),
                      decoration: InputDecoration(
                        labelText: 'Caregiver Email *',
                        labelStyle: const TextStyle(color: AppTheme.textSecondary),
                        hintText: 'e.g. sarah.jenkins@example.com',
                        hintStyle: const TextStyle(color: AppTheme.textMuted),
                        errorText: emailError,
                        filled: true,
                        fillColor: AppTheme.navySurfaceLight,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppTheme.navyBorder),
                        ),
                        prefixIcon: const Icon(Icons.email_outlined, color: AppTheme.tealPrimary),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Relationship (Required)
                    TextField(
                      controller: relationshipController,
                      style: const TextStyle(color: AppTheme.textPrimary),
                      decoration: InputDecoration(
                        labelText: 'Relationship *',
                        labelStyle: const TextStyle(color: AppTheme.textSecondary),
                        hintText: 'e.g. Daughter, Son, Guardian, Caregiver',
                        hintStyle: const TextStyle(color: AppTheme.textMuted),
                        errorText: relError,
                        filled: true,
                        fillColor: AppTheme.navySurfaceLight,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppTheme.navyBorder),
                        ),
                        prefixIcon: const Icon(Icons.people_outline, color: AppTheme.tealPrimary),
                      ),
                    ),
                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      child: PrimaryButton(
                        text: 'Create Pending Invitation',
                        icon: Icons.send_rounded,
                        onPressed: () async {
                          final email = emailController.text.trim();
                          final rel = relationshipController.text.trim();
                          final name = nameController.text.trim();

                          final emailValid = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);

                          if (email.isEmpty || !emailValid || rel.isEmpty) {
                            setModalState(() {
                              if (email.isEmpty) {
                                emailError = 'Email address is required.';
                              } else if (!emailValid) {
                                emailError = 'Please enter a valid email address.';
                              } else {
                                emailError = null;
                              }

                              if (rel.isEmpty) {
                                relError = 'Relationship is required.';
                              } else {
                                relError = null;
                              }
                            });
                            return;
                          }

                          Navigator.of(ctx).pop();
                          try {
                            await FamilyRelationshipService.instance.createInvitation(
                              invitedEmail: email,
                              relationship: rel,
                              displayName: name.isNotEmpty ? name : null,
                            );
                            if (mounted) {
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Demo invitation created for $email. (Simulated in this prototype).',
                                  ),
                                  backgroundColor: AppTheme.tealPrimary,
                                ),
                              );
                              _loadData();
                            }
                          } catch (e) {
                            if (mounted) {
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text('Failed to create invitation: $e'),
                                  backgroundColor: AppTheme.riskCritical,
                                ),
                              );
                            }
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isConfigured = FamilyRelationshipService.instance.isConfigured;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          color: AppTheme.tealPrimary,
          backgroundColor: AppTheme.navySurface,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Family Circle',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Authenticated caregiver authorization & scam protection',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                ),
                const SizedBox(height: 16),

                // View Mode Selector (Elderly View vs Caregiver View)
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppTheme.navySurfaceLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.navyBorder),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedViewIndex = 0),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: _selectedViewIndex == 0
                                  ? AppTheme.tealPrimary
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'My Family Circle',
                              style: TextStyle(
                                color: _selectedViewIndex == 0
                                    ? Colors.black
                                    : AppTheme.textSecondary,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedViewIndex = 1),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: _selectedViewIndex == 1
                                  ? AppTheme.tealPrimary
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'Caregiver View (Preview)',
                              style: TextStyle(
                                color: _selectedViewIndex == 1
                                    ? Colors.black
                                    : AppTheme.textSecondary,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                if (_isLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(color: AppTheme.tealPrimary),
                    ),
                  )
                else if (_selectedViewIndex == 0)
                  _buildElderlyView(isConfigured)
                else
                  _buildCaregiverView(isConfigured),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// View 1: Elderly User View (Managing their Family Circle & Caregivers)
  Widget _buildElderlyView(bool isConfigured) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Environment Badge Banner
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isConfigured
                ? AppTheme.tealPrimary.withValues(alpha: 0.12)
                : AppTheme.riskSuspicious.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isConfigured
                  ? AppTheme.tealPrimary.withValues(alpha: 0.4)
                  : AppTheme.riskSuspicious.withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            children: [
              Icon(
                isConfigured ? Icons.cloud_done_outlined : Icons.offline_bolt_outlined,
                color: isConfigured ? AppTheme.tealPrimary : AppTheme.riskSuspicious,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isConfigured
                      ? 'Connected to Supabase • PostgreSQL RLS Enforced'
                      : 'Demo Mode • Simulated Offline Caregiver Circle',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Caregiver Authorization Notice
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.navySurfaceLight,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.navyBorder),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.lock_person_outlined, size: 18, color: AppTheme.tealPrimary),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Only family members you approve can see family alerts. Adding a phone number or email does not automatically give someone access; mutual authorization is enforced.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Section: Trusted Family Members
        const SectionHeader(
          title: 'Trusted Family Members',
          subtitle: 'Designated accounts authorized to receive your alert telemetry',
        ),
        const SizedBox(height: 10),

        if (_relationships.isEmpty)
          GlassCard(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: Text(
                'No family members linked yet.\nInvite a caregiver below to protect this account.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textMuted,
                      height: 1.5,
                    ),
              ),
            ),
          )
        else
          ..._relationships.map((rel) => _buildRelationshipCard(rel, isConfigured)),

        const SizedBox(height: 20),

        // Action: Invite Family Member Button
        SizedBox(
          width: double.infinity,
          child: PrimaryButton(
            text: 'Add Family Member',
            icon: Icons.person_add_alt_1_rounded,
            backgroundColor: AppTheme.navySurfaceLight,
            textColor: AppTheme.textPrimary,
            onPressed: () => _showInviteCaregiverSheet(context),
          ),
        ),
        const SizedBox(height: 28),

        // Section: Pending Caregiver Invitations
        const SectionHeader(
          title: 'Pending Invitations',
          subtitle: 'Authorization requests awaiting caregiver acceptance',
        ),
        const SizedBox(height: 10),
        if (_invitations.isEmpty)
          GlassCard(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: Text(
                'No pending invitations.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textMuted,
                    ),
              ),
            ),
          )
        else
          ..._invitations.map((inv) => _buildInvitationCard(inv)),
        const SizedBox(height: 28),

        // Privacy Section: Your Privacy (Phase I)
        const SectionHeader(
          title: 'Your Privacy',
          subtitle: 'Zero eavesdropping guarantee for seniors and caregivers',
        ),
        const SizedBox(height: 8),
        GlassCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.shield_outlined, color: AppTheme.tealPrimary, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Protected Privacy Guarantees',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildPrivacyBullet(
                icon: Icons.mic_off_outlined,
                text: 'GuardCall does not share your call audio with family members.',
              ),
              _buildPrivacyBullet(
                icon: Icons.analytics_outlined,
                text: 'Family alerts contain safety information such as risk level and detected warning signals.',
              ),
              _buildPrivacyBullet(
                icon: Icons.text_snippet_outlined,
                text: 'Your trusted family member does not receive your full conversation transcript.',
              ),
              _buildPrivacyBullet(
                icon: Icons.verified_user_outlined,
                text: 'Only family members you approve can access authorized family alerts.',
              ),
              _buildPrivacyBullet(
                icon: Icons.no_encryption_gmailerrorred_outlined,
                text: 'Zero audio retention: call audio is analyzed ephemerally and discarded immediately.',
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildPrivacyBullet({required IconData icon, required String text}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppTheme.tealPrimary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Relationship Card Component
  Widget _buildRelationshipCard(FamilyRelationship rel, bool isConfigured) {
    final isDemo = !isConfigured || rel.id.startsWith('demo');
    final name = rel.displayName ?? (isDemo ? 'Sarah Jenkins' : 'Caregiver Account');

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppTheme.tealPrimary.withValues(alpha: 0.2),
                  child: const Icon(
                    Icons.favorite_rounded,
                    color: AppTheme.tealPrimary,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.textPrimary,
                                  ),
                            ),
                          ),
                          if (isDemo) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.riskSuspicious.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'DEMO',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.riskSuspicious,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        rel.relationship ?? 'Designated Caregiver',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.tealLight,
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        rel.enabled ? 'Active • RLS Authorized' : 'Disabled',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: rel.enabled ? AppTheme.textSecondary : AppTheme.riskCritical,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(color: AppTheme.navyBorder, height: 24),
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        rel.enabled
                            ? Icons.notifications_active_outlined
                            : Icons.notifications_off_outlined,
                        color: rel.enabled ? AppTheme.tealPrimary : AppTheme.textMuted,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Receive scam escalation alerts',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppTheme.textPrimary,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Switch(
                  value: rel.enabled,
                  onChanged: (val) async {
                    await FamilyRelationshipService.instance.enableRelationship(rel.id, val);
                    _loadData();
                  },
                  activeThumbColor: AppTheme.tealPrimary,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Invitation Card Component
  Widget _buildInvitationCard(FamilyInvitation inv) {
    final isPending = inv.status == 'pending';
    final isRevoked = inv.status == 'revoked';
    final title = inv.displayName != null ? '${inv.displayName} (${inv.invitedEmail})' : inv.invitedEmail;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppTheme.navySurfaceLight,
              child: Icon(
                isRevoked ? Icons.cancel_outlined : Icons.mark_email_unread_outlined,
                size: 20,
                color: isRevoked ? AppTheme.riskCritical : AppTheme.tealPrimary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${inv.relationship ?? "Caregiver"} • ${isPending ? "Pending: Invitation waiting for caregiver acceptance." : "Status: ${inv.status.toUpperCase()}"}',
                    style: TextStyle(
                      color: isRevoked ? AppTheme.riskCritical : AppTheme.textMuted,
                      fontSize: 12,
                    ),
                  ),
                  if (isPending) ...[
                    const SizedBox(height: 2),
                    const Text(
                      'Expires in 7 days • Demo simulated delivery',
                      style: TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (isPending)
              TextButton(
                onPressed: () async {
                  final targetName = inv.displayName ?? inv.invitedEmail;
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: AppTheme.navySurface,
                      title: const Text('Revoke Invitation?', style: TextStyle(color: AppTheme.textPrimary)),
                      content: Text(
                        'Are you sure you want to cancel the caregiver invitation for $targetName?',
                        style: const TextStyle(color: AppTheme.textSecondary),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Keep', style: TextStyle(color: AppTheme.textSecondary)),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Revoke', style: TextStyle(color: AppTheme.riskCritical, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    await FamilyRelationshipService.instance.revokeInvitation(inv.id);
                    _loadData();
                  }
                },
                child: const Text(
                  'Revoke',
                  style: TextStyle(color: AppTheme.riskCritical, fontSize: 13, fontWeight: FontWeight.bold),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.navySurfaceLight,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  inv.status.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isRevoked ? AppTheme.riskCritical : AppTheme.tealPrimary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// View 2: Caregiver Perspective Foundation (Phase G)
  Widget _buildCaregiverView(bool isConfigured) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Information Banner
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.navySurfaceLight,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.navyBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.visibility_outlined, color: AppTheme.tealPrimary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Caregiver Perspective Foundation',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'This screen demonstrates what an authenticated caregiver sees when an elderly family member grants them access. Data access is enforced by PostgreSQL RLS.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondary,
                      height: 1.45,
                    ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Section: Incoming Caregiver Invitations
        const SectionHeader(
          title: 'Incoming Invitations',
          subtitle: 'Authorization requests awaiting your acceptance',
        ),
        const SizedBox(height: 10),

        if (_caregiverPendingInvitations.isEmpty)
          GlassCard(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: Text(
                'No pending caregiver invitations for your account.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textMuted,
                    ),
              ),
            ),
          )
        else
          ..._caregiverPendingInvitations.map((inv) => _buildCaregiverPendingInvitationCard(inv)),

        const SizedBox(height: 24),

        // Section: Protected Account Link
        const SectionHeader(
          title: 'Protected Family Member',
          subtitle: 'Account whose threat telemetry you are authorized to observe',
        ),
        const SizedBox(height: 10),

        if (_caregiverRelationships.isEmpty)
          _buildDefaultProtectedCard(isConfigured)
        else
          ..._caregiverRelationships.map((rel) => _buildCaregiverRelationshipCard(rel, isConfigured)),

        const SizedBox(height: 24),

        // Section: Recent Alerts
        const SectionHeader(
          title: 'Recent Scam Escalations',
          subtitle: 'High-risk calls where user requested family intervention',
        ),
        const SizedBox(height: 10),

        if (_caregiverAlerts.isEmpty)
          GlassCard(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: Text(
                'No recent scam escalations for this account.\nEverything is safe.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textMuted,
                      height: 1.5,
                    ),
              ),
            ),
          )
        else
          ..._caregiverAlerts.map((alert) => _buildAlertCard(alert)),

        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildDefaultProtectedCard(bool isConfigured) {
    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 24,
            backgroundColor: AppTheme.navySurfaceLight,
            child: Icon(Icons.person, color: AppTheme.tealPrimary, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isConfigured ? 'Linked Senior Account' : 'Robert Jenkins (Father)',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Relationship: Primary Caregiver • Active Link',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.tealLight,
                      ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.tealPrimary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'LINKED',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppTheme.tealPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCaregiverRelationshipCard(FamilyRelationship rel, bool isConfigured) {
    final name = rel.displayName ?? (isConfigured ? 'Linked Senior Account' : 'Robert Jenkins (Father)');
    final relLabel = rel.relationship ?? 'Primary Caregiver';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 24,
              backgroundColor: AppTheme.navySurfaceLight,
              child: Icon(Icons.person, color: AppTheme.tealPrimary, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Relationship: $relLabel • Active Link',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.tealLight,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    rel.enabled ? 'Active • Telemetry Enabled' : 'Disabled',
                    style: TextStyle(
                      fontSize: 11,
                      color: rel.enabled ? AppTheme.textSecondary : AppTheme.riskCritical,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.tealPrimary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'LINKED',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.tealPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCaregiverPendingInvitationCard(FamilyInvitation inv) {
    final isAccepting = _isAcceptingId == inv.id;
    final isAnyAccepting = _isAcceptingId != null;
    final name = inv.displayName ?? 'Family Account (${inv.ownerUserId})';
    final currentEmail = AuthState.instance.currentUser?.email;
    final isWrongUser = currentEmail != null &&
        currentEmail.trim().isNotEmpty &&
        inv.invitedEmail.trim().toLowerCase() != currentEmail.trim().toLowerCase();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppTheme.tealPrimary.withValues(alpha: 0.15),
                  child: const Icon(
                    Icons.mark_email_unread_outlined,
                    color: AppTheme.tealPrimary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${inv.relationship ?? "Caregiver"} • Pending Authorization',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.tealLight,
                            ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.riskSuspicious.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'PENDING',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.riskSuspicious,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Invited: ${inv.invitedEmail}',
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              isWrongUser
                  ? 'This invitation belongs to ${inv.invitedEmail}. Current authenticated user ($currentEmail) is not eligible to accept.'
                  : 'Accepting establishes mutual authorization to monitor scam threat alerts.',
              style: TextStyle(
                fontSize: 12,
                color: isWrongUser ? AppTheme.riskCritical : AppTheme.textMuted,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                key: Key('accept_invitation_${inv.id}'),
                onPressed: (isAnyAccepting || isWrongUser) ? null : () => _acceptCaregiverInvitation(inv),
                icon: isAccepting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black,
                        ),
                      )
                    : const Icon(Icons.check_circle_outline_rounded, size: 20),
                label: Text(
                  isAccepting ? 'Accepting Invitation...' : 'Accept Invitation',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.tealPrimary,
                  foregroundColor: Colors.black,
                  disabledBackgroundColor: AppTheme.navySurfaceLight,
                  disabledForegroundColor: AppTheme.textMuted,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _acceptCaregiverInvitation(FamilyInvitation inv) async {
    if (_isAcceptingId != null) return;
    setState(() => _isAcceptingId = inv.id);

    final messenger = ScaffoldMessenger.of(context);
    try {
      final currentEmail = AuthState.instance.currentUser?.email;
      final currentUserId = AuthState.instance.currentUser?.id;

      final acceptedRel = await FamilyRelationshipService.instance.acceptInvitation(
        inv.id,
        caregiverUserId: currentUserId,
        caregiverEmail: currentEmail,
        caregiverDisplayName: AuthState.instance.displayName,
      );

      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'Invitation accepted! Connected with ${acceptedRel.displayName ?? "family member"}.',
            ),
            backgroundColor: AppTheme.tealPrimary,
          ),
        );
        await _loadData();
      }
    } catch (e) {
      if (mounted) {
        final message = e is ArgumentError
            ? (e.message?.toString() ?? e.toString())
            : e is StateError
                ? e.message
                : 'Failed to accept invitation: $e';
        messenger.showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: AppTheme.riskCritical,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isAcceptingId = null);
      }
    }
  }

  RiskLevel _getRiskLevel(int score) {
    return RiskLevelScore.fromScore(score);
  }

  /// Alert Card for Caregiver View
  Widget _buildAlertCard(FamilyAlertRecord alert) {
    final level = _getRiskLevel(alert.riskScore);
    final isCritical = level == RiskLevel.critical;
    final isReviewed = alert.status == 'reviewed';
    final scenario = alert.scenarioType ?? 'Fake KYC Verification Scam';
    final signals = alert.detectedSignals ?? const ['Authority impersonation', 'Urgency or time pressure'];
    final explanation = alert.explanation ??
        'Caller impersonated a bank official threatening account closure without OTP verification.';
    final action = alert.interventionStatus ?? 'User selected End Call';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      isCritical ? Icons.warning_amber_rounded : Icons.info_outline,
                      color: level.color,
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${level.label} Threat',
                      style: TextStyle(
                        color: level.color,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: level.color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Score: ${alert.riskScore}/100',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: level.color,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: isReviewed
                            ? AppTheme.tealPrimary.withValues(alpha: 0.15)
                            : AppTheme.skyAccent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        alert.status.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isReviewed ? AppTheme.tealPrimary : AppTheme.skyAccent,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Threat: $scenario',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: signals.map((s) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.navySurfaceLight,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppTheme.navyBorder),
                  ),
                  child: Text(
                    s,
                    style: const TextStyle(fontSize: 11, color: AppTheme.textPrimary),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            Text(
              explanation,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.touch_app_outlined, size: 14, color: AppTheme.tealPrimary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Intervention: $action',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.tealLight,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Step 17 Architecture: Alert & Notification Delivery Status
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.navySurfaceLight,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.navyBorder),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline_rounded, size: 13, color: AppTheme.tealPrimary),
                  const SizedBox(width: 5),
                  const Text(
                    'Alert: Created',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    alert.notificationStatus == 'UNAVAILABLE'
                        ? Icons.block_rounded
                        : Icons.cell_tower_rounded,
                    size: 13,
                    color: alert.notificationStatus == 'UNAVAILABLE'
                        ? AppTheme.riskSuspicious
                        : AppTheme.skyAccent,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'Notification: ${alert.notificationStatus ?? "SIMULATED"}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: alert.notificationStatus == 'UNAVAILABLE'
                          ? AppTheme.riskSuspicious
                          : AppTheme.skyAccent,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Demo only — no external message was sent.',
              style: TextStyle(
                fontSize: 10,
                color: AppTheme.textMuted,
                fontStyle: FontStyle.italic,
              ),
            ),
            const Divider(color: AppTheme.navyBorder, height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Recorded via GuardCall on-device engine',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textMuted,
                          fontSize: 11,
                        ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    CaregiverAlertDetailDialog.show(
                      context: context,
                      alert: alert,
                      onReviewed: _loadData,
                    );
                  },
                  icon: const Icon(Icons.arrow_forward_rounded, size: 16, color: AppTheme.tealPrimary),
                  label: const Text(
                    'View Details',
                    style: TextStyle(
                      color: AppTheme.tealPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
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
