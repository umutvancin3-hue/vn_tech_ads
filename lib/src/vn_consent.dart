import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// UMP (User Messaging Platform) onay akisi.
///
/// AdMob, AEA / Birlesik Krallik / Isvicre kullanicilarina reklam gosterebilmek
/// icin Google onayli bir CMP zorunlu tutar. UMP, google_mobile_ads paketinin
/// icinde gelir ama otomatik calismaz - acikca cagrilmasi gerekir.
class VnConsent {
  VnConsent._();

  /// Onay bilgisini gunceller ve gerekiyorsa onay formunu gosterir.
  ///
  /// Hicbir kosulda hata firlatmaz: ag yoksa veya form yuklenemezse
  /// sessizce tamamlanir, boylece uygulama acilisi bloklanmaz.
  static Future<void> gather({
    String appName = 'VnAds',
    List<String> testDeviceIds = const <String>[],
    bool resetInDebug = false,
    bool eeaInDebug = false,
    Duration timeout = const Duration(seconds: 12),
  }) {
    if (kDebugMode && resetInDebug) {
      ConsentInformation.instance.reset();
    }

    final bool debugAyarGerekli =
        testDeviceIds.isNotEmpty || (kDebugMode && eeaInDebug);

    final ConsentRequestParameters params = debugAyarGerekli
        ? ConsentRequestParameters(
            consentDebugSettings: ConsentDebugSettings(
              testIdentifiers: testDeviceIds.isEmpty ? null : testDeviceIds,
              debugGeography: (kDebugMode && eeaInDebug)
                  ? DebugGeography.debugGeographyEea
                  : null,
            ),
          )
        : ConsentRequestParameters();

    final Completer<void> completer = Completer<void>();

    ConsentInformation.instance.requestConsentInfoUpdate(
      params,
      () async {
        try {
          await _loadAndShowIfRequired(appName);
        } catch (e) {
          debugPrint('$appName/VnConsent: form gosterilemedi: $e');
        }
        if (!completer.isCompleted) completer.complete();
      },
      (FormError error) {
        debugPrint(
          '$appName/VnConsent: onay bilgisi guncellenemedi '
          '(${error.errorCode}) ${error.message}',
        );
        if (!completer.isCompleted) completer.complete();
      },
    );

    return completer.future.timeout(
      timeout,
      onTimeout: () {
        debugPrint('$appName/VnConsent: zaman asimi, acilis surduruluyor.');
      },
    );
  }

  static Future<void> _loadAndShowIfRequired(String appName) {
    final Completer<void> completer = Completer<void>();
    ConsentForm.loadAndShowConsentFormIfRequired((FormError? error) {
      if (error != null) {
        debugPrint(
          '$appName/VnConsent: onay formu hatasi '
          '(${error.errorCode}) ${error.message}',
        );
      }
      if (!completer.isCompleted) completer.complete();
    });
    return completer.future;
  }

  /// Reklam istegi yapilabilir mi? Onay reddedilmisse false doner.
  static Future<bool> canRequestAds() =>
      ConsentInformation.instance.canRequestAds();

  /// Kullaniciya "Gizlilik secenekleri" dugmesi gosterilmeli mi?
  ///
  /// UMP kurallarina gore onay verdikten sonra kullanicinin kararini
  /// degistirebilmesi gerekir. Ayarlar ekraninda bu true ise bir dugme cikar.
  static Future<bool> isPrivacyOptionsRequired() async {
    final PrivacyOptionsRequirementStatus status =
        await ConsentInformation.instance.getPrivacyOptionsRequirementStatus();
    return status == PrivacyOptionsRequirementStatus.required;
  }

  /// Ayarlar ekranindaki "Gizlilik secenekleri" dugmesine baglanir.
  static Future<void> showPrivacyOptions({String appName = 'VnAds'}) {
    final Completer<void> completer = Completer<void>();
    ConsentForm.showPrivacyOptionsForm((FormError? error) {
      if (error != null) {
        debugPrint(
          '$appName/VnConsent: gizlilik secenekleri hatasi '
          '(${error.errorCode}) ${error.message}',
        );
      }
      if (!completer.isCompleted) completer.complete();
    });
    return completer.future;
  }
}
