import 'package:flutter/foundation.dart';

/// Build-time configuration. Pass with:
/// `flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...`
class AppConfig {
  const AppConfig._();

  static const _rawSupabaseUrl = String.fromEnvironment('SUPABASE_URL');

  /// The project origin only (`https://<ref>.supabase.co`). A pasted
  /// `/rest/v1/` suffix or trailing slash would 404 every auth call.
  static String get supabaseUrl {
    final uri = Uri.tryParse(_rawSupabaseUrl.trim());
    return uri != null && uri.hasScheme && uri.host.isNotEmpty
        ? uri.origin
        : _rawSupabaseUrl.trim();
  }

  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static bool get hasSupabase =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.trim().isNotEmpty;

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
