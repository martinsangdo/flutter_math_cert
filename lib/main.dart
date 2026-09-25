import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';
import 'logic/providers.dart';
import 'services/ad_service.dart';
import 'services/cache_service.dart';
import 'views/home_screen.dart';
import 'views/onboarding_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Keep decoded-image memory small for 2GB devices.
  PaintingBinding.instance.imageCache
    ..maximumSize = 50
    ..maximumSizeBytes = 20 << 20;

  if (!AppConfig.hasSupabase) {
    runApp(const _MissingConfigApp());
    return;
  }

  final cache = await CacheService.open();
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    // ignore: deprecated_member_use -- keeps compatibility with supabase_flutter ^2.0.0
    anonKey: AppConfig.supabaseAnonKey,
  );
  await const AdService().init();

  runApp(ProviderScope(
    overrides: [cacheServiceProvider.overrideWithValue(cache)],
    child: const MathPathwayApp(),
  ));
}

class MathPathwayApp extends ConsumerWidget {
  const MathPathwayApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Read once: after onboarding, screens navigate themselves.
    final hasSelection = ref.read(selectionProvider) != null;
    return MaterialApp(
      title: 'MathPathway Junior',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: hasSelection ? const HomeScreen() : const OnboardingScreen(),
    );
  }
}

class _MissingConfigApp extends StatelessWidget {
  const _MissingConfigApp();

  @override
  Widget build(BuildContext context) => const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Missing Supabase config.\nRun with\n'
                '--dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      );
}
