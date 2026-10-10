import 'dart:async';
import 'package:flutter/material.dart';
import '../../app/app_theme.dart';
import '../../core/services/auth_state.dart';
import '../../core/services/family_contact_service.dart';
import '../../core/services/family_relationship_service.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/risk_badge.dart';
import '../../core/widgets/section_header.dart';
import '../demo/demo_center_screen.dart';
import '../family/family_screen.dart';
import '../history/call_history_repository.dart';
import '../history/history_screen.dart';
import '../sms/sms_protection_screen.dart';

/// The primary dashboard of GuardCall.
///
/// Gives users immediate reassurance with an active protection badge,
/// family circle preview, privacy indicators, recent call assessments,
/// and a demo launcher.
class HomeScreen extends StatefulWidget {
  final VoidCallback? onNavigateToCalls;
  final VoidCallback? onNavigateToFamily;
  final VoidCallback? onNavigateToHistory;

  const HomeScreen({
    super.key,
    this.onNavigateToCalls,
    this.onNavigateToFamily,
    this.onNavigateToHistory,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLoadingFamily = true;
  FamilyRelationship? _primaryRelationship;
  FamilyInvitation? _pendingInvitation;
  FamilyContact? _fallbackContact;
  Object? _familyError;
  StreamSubscription<FamilyRelationship>? _relationshipSubscription;

  @override
  void initState() {
    super.initState();
    _loadFamilyData();
    _relationshipSubscription =
        FamilyRelationshipService.instance.onRelationshipChanged.listen((_) {
      if (mounted) _loadFamilyData();
    });
  }

  @override
  void dispose() {
    _relationshipSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadFamilyData() async {
    if (!mounted) return;
    setState(() {
      _isLoadingFamily = true;
      _familyError = null;
    });

    try {
      // 1. Check authenticated family relationships first
      final relationships =
          await FamilyRelationshipService.instance.getMyRelationships();
      FamilyRelationship? activeRel;
      try {
        activeRel = relationships.firstWhere((r) => r.enabled);
      } catch (_) {
        activeRel = relationships.isNotEmpty ? relationships.first : null;
      }

      // 2. Check pending invitations if no active relationship exists
      FamilyInvitation? pendingInv;
      if (activeRel == null) {
        final invitations =
            await FamilyRelationshipService.instance.getMyInvitations();
        try {
          pendingInv = invitations.firstWhere((i) => i.status == 'pending');
        } catch (_) {
          pendingInv = invitations.isNotEmpty ? invitations.first : null;
        }
      }

      // 3. Fallback: Check family contacts if neither relationship nor invitation exists
      FamilyContact? contact;
      if (activeRel == null && pendingInv == null) {
        final contacts = await FamilyContactService.instance.getFamilyContacts();
        try {
          contact = contacts.firstWhere((c) => c.enabled);
        } catch (_) {
          contact = contacts.isNotEmpty ? contacts.first : null;
        }
      }

      if (mounted) {
        setState(() {
          _primaryRelationship = activeRel;
          _pendingInvitation = pendingInv;
          _fallbackContact = contact;
          _isLoadingFamily = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _familyError = e;
          _isLoadingFamily = false;
        });
      }
    }
  }

  void _openDemoCenter(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const DemoCenterScreen(),
      ),
    );
  }

  void _openFamily(BuildContext context) async {
    if (widget.onNavigateToFamily != null) {
      widget.onNavigateToFamily!();
    } else {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const FamilyScreen(),
        ),
      );
      if (mounted) _loadFamilyData();
    }
  }

  void _openHistory(BuildContext context) {
    if (widget.onNavigateToHistory != null) {
      widget.onNavigateToHistory!();
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const HistoryScreen(),
        ),
      );
    }
  }

  String _buildGreeting(String? rawName) {
    final name = rawName?.trim() ?? '';
    if (name.isEmpty || name.toLowerCase() == 'guest') {
      return 'Welcome back';
    }
    return 'Welcome back, $name';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Bar & Reactive Greeting
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'GuardCall',
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                color: AppTheme.tealPrimary,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 2),
                        ListenableBuilder(
                          listenable: AuthState.instance,
                          builder: (context, _) {
                            final greeting =
                                _buildGreeting(AuthState.instance.displayName);
                            return Text(
                              greeting,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppTheme.textSecondary,
                                  ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const RiskBadge(
                    level: RiskLevel.safe,
                    showIcon: true,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Main Protection Status Card
              GlassCard(
                borderColor: AppTheme.tealPrimary.withValues(alpha: 0.35),
                backgroundColor: AppTheme.navySurfaceLight.withValues(alpha: 0.9),
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.tealPrimary.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.shield_outlined,
                            color: AppTheme.tealPrimary,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Protection Active',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.tealLight,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Real-time conversation pattern shield',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: AppTheme.textSecondary,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'GuardCall is monitoring active conversation flows for manipulation, false urgency, and authority impersonation.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.textPrimary,
                            height: 1.5,
                          ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: PrimaryButton(
                        text: 'Start Demo Call',
                        icon: Icons.phone_in_talk_rounded,
                        onPressed: () => _openDemoCenter(context),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        key: const Key('home_open_sms_protection_button'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.skyAccent,
                          side: const BorderSide(color: AppTheme.navyBorder),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          minimumSize: const Size.fromHeight(48),
                        ),
                        icon: const Icon(Icons.sms_outlined, size: 20),
                        label: const Text('Analyze Suspicious SMS / Text',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const SmsProtectionScreen(),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Trusted Family Contact Summary
              const SectionHeader(
                title: 'Family Circle',
                subtitle: 'Your designated emergency contact',
              ),
              const SizedBox(height: 8),
              _buildFamilyCard(context),
              const SizedBox(height: 28),

              // Recent Assessment Summary
              const SectionHeader(
                title: 'Recent Activity',
                subtitle: 'Last assessed call overview',
              ),
              const SizedBox(height: 8),
              ListenableBuilder(
                listenable: CallHistoryRepository.instance,
                builder: (context, _) {
                  final records = CallHistoryRepository.instance.records;
                  if (records.isEmpty) {
                    return _buildEmptyRecentActivityCard(context);
                  }
                  return _buildRecentActivityCard(context, records.first);
                },
              ),
              const SizedBox(height: 28),

              // Privacy Status Card
              const SectionHeader(
                title: 'Privacy & Storage',
                subtitle: 'Zero audio retention guarantee',
              ),
              const SizedBox(height: 8),
              GlassCard(
                padding: const EdgeInsets.all(18),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.lock_outline_rounded,
                      color: AppTheme.tealPrimary,
                      size: 24,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Audio is Never Recorded',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: AppTheme.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'GuardCall processes conversation patterns transiently in memory. Raw audio and transcripts are never stored.',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppTheme.textSecondary,
                                  height: 1.45,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFamilyCard(BuildContext context) {
    if (_isLoadingFamily) {
      return GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppTheme.tealPrimary,
            ),
          ),
        ),
      );
    }

    if (_familyError != null) {
      return InkWell(
        onTap: () => _openFamily(context),
        borderRadius: BorderRadius.circular(16),
        child: GlassCard(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.riskSuspicious.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(
                    Icons.error_outline_rounded,
                    color: AppTheme.riskSuspicious,
                    size: 26,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Family Circle Status',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tap to review family emergency contacts',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.textSecondary,
              ),
            ],
          ),
        ),
      );
    }

    // 1. Active Authenticated Relationship
    if (_primaryRelationship != null) {
      final rel = _primaryRelationship!;
      final name = rel.displayName ?? 'Caregiver';
      final relationshipLabel = rel.relationship ?? 'Designated Caregiver';
      final isEnabled = rel.enabled;

      return InkWell(
        onTap: () => _openFamily(context),
        borderRadius: BorderRadius.circular(16),
        child: GlassCard(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.skyAccent.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(
                    Icons.person_rounded,
                    color: AppTheme.skyAccent,
                    size: 26,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$name ($relationshipLabel)',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isEnabled
                          ? 'Connected • Receives Critical Alerts'
                          : 'Paused • Alerts Temporarily Disabled',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: isEnabled
                                ? AppTheme.tealPrimary
                                : AppTheme.textMuted,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.textSecondary,
              ),
            ],
          ),
        ),
      );
    }

    // 2. Pending Invitation
    if (_pendingInvitation != null) {
      final inv = _pendingInvitation!;
      final label = inv.displayName ?? inv.invitedEmail;
      final relLabel = inv.relationship ?? 'Caregiver';

      return InkWell(
        onTap: () => _openFamily(context),
        borderRadius: BorderRadius.circular(16),
        child: GlassCard(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.riskSuspicious.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(
                    Icons.mark_email_unread_outlined,
                    color: AppTheme.riskSuspicious,
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$label ($relLabel)',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Invitation Pending • Awaiting Acceptance',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.riskSuspicious,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.textSecondary,
              ),
            ],
          ),
        ),
      );
    }

    // 3. Fallback Contact
    if (_fallbackContact != null) {
      final contact = _fallbackContact!;
      final relLabel =
          contact.relationship != null && contact.relationship!.isNotEmpty
              ? ' (${contact.relationship})'
              : '';

      return InkWell(
        onTap: () => _openFamily(context),
        borderRadius: BorderRadius.circular(16),
        child: GlassCard(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.skyAccent.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(
                    Icons.person_rounded,
                    color: AppTheme.skyAccent,
                    size: 26,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${contact.name}$relLabel',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      contact.enabled
                          ? 'Connected • Receives Critical Alerts'
                          : 'Paused • Alerts Temporarily Disabled',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: contact.enabled
                                ? AppTheme.tealPrimary
                                : AppTheme.textMuted,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.textSecondary,
              ),
            ],
          ),
        ),
      );
    }

    // 4. No Contacts or Caregivers Connected (Empty State)
    return InkWell(
      onTap: () => _openFamily(context),
      borderRadius: BorderRadius.circular(16),
      child: GlassCard(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppTheme.tealPrimary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(
                  Icons.person_add_alt_1_rounded,
                  color: AppTheme.tealPrimary,
                  size: 24,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No Caregiver Connected',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap to add a trusted emergency contact',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppTheme.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyRecentActivityCard(BuildContext context) {
    return InkWell(
      onTap: () => _openHistory(context),
      borderRadius: BorderRadius.circular(16),
      child: GlassCard(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.navySurfaceLight,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.navyBorder),
              ),
              child: const Icon(
                Icons.history_toggle_off_rounded,
                color: AppTheme.textMuted,
                size: 26,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No Call Activity Logged',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Completed call assessments will appear here.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppTheme.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivityCard(
      BuildContext context, CallHistoryRecord record) {
    IconData iconData;
    Color iconColor;

    switch (record.riskLevel) {
      case RiskLevel.safe:
        iconData = Icons.check_circle_outline_rounded;
        iconColor = AppTheme.riskSafe;
        break;
      case RiskLevel.suspicious:
        iconData = Icons.info_outline_rounded;
        iconColor = AppTheme.riskSuspicious;
        break;
      case RiskLevel.high:
        iconData = Icons.warning_amber_rounded;
        iconColor = AppTheme.riskHigh;
        break;
      case RiskLevel.critical:
        iconData = Icons.gpp_bad_rounded;
        iconColor = AppTheme.riskCritical;
        break;
    }

    return InkWell(
      onTap: () => _openHistory(context),
      borderRadius: BorderRadius.circular(16),
      child: GlassCard(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    iconData,
                    color: iconColor,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        record.title,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: AppTheme.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                      ),
                      if (record.timestamp.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          record.timestamp,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppTheme.textMuted,
                                  ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: RiskBadge(level: record.riskLevel, score: record.riskScore),
            ),
            if (record.subtitle.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                record.subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondary,
                      height: 1.4,
                    ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

