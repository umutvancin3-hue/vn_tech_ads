import 'dart:async';
import 'dart:io' show Platform;

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'vn_ads_config.dart';
import 'vn_consent.dart';

/// VN-Tech uygulamalarinda reklam baslatmanin tek giris noktasi.
///
/// Dogru sira sudur ve bu sinif onu garanti eder:
///   1) UMP onayi topla
///   2) iOS ise ATT izni iste
///   3) EN SON MobileAds.instance.initialize()
///
/// MobileAds'i onaydan once baslatmak, AEA kullanicilarinda reklamlarin
/// bos donmesine yol acar.
class VnAds {
  VnAds._();

  static VnAdsConfig? _config;
  static bool _initialized = false;
  static bool _nonPersonalized = false;
  static bool _canRequestAds = true;

  static final List<void Function()> _izinBekleyenler = <void Function()>[];
  static Timer? _izinIzleyici;

  static bool get isInitialized => _initialized;
  static bool get nonPersonalized => _nonPersonalized;
  static bool get canRequestAds => _canRequestAds;

  static VnAdsConfig get config {
    final VnAdsConfig? c = _config;
    if (c == null) {
      throw StateError('VnAds.init() cagrilmadan reklam yapilandirmasi okundu.');
    }
    return c;
  }

  /// main() icinde runApp'ten once cagrilir.
  ///
  /// Hicbir kosulda hata firlatmaz (release'de test reklam kimligi
  /// kullanilmasi disinda) - ag yoksa bile uygulama acilir.
  static Future<void> init(VnAdsConfig config) async {
    _config = config;
    config.assertNoTestIdsInRelease();

    await VnConsent.gather(
      appName: config.appName,
      testDeviceIds: config.testDeviceIds,
      resetInDebug: config.resetConsentInDebug,
      eeaInDebug: config.debugEeaGeography,
    );

    try {
      _canRequestAds = await VnConsent.canRequestAds();
    } catch (e) {
      debugPrint('${config.appName}/VnAds: canRequestAds okunamadi: $e');
      _canRequestAds = true;
    }

    if (!kIsWeb && Platform.isIOS) {
      await _requestAtt(config.appName);
    }

    try {
      await MobileAds.instance.initialize();
      _initialized = true;
    } catch (e) {
      debugPrint('${config.appName}/VnAds: MobileAds baslatilamadi: $e');
    }

    await _durumuYazdir(config.appName);

    // Onay formu acilista 12 saniyede kapanmadiysa init bloklanmasin diye
    // devam ediyoruz; ama kullanici formu birkac saniye sonra onaylarsa
    // reklam izni o anda aciliyor. Bunu yakalamak icin kisa sureli izleyici.
    if (!_canRequestAds) _izniIzle(config.appName);
  }

  /// Reklam izni (henuz) yoksa, izin gelince calisacak isi kaydeder.
  /// Izin zaten varsa isi hemen calistirir.
  ///
  /// Tipik kullanim - main() icinde:
  ///   VnAds.reklamIzniVerilince(() {
  ///     VnInterstitial.onYukle();
  ///     VnRewarded.onYukle();
  ///   });
  static void reklamIzniVerilince(void Function() is_) {
    if (_canRequestAds) {
      is_();
      return;
    }
    _izinBekleyenler.add(is_);
  }

  static void _izniIzle(String appName) {
    _izinIzleyici?.cancel();
    int deneme = 0;
    _izinIzleyici = Timer.periodic(const Duration(seconds: 4), (Timer t) async {
      deneme++;
      bool izin = false;
      try {
        izin = await VnConsent.canRequestAds();
      } catch (_) {}

      if (izin) {
        _canRequestAds = true;
        t.cancel();
        _izinIzleyici = null;
        debugPrint('VNADS [$appName] onay sonradan verildi, reklamlar acildi.');
        final List<void Function()> kuyruk =
            List<void Function()>.from(_izinBekleyenler);
        _izinBekleyenler.clear();
        for (final void Function() is_ in kuyruk) {
          try {
            is_();
          } catch (e) {
            debugPrint('VNADS [$appName] izin isi hatasi: $e');
          }
        }
      } else if (deneme >= 45) {
        // ~3 dakika sonra birak; kullanici formu acmamis demektir.
        t.cancel();
        _izinIzleyici = null;
      }
    });
  }

  /// Emulator / cihaz dogrulamasi icin tek satirlik ozet.
  /// logcat'te `VNADS` ile filtrelenir.
  static Future<void> _durumuYazdir(String appName) async {
    try {
      final ConsentStatus durum =
          await ConsentInformation.instance.getConsentStatus();
      final bool gizlilikGerekli = await VnConsent.isPrivacyOptionsRequired();
      debugPrint(
        'VNADS [$appName] onayDurumu=${durum.name} '
        'reklamIstenebilir=$_canRequestAds '
        'kisisellestirilmemis=$_nonPersonalized '
        'gizlilikSecenekleri=$gizlilikGerekli '
        'mobileAdsHazir=$_initialized',
      );
    } catch (e) {
      debugPrint('VNADS [$appName] durum okunamadi: $e');
    }
  }

  /// Tum reklam isteklerinde bunu kullan; ATT reddedilmisse
  /// kisisellestirilmemis reklam ister.
  static AdRequest request() =>
      AdRequest(nonPersonalizedAds: _nonPersonalized);

  static Future<void> _requestAtt(String appName) async {
    try {
      TrackingStatus status =
          await AppTrackingTransparency.trackingAuthorizationStatus;
      if (status == TrackingStatus.notDetermined) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
        status = await AppTrackingTransparency.requestTrackingAuthorization();
      }
      if (status == TrackingStatus.denied ||
          status == TrackingStatus.restricted) {
        _nonPersonalized = true;
      }
    } catch (e) {
      debugPrint('$appName/VnAds: ATT istegi basarisiz: $e');
    }
  }

  /// Testlerde durumu sifirlamak icin.
  @visibleForTesting
  static void resetForTest() {
    _izinIzleyici?.cancel();
    _izinIzleyici = null;
    _izinBekleyenler.clear();
    _config = null;
    _initialized = false;
    _nonPersonalized = false;
    _canRequestAds = true;
  }
}
