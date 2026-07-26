import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dollchecker/app.dart';
import 'package:dollchecker/core/config/env.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env');

  if (!Env.isConfigured) {
    runApp(const _MisconfiguredApp());
    return;
  }

  await Supabase.initialize(
    url: Env.supabaseUrl,
    // `publishableKey` is the current name for what the dashboard still calls
    // the anon key — a public client key, safe to ship. RLS protects the data.
    publishableKey: Env.supabaseAnonKey,
  );

  runApp(const ProviderScope(child: DollCheckerApp()));
}

/// Shown when `.env` still holds placeholder values.
class _MisconfiguredApp extends StatelessWidget {
  const _MisconfiguredApp();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Missing configuration.\n\n'
              'Copy app/.env.example to app/.env and set SUPABASE_URL and '
              'SUPABASE_ANON_KEY, then restart.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
