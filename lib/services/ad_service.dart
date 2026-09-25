import 'dart:async';

import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../config.dart';

class AdService {
  const AdService();

  Future<void> init() async {
    if (AppConfig.adsSupported) await MobileAds.instance.initialize();
  }

  /// Loads a rewarded ad on demand (nothing stays in memory between uses) and
  /// resolves to true only if `onUserEarnedReward` fired. Where ads are
  /// unsupported (web/desktop) the reward is granted without an ad.
  Future<bool> showRewarded() {
    if (!AppConfig.adsSupported) return Future.value(true);

    final result = Completer<bool>();
    var earned = false;
    RewardedAd.load(
      adUnitId: AppConfig.rewardedUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              result.complete(earned);
            },
            onAdFailedToShowFullScreenContent: (ad, _) {
              ad.dispose();
              result.complete(false);
            },
          );
          ad.show(onUserEarnedReward: (_, _) => earned = true);
        },
        onAdFailedToLoad: (_) => result.complete(false),
      ),
    );
    return result.future;
  }
}
