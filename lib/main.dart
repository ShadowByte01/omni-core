import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'config/supabase_config.dart';

/// App entry point.
///
/// 1. Ensures Flutter bindings are ready.
/// 2. Conditionally initialises Supabase — only when credentials are present.
///    If absent, the app boots 100% offline and never prompts for login.
/// 3. Wraps the app in a [ProviderScope] (Riverpod) so the whole tree shares
///    the offline-first Drift DB, auth, connectivity and sync controllers.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (SupabaseConfig.isConfigured) {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.anonKey,
      debug: false,
    );
  }

  runApp(
    const ProviderScope(
      child: OmniCoreApp(),
    ),
  );
}
