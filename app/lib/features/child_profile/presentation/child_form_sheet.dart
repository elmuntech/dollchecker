import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:dollchecker/features/child_profile/child_profile.dart';
import 'package:dollchecker/l10n/app_localizations.dart';

/// Bottom sheet used to add a child or edit an existing one.
/// Returns the saved profile, or null if the user backed out.
Future<ChildProfile?> showChildFormSheet(
  BuildContext context, {
  ChildProfile? existing,
}) {
  return showModalBottomSheet<ChildProfile>(
    context: context,
    isScrollControlled: true,
    builder: (_) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: _ChildForm(existing: existing),
    ),
  );
}

class _ChildForm extends ConsumerStatefulWidget {
  const _ChildForm({this.existing});
  final ChildProfile? existing;

  @override
  ConsumerState<_ChildForm> createState() => _ChildFormState();
}

class _ChildFormState extends ConsumerState<_ChildForm> {
  late final TextEditingController _name =
      TextEditingController(text: widget.existing?.name ?? '');
  late DateTime? _birthDate = widget.existing?.birthDate;
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
      initialDate: _birthDate ?? DateTime(now.year - 3),
      firstDate: DateTime(now.year - 18),
      lastDate: now,
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    final repo = ref.read(childRepositoryProvider);
    try {
      final saved = widget.existing == null
          ? await repo.create(name: name, birthDate: _birthDate)
          : await repo.update(
              id: widget.existing!.id, name: name, birthDate: _birthDate);
      ref.invalidate(childrenProvider);
      if (mounted) Navigator.of(context).pop(saved);
    } catch (_) {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.existing == null ? l.addChild : l.editChild,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _name,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
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
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(l.save),
            ),
          ],
        ),
      ),
    );
  }
}
