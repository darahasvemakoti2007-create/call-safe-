import 'package:flutter/material.dart';
import '../../app/app_theme.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/risk_badge.dart';
import '../../core/widgets/section_header.dart';
import 'assessment_detail_dialog.dart';
import 'call_history_repository.dart';

/// Call history screen showing structured risk assessment records,
/// with real-time search, multi-tier risk filtering, and full assessment detail inspection.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  RiskLevel? _selectedRiskFilter;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _searchQuery = '';
      _selectedRiskFilter = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final repository = CallHistoryRepository.instance;
    final hasActiveFilter = _searchQuery.isNotEmpty || _selectedRiskFilter != null;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Risk History',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                'Audit log of assessed call manipulation patterns',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
              ),
              const SizedBox(height: 16),

              // Clarification banner (Notice: Demo Records & Privacy)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.skyAccent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppTheme.skyAccent.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.shield_outlined,
                      color: AppTheme.skyAccent,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Zero Audio Retention: GuardCall stores structured threat metadata only. No raw audio is recorded.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.textPrimary,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Search Input Field
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.navySurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.navyBorder),
                ),
                child: TextField(
                  key: const Key('history_search_text_field'),
                  controller: _searchController,
                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search title, signals, or transcripts...',
                    hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 14),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: AppTheme.textSecondary,
                      size: 20,
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            key: const Key('history_search_clear_button'),
                            icon: const Icon(
                              Icons.clear_rounded,
                              color: AppTheme.textSecondary,
                              size: 18,
                            ),
                            tooltip: 'Clear search text',
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  onChanged: (val) {
                    setState(() => _searchQuery = val.trim());
                  },
                ),
              ),
              const SizedBox(height: 12),

              // Risk Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip(
                      label: 'All',
                      isSelected: _selectedRiskFilter == null,
                      onTap: () => setState(() => _selectedRiskFilter = null),
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      label: 'Safe',
                      riskLevel: RiskLevel.safe,
                      isSelected: _selectedRiskFilter == RiskLevel.safe,
                      onTap: () => setState(() => _selectedRiskFilter = RiskLevel.safe),
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      label: 'Suspicious',
                      riskLevel: RiskLevel.suspicious,
                      isSelected: _selectedRiskFilter == RiskLevel.suspicious,
                      onTap: () => setState(() => _selectedRiskFilter = RiskLevel.suspicious),
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      label: 'High',
                      riskLevel: RiskLevel.high,
                      isSelected: _selectedRiskFilter == RiskLevel.high,
                      onTap: () => setState(() => _selectedRiskFilter = RiskLevel.high),
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      label: 'Critical',
                      riskLevel: RiskLevel.critical,
                      isSelected: _selectedRiskFilter == RiskLevel.critical,
                      onTap: () => setState(() => _selectedRiskFilter = RiskLevel.critical),
                    ),
                    if (hasActiveFilter) ...[
                      const SizedBox(width: 12),
                      TextButton.icon(
                        key: const Key('history_reset_filters_button'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppTheme.skyAccent,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          minimumSize: const Size(48, 36),
                        ),
                        onPressed: _clearFilters,
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: const Text('Reset', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Section Header
              SectionHeader(
                title: 'Past Assessments',
                subtitle: 'Evaluated by pattern sequence analysis',
                trailing: hasActiveFilter
                    ? TextButton(
                        key: const Key('history_clear_filters_text_button'),
                        onPressed: _clearFilters,
                        child: const Text('Clear Filters', style: TextStyle(color: AppTheme.skyAccent)),
                      )
                    : null,
              ),
              const SizedBox(height: 12),

              // Filtered Assessment List
              ListenableBuilder(
                listenable: repository,
                builder: (context, _) {
                  final allRecords = repository.records;

                  if (allRecords.isEmpty) {
                    return _buildEmptyState(
                      context,
                      icon: Icons.history_toggle_off_rounded,
                      title: 'No call assessments yet',
                      message:
                          'No call risk assessment records have been logged yet. Complete a training simulation or an incoming call to view evaluations here.',
                    );
                  }

                  final query = _searchQuery.toLowerCase();
                  final filtered = allRecords.where((record) {
                    // Risk level filter
                    if (_selectedRiskFilter != null && record.riskLevel != _selectedRiskFilter) {
                      return false;
                    }
                    // Text search filter
                    if (query.isNotEmpty) {
                      final inTitle = record.title.toLowerCase().contains(query);
                      final inSubtitle = record.subtitle.toLowerCase().contains(query);
                      final inSignals = record.signals.any((s) => s.toLowerCase().contains(query));
                      final inExplanation =
                          record.explanation?.toLowerCase().contains(query) ?? false;
                      final inTranscript =
                          record.transcriptExcerpt?.toLowerCase().contains(query) ?? false;
                      if (!inTitle &&
                          !inSubtitle &&
                          !inSignals &&
                          !inExplanation &&
                          !inTranscript) {
                        return false;
                      }
                    }
                    return true;
                  }).toList();

                  if (filtered.isEmpty) {
                    return _buildFilteredEmptyState(context);
                  }

                  return Column(
                    children: filtered.map((record) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _buildHistoryCard(
                          context,
                          record: record,
                          onTap: () => AssessmentDetailDialog.show(context, record),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    RiskLevel? riskLevel,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final activeColor = riskLevel?.color ?? AppTheme.tealPrimary;

    return Semantics(
      button: true,
      selected: isSelected,
      label: 'Filter by $label',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 40, minWidth: 48),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? activeColor.withValues(alpha: 0.18)
                  : AppTheme.navySurface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? activeColor : AppTheme.navyBorder,
                width: isSelected ? 1.5 : 1.0,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? activeColor : AppTheme.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: AppTheme.textMuted),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilteredEmptyState(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.search_off_rounded,
              size: 44,
              color: AppTheme.textMuted,
            ),
            const SizedBox(height: 12),
            const Text(
              'No matching assessments found',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _searchQuery.isNotEmpty
                  ? 'No records match "$_searchQuery" with the active filters.'
                  : 'No records found for the selected risk filter.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              key: const Key('history_clear_filters_empty_state_button'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.navySurfaceLight,
                foregroundColor: AppTheme.tealPrimary,
                side: const BorderSide(color: AppTheme.navyBorder),
                minimumSize: const Size(140, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: _clearFilters,
              icon: const Icon(Icons.clear_all_rounded, size: 18),
              label: const Text('Clear Filters'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryCard(
    BuildContext context, {
    required CallHistoryRecord record,
    required VoidCallback onTap,
  }) {
    final title = record.title.isNotEmpty ? record.title : 'Call Assessment';
    final timestamp = record.timestamp.isNotEmpty ? record.timestamp : 'Timestamp not recorded';
    final level = record.riskLevel;

    return GlassCard(
      padding: const EdgeInsets.all(18),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 290;
              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RiskBadge(level: level, score: record.riskScore),
                    const SizedBox(height: 8),
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$timestamp • ${record.duration}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.textMuted,
                          ),
                    ),
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$timestamp • ${record.duration}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppTheme.textMuted,
                              ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  RiskBadge(level: level, score: record.riskScore),
                ],
              );
            },
          ),
          if (record.interventionStatus != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: level.color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: level.color.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.security_rounded,
                    size: 13,
                    color: level.color,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Intervention: ${record.interventionStatus}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: level.color,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            record.subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textSecondary,
                  height: 1.4,
                ),
          ),
          if (record.signals.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: record.signals.map((signal) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.navySurfaceLight,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.navyBorder),
                  ),
                  child: Text(
                    signal,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.tealLight,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              const Spacer(),
              Text(
                'View details',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.tealPrimary.withValues(alpha: 0.9),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 11,
                color: AppTheme.tealPrimary,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
