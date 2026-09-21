import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'vn_ads.dart';

/// Tum VN-Tech uygulamalarinda kullanilan ortak odullu (rewarded) reklam.
///
/// Odullu reklam her zaman kullanicinin KENDI istegiyle baslar; bu sinif
/// reklami yalnizca [goster] cagrildiginda acar. Odul, reklam sonuna kadar
/// izlendiginde verilir; kullanici yarida keserse [goster] false doner ve
/// hicbir hak verilmez.
class VnRewarded {
  VnRewarded._();

  static RewardedAd? _ad;
  static bool _yukleniyor = false;

  /// Kullaniciya "reklam izle" dugmesini aktif etmeden once bunu kontrol et.
  static bool get hazir => _ad != null;

  static bool get yukleniyor => _yukleniyor;

  /// Arka planda reklami yukler. Cagirmak ucuzdur.
  static Future<void> onYukle() async {
    if (_ad != null || _yukleniyor) return;
    if (!VnAds.isInitialized || !VnAds.canRequestAds) return;

    final String? birim = VnAds.config.rewardedId;
    if (birim == null || birim.isEmpty) return;

    _yukleniyor = true;
    await RewardedAd.load(
      adUnitId: birim,
      request: VnAds.request(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (RewardedAd ad) {
          _ad = ad;
          _yukleniyor = false;
        },
        onAdFailedToLoad: (LoadAdError error) {
          _ad = null;
          _yukleniyor = false;
          debugPrint(
            'VNADS odullu yuklenemedi: ${error.code} ${error.message}',
          );
        },
      ),
    );
  }

  /// Odullu reklami gosterir.
  ///
  /// Kullanici reklami sonuna kadar izlediyse true, aksi halde false doner.
  /// Reklam hazir degilse hemen false doner ve yeniden yukleme baslatir.
  static Future<bool> goster() async {
    final RewardedAd? ad = _ad;
    if (ad == null) {
      unawaited(onYukle());
      return false;
    }
    _ad = null;

    bool odulKazanildi = false;
    final Completer<void> kapandi = Completer<void>();

    ad.fullScreenContentCallback = FullScreenContentCallback<RewardedAd>(
      onAdDismissedFullScreenContent: (RewardedAd a) {
        a.dispose();
        if (!kapandi.isCompleted) kapandi.complete();
        unawaited(onYukle());
      },
      onAdFailedToShowFullScreenContent: (RewardedAd a, AdError e) {
        a.dispose();
        if (!kapandi.isCompleted) kapandi.complete();
        unawaited(onYukle());
      },
    );

    try {
      await ad.show(
        onUserEarnedReward: (AdWithoutView a, RewardItem reward) {
          odulKazanildi = true;
        },
      );
    } catch (e) {
      debugPrint('VNADS odullu gosterilemedi: $e');
      if (!kapandi.isCompleted) kapandi.complete();
    }

    await kapandi.future;
    return odulKazanildi;
  }

  @visibleForTesting
  static void resetForTest() {
    _ad?.dispose();
    _ad = null;
    _yukleniyor = false;
  }
}
