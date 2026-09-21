# vn_tech_ads

VN-Tech uygulamalarinin ortak reklam modulu. Her uygulamada tekrarlanan
UMP onayi / ATT / AdMob baslatma kodunu tek yerde toplar.

## Neden var

21 Eylul 2026 taramasi: 16 reklamli projenin 15'inde UMP onay akisi yoktu.
AdMob, AEA / Birlesik Krallik / Isvicre kullanicilarina reklam gosterebilmek
icin Google onayli bir CMP zorunlu tutuyor. UMP `google_mobile_ads` icinde
geliyor ama otomatik calismiyor - acikca cagrilmasi gerekiyor. Onay olmadan
Avrupa gosterimleri bos veya cok dusuk gelirli donuyor.

## Kurulum

Uygulamanin `pubspec.yaml` dosyasina:

```yaml
dependencies:
  vn_tech_ads:
    path: ../../0-PAKET/vn_tech_ads
```

(Bu yol `apps\1-yayin\*`, `apps\2-test\*` ve `apps\3-gelistirme\*` altindaki
tum uygulamalar icin aynidir.)

Uygulamanin kendi `google_mobile_ads` ve `app_tracking_transparency`
satirlari **silinir** - bu paket onlari getirir.

## Kullanim

`main.dart`:

```dart
import 'package:vn_tech_ads/vn_tech_ads.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await VnAds.init(const VnAdsConfig(
    appName: 'Ruya AI',
    androidBannerId: 'ca-app-pub-8812132500947904/3763080174',
    iosBannerId: null, // iOS AdMob kaydi acilinca doldurulacak
  ));

  runApp(const MyApp());
}
```

Banner:

```dart
VnBannerAd(enabled: !kullaniciPremium)
```

Ayarlar ekranindaki zorunlu "Gizlilik secenekleri" dugmesi:

```dart
FutureBuilder<bool>(
  future: VnConsent.isPrivacyOptionsRequired(),
  builder: (context, snap) {
    if (snap.data != true) return const SizedBox.shrink();
    return ListTile(
      title: const Text('Gizlilik secenekleri'),
      onTap: () => VnConsent.showPrivacyOptions(),
    );
  },
)
```

## Kurallar

1. `MobileAds.instance.initialize()` uygulamada **dogrudan cagrilmaz**.
   Her zaman `VnAds.init()` uzerinden gider.
2. Reklam istekleri `VnAds.request()` kullanir - ATT reddedildiginde
   otomatik olarak kisisellestirilmemis reklam ister.
3. Release derlemesinde Google'in genel test reklam kimligi
   (`ca-app-pub-3940256099942544...`) kullanilirsa `VnAds.init()`
   `StateError` firlatir. Bu kasitlidir.
4. Reklamsiz uygulamalar (WidgetLab, SiteMark) bu paketi **kullanmaz** -
   aksi halde AD_ID izni manifest'e girer ve Veri Guvenligi beyani bozulur.

## Surum gecmisi

- 1.0.0 (21 Eyl 2026) - ilk surum. UMP onayi, ATT, adaptif banner,
  gizlilik secenekleri formu, release test-kimligi korumasi.
