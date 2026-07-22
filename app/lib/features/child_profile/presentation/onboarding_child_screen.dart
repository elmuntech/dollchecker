import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:dollchecker/features/child_profile/child_profile.dart';
import 'package:dollchecker/l10n/app_localizations.dart';

class OnboardingChildScreen extends ConsumerStatefulWidget {
  const OnboardingChildScreen({super.key});

  @override
  ConsumerState<OnboardingChildScreen> createState() =>
      _OnboardingChildScreenState();
}

class _OnboardingChildScreenState
    extends ConsumerState<OnboardingChildScreen> {
  final _name = TextEditingController();
  DateTime? _birthDate;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 3),
      firstDate: DateTime(now.year - 18),
      lastDate: now,
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) return;
    setState(() => _saving = true);
    await ref
        .read(childRepositoryProvider)
        .create(name: _name.text.trim(), birthDate: _birthDate);
    ref.invalidate(childrenProvider);
    // Router redirect will move us to home once a child exists.
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.onboardingTitle)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l.onboardingSubtitle,
                  style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: 24),
              TextField(
                controller: _name,
                decoration: InputDecoration(labelText: l.childName),
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(14),
                child: InputDecorator(
                  decoration: InputDecoration(labelText: l.childBirthDate),
                  child: Text(
                    _birthDate == null
                        ? l.pickDate
                        : DateFormat.yMMMMd().format(_birthDate!),
                  ),
                ),
              ),
              const Spacer(),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(l.continueLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
