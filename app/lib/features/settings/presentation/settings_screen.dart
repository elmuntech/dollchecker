import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:dollchecker/core/l10n/locale_controller.dart';
import 'package:dollchecker/core/supabase/supabase.dart';
import 'package:dollchecker/features/child_profile/child_profile.dart';
import 'package:dollchecker/features/profile/data/profile_repository.dart';
import 'package:dollchecker/features/reminders/data/reminder_repository.dart';
import 'package:dollchecker/features/reminders/domain/reminder_schedule.dart';
import 'package:dollchecker/l10n/app_localizations.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final locale = ref.watch(localeProvider);
    final children = ref.watch(childrenProvider).valueOrNull ?? const [];
    final quota = ref.watch(quotaProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(title: Text(l.settings)),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.child_care_outlined),
            title: Text(l.children),
            subtitle: Text(children.map((c) => c.name).join(', ')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/children'),
          ),
          if (quota != null)
            ListTile(
              leading: const Icon(Icons.workspace_premium_outlined),
              title: Text(l.plan),
              subtitle: Text(
                quota.isPremium
                    ? '${l.planPremium} · ${l.unlimitedScans}'
                    : '${l.planFree} · ${l.scansLeft(quota.remaining ?? 0)}',
              ),
            ),
          const Divider(),
          const ReminderSection(),
          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child:
                Text(l.language, style: Theme.of(context).textTheme.titleSmall),
          ),
          RadioGroup<String>(
            groupValue: locale.languageCode,
            onChanged: (value) {
              if (value == null) return;
              ref.read(localeProvider.notifier).state = Locale(value);
              // A scheduled reminder carries its text with it, so the pending
              // one is still in the old language until it is re-armed.
              _rescheduleReminder(ref, Locale(value));
            },
            child: Column(
              children: [
                RadioListTile<String>(value: 'en', title: Text(l.english)),
                RadioListTile<String>(value: 'ru', title: Text(l.russian)),
              ],
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: Text(l.signOut),
            onTap: () => ref.read(supabaseProvider).auth.signOut(),
          ),
        ],
      ),
    );
  }
}

/// Re-arms an enabled reminder in the newly chosen language.
Future<void> _rescheduleReminder(WidgetRef ref, Locale locale) async {
  final l = await AppLocalizations.delegate.load(locale);
  await ref
      .read(reminderControllerProvider.notifier)
      .reschedule(reminderCopy(l));
}

/// The daily nudge: one switch and one time. Nothing else — a reminder people
/// cannot predict is one they turn off.
class ReminderSection extends ConsumerWidget {
  const ReminderSection({super.key});

  Future<void> _pickTime(
    BuildContext context,
    WidgetRef ref,
    ReminderSchedule schedule,
  ) async {
    final l = AppLocalizations.of(context);
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: schedule.hour, minute: schedule.minute),
    );
    if (picked == null) return;
    await ref.read(reminderControllerProvider.notifier).setTime(
          hour: picked.hour,
          minute: picked.minute,
          copy: reminderCopy(l),
        );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final schedule = ref.watch(reminderControllerProvider).valueOrNull ??
        ReminderSchedule.defaultSchedule;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child:
              Text(l.reminders, style: Theme.of(context).textTheme.titleSmall),
        ),
        SwitchListTile(
          value: schedule.enabled,
          title: Text(l.dailyReminder),
          subtitle: Text(l.dailyReminderHint),
          onChanged: (value) => ref
              .read(reminderControllerProvider.notifier)
              .setEnabled(value, reminderCopy(l)),
        ),
        ListTile(
          leading: const Icon(Icons.schedule),
          title: Text(l.reminderTime),
          subtitle: Text(schedule.label),
          enabled: schedule.enabled,
          onTap: schedule.enabled
              ? () => _pickTime(context, ref, schedule)
              : null,
        ),
      ],
    );
  }
}

/// The notification's own text, in the app's current language.
ReminderCopy reminderCopy(AppLocalizations l) =>
    ReminderCopy(title: l.reminderTitle, body: l.reminderBody);
