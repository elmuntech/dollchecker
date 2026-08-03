import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:dollchecker/core/config/legal_links.dart';
import 'package:dollchecker/core/utils/external_link.dart';
import 'package:dollchecker/features/auth/data/auth_repository.dart';
import 'package:dollchecker/features/billing/data/billing_repository.dart';
import 'package:dollchecker/features/child_profile/child_profile.dart';
import 'package:dollchecker/features/child_profile/presentation/child_switcher.dart';
import 'package:dollchecker/features/collection/domain/toy.dart';
import 'package:dollchecker/features/collection/presentation/collection_screen.dart';
import 'package:dollchecker/features/missions/data/mission_repository.dart';
import 'package:dollchecker/features/parents/data/parents_repository.dart';
import 'package:dollchecker/features/parents/domain/household_report.dart';
import 'package:dollchecker/features/parents/domain/safety_watch.dart';
import 'package:dollchecker/features/profile/data/profile_repository.dart';
import 'package:dollchecker/l10n/app_localizations.dart';
import 'package:dollchecker/shared/widgets/safety_badge.dart';

/// The grown-ups' view of the app.
///
/// Every other surface answers "what should we play next?" for one child. This
/// one answers "how is the household doing?" — the week's activity per child,
/// the toys whose latest analysis was not green, and the account itself.
class ParentsScreen extends ConsumerWidget {
  const ParentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final report = ref.watch(householdReportProvider).valueOrNull;
    final watch = ref.watch(safetyWatchProvider).valueOrNull;
    final today = ref.watch(todayProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l.parentsPanel)),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(householdReportProvider);
          ref.invalidate(safetyWatchProvider);
          ref.invalidate(quotaProvider);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            if (report == null)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              _WeekSummaryCard(report: report),
              if (report.children.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text(l.parentsChildrenTitle,
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                for (final week in report.children)
                  _ChildWeekCard(week: week, today: today),
              ],
            ],
            if (watch != null) ...[
              const SizedBox(height: 24),
              _SafetyReview(watch: watch),
            ],
            const SizedBox(height: 24),
            Text(l.account, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            const _AccountSection(),
            const _LegalSection(),
            const SizedBox(height: 8),
            const _DeleteAccountTile(),
          ],
        ),
      ),
    );
  }
}

/// The household headline: scans, missions and active days over the window.
class _WeekSummaryCard extends StatelessWidget {
  const _WeekSummaryCard({required this.report});
  final HouseholdReport report;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.parentsWeekTitle,
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 2),
            Text(l.thisWeek, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _Stat(
                    value: '${report.totalScans}',
                    label: l.statScans,
                    icon: Icons.qr_code_scanner,
                  ),
                ),
                Expanded(
                  child: _Stat(
                    value: '${report.missionsCompleted}',
                    label: l.statMissions,
                    icon: Icons.check_circle_outline,
                  ),
                ),
                Expanded(
                  child: _Stat(
                    value: '${report.activeDays}',
                    label: l.statActiveDays,
                    icon: Icons.local_fire_department_outlined,
                  ),
                ),
              ],
            ),
            if (report.isQuiet) ...[
              const SizedBox(height: 14),
              Text(l.parentsQuiet,
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, required this.icon});

  final String value;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Icon(icon, size: 20, color: scheme.primary),
        const SizedBox(height: 6),
        Text(value, style: Theme.of(context).textTheme.headlineSmall),
        Text(
          label,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ],
    );
  }
}

/// One child's week. Tapping it makes that child the active one and opens their
/// development dashboard — the natural next question after reading the numbers.
class _ChildWeekCard extends ConsumerWidget {
  const _ChildWeekCard({required this.week, required this.today});

  final ChildWeek week;
  final DateTime today;

  void _open(BuildContext context, WidgetRef ref) {
    ref.read(selectedChildIdProvider.notifier).state = week.child.id;
    context.go('/development');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _open(context, ref),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: scheme.primaryContainer,
                    child: Text(_initial(week.child.name)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(week.child.name,
                            style: Theme.of(context).textTheme.titleMedium),
                        Text(childAgeLabel(l, week.child),
                            style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
                  if (week.developmentIndex > 0)
                    Chip(
                      visualDensity: VisualDensity.compact,
                      label: Text('${l.developmentIndex} '
                          '${week.developmentIndex}'),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 16,
                runSpacing: 4,
                children: [
                  _Meta(
                    icon: Icons.qr_code_scanner,
                    text: '${l.statScans}: ${week.scans}',
                  ),
                  _Meta(
                    icon: Icons.check_circle_outline,
                    text: week.missionsPlanned == 0
                        ? l.childNoMissions
                        : l.missionsProgress(
                            week.missionsCompleted, week.missionsPlanned),
                  ),
                ],
              ),
              if (week.missionsPlanned > 0) ...[
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: week.completionRate,
                    minHeight: 6,
                    backgroundColor: scheme.surfaceContainerHighest,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              _WeekStrip(days: week.dayStrip(today)),
            ],
          ),
        ),
      ),
    );
  }

  static String _initial(String name) {
    final trimmed = name.trim();
    return trimmed.isEmpty ? '?' : trimmed.substring(0, 1).toUpperCase();
  }
}

/// Seven dots, oldest first — filled on the days a mission was completed.
class _WeekStrip extends StatelessWidget {
  const _WeekStrip({required this.days});
  final List<bool> days;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        for (final active in days)
          Container(
            width: 14,
            height: 14,
            margin: const EdgeInsets.only(right: 6),
            decoration: BoxDecoration(
              color:
                  active ? scheme.primary : scheme.surfaceContainerHighest,
              shape: BoxShape.circle,
            ),
          ),
      ],
    );
  }
}

/// The toys whose latest analysis was red or yellow.
class _SafetyReview extends StatelessWidget {
  const _SafetyReview({required this.watch});
  final SafetyWatch watch;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(l.safetyReview,
                style: Theme.of(context).textTheme.titleMedium),
            if (watch.isNotEmpty)
              Text(l.needsAttention(watch.count),
                  style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          watch.isEmpty ? l.safetyReviewEmpty : l.safetyReviewHint,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        for (final toy in watch.toys) _SafetyTile(toy: toy),
      ],
    );
  }
}

class _SafetyTile extends StatelessWidget {
  const _SafetyTile({required this.toy});
  final Toy toy;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: SizedBox(
          width: 44,
          height: 44,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: ToyThumbnail(path: toy.imagePath),
          ),
        ),
        title: Text(toy.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: toy.lastScannedAt == null
            ? null
            : Text(l.lastScanned(
                DateFormat.yMMMd().format(toy.lastScannedAt!))),
        trailing: SafetyDot(level: toy.safety),
        onTap: () => context.push('/toy/${toy.id}'),
      ),
    );
  }
}

/// Plan, children and app settings — the parent-only controls.
class _AccountSection extends ConsumerWidget {
  const _AccountSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final children = ref.watch(childrenProvider).valueOrNull ?? const [];
    final quota = ref.watch(quotaProvider).valueOrNull;

    return Card(
      child: Column(
        children: [
          if (quota != null) _PlanTile(quota: quota),
          ListTile(
            leading: const Icon(Icons.child_care_outlined),
            title: Text(l.children),
            subtitle: Text(children.map((c) => c.name).join(', ')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/children'),
          ),
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: Text(l.settings),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings'),
          ),
        ],
      ),
    );
  }
}

/// The plan the household is on, and the one action that goes with it:
/// upgrading, or managing the subscription that already exists. Cancelling has
/// to be reachable from inside the app, not only from a billing email.
class _PlanTile extends ConsumerStatefulWidget {
  const _PlanTile({required this.quota});
  final QuotaStatus quota;

  @override
  ConsumerState<_PlanTile> createState() => _PlanTileState();
}

class _PlanTileState extends ConsumerState<_PlanTile> {
  bool _busy = false;

  Future<void> _openPortal() async {
    final messenger = ScaffoldMessenger.of(context);
    final failed = AppLocalizations.of(context).portalFailed;

    setState(() => _busy = true);
    try {
      final url = await ref.read(billingRepositoryProvider).portalUrl();
      final opened = await ref.read(externalLauncherProvider)(Uri.parse(url));
      if (!opened) messenger.showSnackBar(SnackBar(content: Text(failed)));
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(failed)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final quota = widget.quota;

    return ListTile(
      leading: const Icon(Icons.workspace_premium_outlined),
      title: Text(l.plan),
      subtitle: Text(
        quota.isPremium
            ? '${l.planPremium} · ${l.unlimitedScans}'
            : '${l.planFree} · ${l.scansLeft(quota.remaining ?? 0)}',
      ),
      trailing: _busy
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : quota.isPremium
              ? TextButton(
                  onPressed: _openPortal,
                  child: Text(l.manageSubscription),
                )
              : FilledButton.tonal(
                  onPressed: () => context.push('/paywall'),
                  child: Text(l.upgrade),
                ),
    );
  }
}

/// Privacy policy, terms and support. Rows appear only once the corresponding
/// URL is published (see `docs/INTEGRATIONS.md`).
class _LegalSection extends ConsumerWidget {
  const _LegalSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final links = ref.watch(legalLinksProvider);
    if (links.isEmpty) return const SizedBox.shrink();

    final privacy = links.privacyUrl;
    final terms = links.termsUrl;
    final support = links.supportUri;

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.legal, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                if (privacy != null)
                  ListTile(
                    leading: const Icon(Icons.privacy_tip_outlined),
                    title: Text(l.privacyPolicy),
                    trailing: const Icon(Icons.open_in_new, size: 18),
                    onTap: () => openExternalUrl(privacy),
                  ),
                if (terms != null)
                  ListTile(
                    leading: const Icon(Icons.description_outlined),
                    title: Text(l.termsOfService),
                    trailing: const Icon(Icons.open_in_new, size: 18),
                    onTap: () => openExternalUrl(terms),
                  ),
                if (support != null)
                  ListTile(
                    leading: const Icon(Icons.mail_outline),
                    title: Text(l.contactSupport),
                    trailing: const Icon(Icons.open_in_new, size: 18),
                    onTap: () => openExternalUri(support),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Account deletion, which both app stores require to be reachable from inside
/// the app. Destructive and irreversible, so it sits on its own and states
/// exactly what disappears before doing anything.
class _DeleteAccountTile extends ConsumerStatefulWidget {
  const _DeleteAccountTile();

  @override
  ConsumerState<_DeleteAccountTile> createState() => _DeleteAccountTileState();
}

class _DeleteAccountTileState extends ConsumerState<_DeleteAccountTile> {
  bool _busy = false;

  Future<void> _delete() async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l.deleteAccount),
        content: Text(l.deleteAccountConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l.deleteAccountAction),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      await ref.read(authRepositoryProvider).deleteAccount();
      // Signing out inside the repository sends the router back to /auth, so
      // there is usually no screen left to update — only the message survives.
      messenger.showSnackBar(SnackBar(content: Text(l.accountDeleted)));
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l.deleteAccountFailed)));
    } finally {
      // Always stop the spinner, including on the success path: leaving one
      // running forever is a lie if the navigation has not happened yet.
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;

    return Card(
      child: ListTile(
        leading: _busy
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(Icons.delete_forever_outlined, color: scheme.error),
        title: Text(l.deleteAccount, style: TextStyle(color: scheme.error)),
        subtitle: Text(l.deleteAccountHint),
        onTap: _busy ? null : _delete,
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14),
        const SizedBox(width: 4),
        Text(text, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
