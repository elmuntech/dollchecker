import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Current app locale. Defaults to English; user can switch to Russian in
/// Settings. (V1: persist to profiles.locale.)
final localeProvider = StateProvider<Locale>((ref) => const Locale('en'));

const supportedLocales = [Locale('en'), Locale('ru')];
