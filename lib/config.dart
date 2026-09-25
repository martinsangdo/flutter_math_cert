import 'package:flutter/foundation.dart';

/// Build-time configuration. Pass with:
/// `flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...`
class AppConfig {
  const AppConfig._();

  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static bool get hasSupabase =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  /// Ads only exist on Android/iOS; never on web or desktop.
  static bool get adsSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  // Official Google AdMob test unit ids. Release builds may override them with
  // --dart-define=ADMOB_BANNER_ID=... / ADMOB_REWARDED_ID=...
  static const _bannerOverride = String.fromEnvironment('ADMOB_BANNER_ID');
  static const _rewardedOverride = String.fromEnvironment('ADMOB_REWARDED_ID');

  static bool get _isAndroid => defaultTargetPlatform == TargetPlatform.android;

  static String get bannerUnitId => kReleaseMode && _bannerOverride.isNotEmpty
      ? _bannerOverride
      : _isAndroid
          ? 'ca-app-pub-3940256099942544/6300978111'
          : 'ca-app-pub-3940256099942544/2934735716';

  static String get rewardedUnitId =>
      kReleaseMode && _rewardedOverride.isNotEmpty
          ? _rewardedOverride
          : _isAndroid
              ? 'ca-app-pub-3940256099942544/5224354917'
              : 'ca-app-pub-3940256099942544/1712485313';
}
