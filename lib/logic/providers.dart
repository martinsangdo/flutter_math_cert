import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';
import '../services/ad_service.dart';
import '../services/cache_service.dart';
import '../services/supabase_service.dart';

/// Overridden in `main()` once Hive is open.
final cacheServiceProvider = Provider<CacheService>((_) => throw UnimplementedError());

final adServiceProvider = Provider<AdService>((_) => const AdService());

final supabaseServiceProvider = Provider<SupabaseService>(
  (ref) => SupabaseService(Supabase.instance.client, ref.watch(cacheServiceProvider)),
);

final certificationsProvider = FutureProvider<List<Certification>>(
  (ref) => ref.watch(supabaseServiceProvider).fetchCertifications(),
);

/// The student's chosen contest and grade, persisted locally. Null until onboarding.
class SelectionNotifier extends Notifier<Selection?> {
  @override
  Selection? build() {
    final cache = ref.watch(cacheServiceProvider);
    final cert = cache.readPref('cert');
    final grade = int.tryParse(cache.readPref('grade') ?? '');
    return cert == null || grade == null ? null : Selection(cert, grade);
  }

  Future<void> select(String certId, int grade) async {
    final cache = ref.read(cacheServiceProvider);
    await cache.writePref('cert', certId);
    await cache.writePref('grade', '$grade');
    state = Selection(certId, grade);
  }
}

final selectionProvider = NotifierProvider<SelectionNotifier, Selection?>(SelectionNotifier.new);

/// The selected contest's full record.
final selectedCertProvider = FutureProvider<Certification>((ref) async {
  final selection = ref.watch(selectionProvider)!;
  final certs = await ref.watch(certificationsProvider.future);
  return certs.firstWhere((c) => c.id == selection.certId);
});

/// When the student sits the exam. The schema has no exam date, so the
/// student sets it and it lives on the device, per contest.
class ExamDateNotifier extends Notifier<DateTime?> {
  late String _key;

  @override
  DateTime? build() {
    _key = 'exam:${ref.watch(selectionProvider)?.certId}';
    return DateTime.tryParse(ref.watch(cacheServiceProvider).readPref(_key) ?? '');
  }

  Future<void> set(DateTime date) async {
    await ref.read(cacheServiceProvider).writePref(_key, date.toIso8601String());
    state = date;
  }
}

final examDateProvider = NotifierProvider<ExamDateNotifier, DateTime?>(ExamDateNotifier.new);

final homeDataProvider = FutureProvider.autoDispose<HomeData>((ref) async {
  final cert = await ref.watch(selectedCertProvider.future);
  return ref.watch(supabaseServiceProvider).fetchHomeData(cert);
});
