import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'vn_ads.dart';

/// Tum VN-Tech uygulamalarinda kullanilan ortak gecis (interstitial) reklami.
///
/// Politika notu: gecis reklami kullanicinin istedigi icerigin ONUNU KESMEZ.
/// Dogru yer, kullanicinin bir isi bitirip geri dondugu dogal moladir
/// (ornegin sonuc ekranindan cikis). Bu sinif ayrica iki koruma saglar:
///   - [enAzAra]: iki reklam arasinda en az bu kadar sure gecmeden gosterilmez
///   - [gunlukTavan]: gun icinde bu sayidan fazla gosterilmez
///
/// Reklam her zaman ONCEDEN yuklenir; [goster] hazir degilse sessizce false
/// doner ve kullaniciyi bekletmez.
class VnInterstitial {
  VnInterstitial._();

  static InterstitialAd? _ad;
  static bool _yukleniyor = false;
  static DateTime? _sonGosterim;
  static String _gun = '';
  static int _bugunGosterilen = 0;

  /// Elde gosterilmeye hazir bir reklam var mi.
  static bool get hazir => _ad != null;

  static int get bugunGosterilen {
    _gunuTazele();
    return _bugunGosterilen;
  }

  static void _gunuTazele() {
    final DateTime n = DateTime.now();
    final String bugun = '${n.year}-${n.month}-${n.day}';
    if (_gun != bugun) {
      _gun = bugun;
      _bugunGosterilen = 0;
    }
  }

  /// Arka planda reklami yukler. Cagirmak ucuzdur; zaten yuklu veya
  /// yukleniyorsa hicbir sey yapmaz.
  static Future<void> onYukle() async {
    if (_ad != null || _yukleniyor) return;
    if (!VnAds.isInitialized || !VnAds.canRequestAds) return;

    final String? birim = VnAds.config.interstitialId;
    if (birim == null || birim.isEmpty) return;

    _yukleniyor = true;
    await InterstitialAd.load(
      adUnitId: birim,
      request: VnAds.request(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (InterstitialAd ad) {
          _ad = ad;
          _yukleniyor = false;
        },
        onAdFailedToLoad: (LoadAdError error) {
          _ad = null;
          _yukleniyor = false;
          debugPrint(
            'VNADS gecis yuklenemedi: ${error.code} ${error.message}',
          );
        },
      ),
    );
  }

  /// Hazirsa ve sinirlar uygunsa reklami gosterir.
  ///
  /// Reklam kapanana kadar bekler, sonra true doner. Gosterilemediyse
  /// (hazir degil, gun tavani dolu, aradaki sure yetmedi) false doner ve
  /// bir sonraki sefer icin yeniden yukleme baslatir.
  static Future<bool> goster({
    Duration enAzAra = const Duration(seconds: 40),
    int gunlukTavan = 6,
  }) async {
    _gunuTazele();

    if (_bugunGosterilen >= gunlukTavan) {
      unawaited(onYukle());
      return false;
    }

    final DateTime? son = _sonGosterim;
    if (son != null && DateTime.now().difference(son) < enAzAra) {
      return false;
    }

    final InterstitialAd? ad = _ad;
    if (ad == null) {
      unawaited(onYukle());
      return false;
    }
    _ad = null;

    final Completer<void> kapandi = Completer<void>();
    ad.fullScreenContentCallback = FullScreenContentCallback<InterstitialAd>(
      onAdDismissedFullScreenContent: (InterstitialAd a) {
        a.dispose();
        if (!kapandi.isCompleted) kapandi.complete();
        unawaited(onYukle());
      },
      onAdFailedToShowFullScreenContent: (InterstitialAd a, AdError e) {
        a.dispose();
        if (!kapandi.isCompleted) kapandi.complete();
        unawaited(onYukle());
      },
    );

    _sonGosterim = DateTime.now();
    _bugunGosterilen++;

    try {
      await ad.show();
    } catch (e) {
      debugPrint('VNADS gecis gosterilemedi: $e');
      if (!kapandi.isCompleted) kapandi.complete();
    }

    await kapandi.future;
    return true;
  }

  @visibleForTesting
  static void resetForTest() {
    _ad?.dispose();
    _ad = null;
    _yukleniyor = false;
    _sonGosterim = null;
    _gun = '';
    _bugunGosterilen = 0;
  }
}
