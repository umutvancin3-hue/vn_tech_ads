import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

/// Google'in herkese acik test reklam birimlerinin onek'i.
/// Release derlemesinde bu onekle baslayan bir kimlik kullanilirsa
/// [VnAdsConfig.assertNoTestIdsInRelease] hata firlatir.
const String kGoogleTestAdPrefix = 'ca-app-pub-3940256099942544';

/// Tek bir uygulamanin reklam yapilandirmasi.
@immutable
class VnAdsConfig {
  const VnAdsConfig({
    required this.appName,
    this.androidBannerId,
    this.iosBannerId,
    this.androidInterstitialId,
    this.iosInterstitialId,
    this.androidRewardedId,
    this.iosRewardedId,
    this.testDeviceIds = const <String>[],
    this.resetConsentInDebug = false,
    this.debugEeaGeography = false,
  });

  /// Log satirlarinda gorunur; hangi uygulamanin logu oldugunu ayirt etmek icin.
  final String appName;

  final String? androidBannerId;
  final String? iosBannerId;
  final String? androidInterstitialId;
  final String? iosInterstitialId;
  final String? androidRewardedId;
  final String? iosRewardedId;

  /// UMP onay formunu test cihazinda zorlamak icin AdMob test cihaz kimlikleri.
  final List<String> testDeviceIds;

  /// Yalnizca debug derlemede onay durumunu her acilista sifirlar.
  /// Release derlemede yok sayilir.
  final bool resetConsentInDebug;

  /// Yalnizca debug derlemede cihazi AEA'daymis gibi gosterir; boylece
  /// Turkiye'deki emulatorde de UMP onay formu acilir ve akis test edilebilir.
  /// Release derlemede yok sayilir - gercek cografya kullanilir.
  final bool debugEeaGeography;

  String? get bannerId => Platform.isIOS ? iosBannerId : androidBannerId;
  String? get interstitialId =>
      Platform.isIOS ? iosInterstitialId : androidInterstitialId;
  String? get rewardedId => Platform.isIOS ? iosRewardedId : androidRewardedId;

  List<String?> get _allIds => <String?>[
        androidBannerId,
        iosBannerId,
        androidInterstitialId,
        iosInterstitialId,
        androidRewardedId,
        iosRewardedId,
      ];

  /// Release derlemesinde Google'in genel test reklam kimliklerinin
  /// yanlislikla yayina cikmasini engeller.
  void assertNoTestIdsInRelease() {
    if (kDebugMode || kProfileMode) return;
    final List<String> hatalilar = _allIds
        .whereType<String>()
        .where((String id) => id.startsWith(kGoogleTestAdPrefix))
        .toList();
    if (hatalilar.isNotEmpty) {
      throw StateError(
        'VnAds [$appName]: release derlemesinde Google test reklam kimligi '
        'kullaniliyor: ${hatalilar.join(", ")}. Gercek AdMob birimleriyle '
        'degistirin.',
      );
    }
  }
}
