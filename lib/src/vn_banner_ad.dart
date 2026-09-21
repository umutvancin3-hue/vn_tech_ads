import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'vn_ads.dart';

/// Tum VN-Tech uygulamalarinda kullanilan ortak banner reklam widget'i.
///
/// - Uyarlanabilir (anchored adaptive) boyut kullanir; sabit 320x50'ye gore
///   daha yuksek gelir getirir.
/// - Reklam yuklenmeden yer kaplamaz.
/// - [enabled] false ise (premium kullanici, reklam kaldirma satin alinmis)
///   hicbir istek yapmaz.
class VnBannerAd extends StatefulWidget {
  const VnBannerAd({
    super.key,
    this.enabled = true,
    this.fallbackSize = AdSize.banner,
  });

  final bool enabled;
  final AdSize fallbackSize;

  @override
  State<VnBannerAd> createState() => _VnBannerAdState();
}

class _VnBannerAdState extends State<VnBannerAd> {
  BannerAd? _ad;
  bool _loaded = false;
  bool _istendi = false;
  bool _izinBekleniyor = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_istendi) {
      _istendi = true;
      _yukle();
    }
  }

  @override
  void didUpdateWidget(covariant VnBannerAd oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled && !widget.enabled) {
      _ad?.dispose();
      _ad = null;
      _loaded = false;
    } else if (!oldWidget.enabled && widget.enabled) {
      _yukle();
    }
  }

  Future<void> _yukle() async {
    if (!widget.enabled) return;
    if (!VnAds.isInitialized) return;

    // Onay formu acilistan sonra onaylandiysa izin gecikmeli gelir;
    // o an banner'i yeniden dene.
    if (!VnAds.canRequestAds) {
      if (!_izinBekleniyor) {
        _izinBekleniyor = true;
        VnAds.reklamIzniVerilince(() {
          _izinBekleniyor = false;
          if (mounted) unawaited(_yukle());
        });
      }
      return;
    }

    final String? unitId = VnAds.config.bannerId;
    if (unitId == null || unitId.isEmpty) return;

    final double genislik = MediaQuery.sizeOf(context).width;
    final AdSize boyut =
        await AdSize.getLargeAnchoredAdaptiveBannerAdSize(
              genislik.truncate(),
            ) ??
            widget.fallbackSize;

    if (!mounted) return;

    final BannerAd banner = BannerAd(
      adUnitId: unitId,
      size: boyut,
      request: VnAds.request(),
      listener: BannerAdListener(
        onAdLoaded: (Ad ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }
          setState(() => _loaded = true);
        },
        onAdFailedToLoad: (Ad ad, LoadAdError error) {
          ad.dispose();
          if (!mounted) return;
          setState(() {
            _ad = null;
            _loaded = false;
          });
        },
      ),
    );

    _ad = banner;
    await banner.load();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final BannerAd? ad = _ad;
    if (!widget.enabled || !_loaded || ad == null) {
      return const SizedBox.shrink();
    }
    return SizedBox(
      width: ad.size.width.toDouble(),
      height: ad.size.height.toDouble(),
      child: AdWidget(ad: ad),
    );
  }
}
