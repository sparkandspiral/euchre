import 'dart:async';

import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solitaire/model/save_state.dart';
import 'package:solitaire/providers/save_state_notifier.dart';

const _kRemoteConfigKey = 'games_between_ads';
const _kDefaultGamesBetweenAds = 3;
const _kPrefsCounter = 'games_since_interstitial';

final adServiceProvider = Provider<AdService>((ref) => AdService(ref));

class AdService {
  AdService(this._ref);
  final Ref _ref;

  InterstitialAd? _interstitial;

  Future<void> preload() async {
    if (_interstitial != null) return;
    final adUnitId = defaultTargetPlatform == TargetPlatform.iOS
        ? 'ca-app-pub-8753462308649653/6079870332'
        : 'ca-app-pub-8753462308649653/2443877654';
    await InterstitialAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => _interstitial = ad,
        onAdFailedToLoad: (_) => _interstitial = null,
      ),
    );
  }

  Future<void> maybeShowAfterGame() async {
    final saveState = await _ref.read(saveStateNotifierProvider.future);
    if (saveState.adsRemoved) return;

    final prefs = await SharedPreferences.getInstance();
    final played = prefs.getInt(_kPrefsCounter) ?? 0;
    final threshold = await _fetchGamesBetweenAds();
    if (played + 1 < threshold) {
      await prefs.setInt(_kPrefsCounter, played + 1);
      return;
    }

    await prefs.setInt(_kPrefsCounter, 0);
    await preload();
    if (_interstitial != null) {
      _interstitial!.fullScreenContentCallback =
          FullScreenContentCallback(onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _interstitial = null;
        preload();
      }, onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        _interstitial = null;
      });
      await _interstitial!.show();
    }
  }

  Future<int> _fetchGamesBetweenAds() async {
    try {
      final remoteConfig = FirebaseRemoteConfig.instance;
      await remoteConfig.fetchAndActivate();
      final value = remoteConfig.getInt(_kRemoteConfigKey);
      if (value <= 0) return _kDefaultGamesBetweenAds;
      return value;
    } catch (_) {
      return _kDefaultGamesBetweenAds;
    }
  }
}

