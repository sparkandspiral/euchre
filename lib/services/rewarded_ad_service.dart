import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

final rewardedAdServiceProvider = Provider((ref) => RewardedAdService());

class RewardedAdService {
  RewardedAd? _rewarded;

  Future<void> load() async {
    if (_rewarded != null) return;
    final adUnitId = Platform.isIOS
        ? 'ca-app-pub-8753462308649653/7504632648'
        : 'ca-app-pub-8753462308649653/8817714316';
    await RewardedAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) => _rewarded = ad,
        onAdFailedToLoad: (_) => _rewarded = null,
      ),
    );
  }

  Future<bool> showRewardedAd(BuildContext context) async {
    await load();
    if (_rewarded == null) return false;

    final completer = Completer<bool>();
    _rewarded!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _rewarded = null;
        load();
        completer.complete(false);
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _rewarded = null;
        completer.complete(false);
      },
    );

    _rewarded!.show(onUserEarnedReward: (ad, reward) {
      completer.complete(true);
    });
    return completer.future;
  }
}
