# Biçim desteği — ölçüm

Bu dosya bir tasarım belgesi değil, bir **tutanak**. Her satır iPhone 16
simülatöründe (iOS 26, Xcode 26.4) gerçek dosyalarla koşturulmuş bir ölçümün
sonucu. Yeniden üretmek için en altta komutlar var.

Ölçüm **iOS'ta** yapıldı, macOS'ta değil. Bu ayrım önemli: `.mpg` ve `.ts`
macOS'ta AVFoundation tarafından açılıyor, iOS'ta açılmıyor. Ana makinede
yapılan bir ölçüm bu iki biçim için yanlış cevap verirdi.

---

## Giriş — kapsayıcılar

`AVF açıyor`: AVFoundation kapsayıcıyı açıp süre okuyabiliyor mu.
`ses`: açtıysa içinde ses kanalı buldu mu.
`FFmpeg`: yedek yolun bulduğu kodek ve örnekleme/kanal.

| dosya | UTI | seçilebilir | AVF açıyor | ses | FFmpeg |
|---|---|---|---|---|---|
| `a.aac` | `public.aac-audio` | ✅ | ✅ | var | *(gerekmedi)* |
| `a.aiff` | `public.aiff-audio` | ✅ | ✅ | var | *(gerekmedi)* |
| `a.m4a` (ALAC) | `com.apple.m4a-audio` | ✅ | ✅ | var | *(gerekmedi)* |
| `a.caf` | `com.apple.coreaudio-format` | ✅ | ✅ | var | *(gerekmedi)* |
| `a.flac` | `org.xiph.flac` | ✅ | ✅ | var | *(gerekmedi)* |
| `a.m4a` (AAC) | `com.apple.m4a-audio` | ✅ | ✅ | var | *(gerekmedi)* |
| `a.mp3` | `public.mp3` | ✅ | ✅ | var | *(gerekmedi)* |
| `a.wav` | `com.microsoft.waveform-audio` | ✅ | ✅ | var | *(gerekmedi)* |
| `v.3gp` | `public.3gpp` | ✅ | ✅ | var | *(gerekmedi)* |
| `v.m4v` | `com.apple.m4v-video` | ✅ | ✅ | var | *(gerekmedi)* |
| `v.mov` | `com.apple.quicktime-movie` | ✅ | ✅ | var | *(gerekmedi)* |
| `v.mp4` | `public.mpeg-4` | ✅ | ✅ | var | *(gerekmedi)* |
| `a.mka` | `org.matroska.mka` † | ✅ | ❌ | — | opus 48000/2 |
| `a.ogg` | `org.xiph.ogg-audio` † | ✅ | ❌ | — | flac 44100/2 |
| `a.opus` | `org.xiph.opus` † | ✅ | ❌ | — | opus 48000/2 |
| `a.wma` | `com.microsoft.windows-media-wma` | ✅ | ❌ | — | wmav2 44100/2 |
| `v.asf` | `com.microsoft.advanced-systems-format` ‡ | ✅ | ❌ | — | wmav2 44100/2 |
| **`v.avi`** | `public.avi` | ✅ | ✅ | **YOK** | mp3float 44100/2 |
| `v.flv` | `com.adobe.flash.video` | ✅ | ❌ | — | mp3float 44100/2 |
| `v.mkv` | `org.matroska.mkv` † | ✅ | ❌ | — | opus 48000/2 |
| `v.mpg` | `public.mpeg` | ✅ | ❌ | — | mp2 44100/2 |
| `v.ts` | `public.mpeg-2-transport-stream` | ✅ | ❌ | — | aac 44100/2 |
| `v.webm` | `org.webmproject.webm` | ✅ | ❌ | — | opus 48000/2 |
| `v.wmv` | `com.microsoft.windows-media-wmv` | ✅ | ❌ | — | wmav2 44100/2 |

**24/24 kapsanıyor.** AVFoundation 11'ini açıyor, FFmpeg kalan 13'ünü.

*"gerekmedi"*: FFmpeg'e mp4/mov/wav/mp3/flac demuxer'ları **bilerek
açılmadı** — AVFoundation onları zaten açıyor ve boyutu ikiye katlamanın
anlamı yok. O satırlarda FFmpeg `unsupportedContainer` döndürüyor, ki bu bir
eksik değil, kapsam kararı.

### Üç tuzak

**† Sistemde UTI'si olmayan tipler.** `UTType(filenameExtension: "mkv")` iOS'ta
dinamik bir tanımlayıcı (`dyn.ah62d4rv4ge804450`) döndürüyor ve
`public.movie`'ye **uymuyor**. Sonuç: dosya seçici `[.movie, .video, .audio]`
filtresiyle açıldığında `.mkv`, `.mka`, `.ogg`, `.opus` dosyaları **soluk ve
seçilemez**. FFmpeg'i eklemek, kullanıcı dosyayı seçemedikçe hiçbir işe
yaramıyordu. `Info.plist` → `UTImportedTypeDeclarations` bunları kaydediyor.

**‡ Sistemin kendi tanımladığı ama uymayan tip.** `.asf`'nin UTI'si **var** ama
`public.movie`'ye uymuyor, ve "imported" bildirim sistemin kendi tanımladığı
bir tipin uygunluğunu **değiştiremiyor** (denendi, LaunchServices yok saydı).
Tek yol seçiciye adıyla eklemek → `MediaTypes.extras`.

**`v.avi` — en sinsisi.** AVFoundation dosyayı **açıyor**, süre veriyor, ama
ses kanalı listesi **boş** dönüyor. Yani "desteklenmiyor" hatası hiç almıyoruz;
sessizce sesi olmayan bir dosya görüyoruz. Boru hattı bu yüzden yedek yola
"AVFoundation hata verdi" diye değil, **"ses kanalı bulamadı"** diye geçiyor
(`NativeDecoder.decode`). İki durumu ayıramayız, ve ayırmaya da gerek yok:
FFmpeg kapsayıcıyı açabiliyorsa cevap ikincisidir.

---

## Çıkış — kodlayıcılar

iOS'un gerçekten sahip olduğu ses kodlayıcıları. Kaynak: 2 sn 44,1 kHz stereo.

| kodlayıcı | kapsayıcı | sonuç | boyut |
|---|---|---|---|
| AAC | `.m4a` | ✅ yazdı | 21.562 B |
| Apple Lossless (ALAC) | `.m4a` | ✅ yazdı | 75.343 B |
| PCM 16-bit | `.wav` | ✅ yazdı | 356.896 B |
| PCM 16-bit | `.aiff` | ✅ yazdı | 356.896 B |
| FLAC | `.caf` | ❌ kapsayıcı kabul etmiyor | — |
| Opus | `.caf` | ❌ kapsayıcı kabul etmiyor | — |
| AMR | `.amr` | ❌ `Cannot Encode` | — |
| **MP3** | — | ❌ **iOS'ta MP3 kodlayıcı YOK** | — |

Sonuçlar:

- **MP3 için LAME zorunlu.** iOS bir MP3 **çözücüsü** taşıyor ama
  **kodlayıcısı** yok; `AVAssetExportSession`'ın MP3 hazır ayarı da yok.
  Uygulamanın tek gerçek üçüncü taraf bağımlılığının sebebi bu tek satır.
- **ALAC hazır bir kazanç.** Kodlayıcı çalışıyor, WAV'ın ~%21'i boyutunda ve
  kayıpsız. Ürüne eklenmedi — ayrı bir karar.
- **FLAC ve Opus yazılamıyor**, çünkü iOS'un `.caf`'ı bu kodlayıcıları kabul
  etmiyor. Kodlayıcı kimliği (`kAudioFormatFLAC`) var olması bir şey ifade
  etmiyor; `canApply(outputSettings:forMediaType:)` yanıtı ediyor.

### Bir uyarı: `AVAssetWriter` ObjC exception atıyor

Desteklenmeyen bir kapsayıcı verilince `AVAssetWriter(outputURL:fileType:)`
Swift'te **yakalanamayan** bir Objective-C exception atıyor ve test sürecini
öldürüyor. Ölçüm bu yüzden önce `canApply(outputSettings:forMediaType:)`
soruyor. Bu, ölçümü yazarken süreç çökmesiyle öğrenildi.

---

## Yeniden üretmek

```sh
# 1. Örnekleri üret (ana makinede ffmpeg gerekiyor)
#    24 kapsayıcı, her biri 2 sn, toplam ~2 MB — komutlar git geçmişinde.

# 2. Simülatöre kopyala
xcrun simctl boot 'iPhone 16'
xcrun simctl install booted <derived>/mp3_converter.app
C=$(xcrun simctl get_app_container booted net.yaysoft.mp3-converter data)
mkdir -p "$C/Documents/fmt" && cp fmt/* "$C/Documents/fmt/"

# 3. Ölçümü koştur
xcodebuild test -scheme "MP3 Converter" \
  -only-testing:mp3_converterTests/FormatSupportTests \
  -only-testing:mp3_converterTests/OutputFormatSupportTests
```

`fmt` klasörü boşsa ölçüm sessizce atlanır, yani CI'da kırılmaz. Kalıcı
regresyon koruması ayrı bir yerde: `mp3_converterTests/FallbackTests.swift`
dört kapsayıcıyı depoya konmuş örneklerle her koşuda sınıyor.

---

## Ölçüm tarihi

2026-09-19 · FFmpeg 7.1.1 · iPhone 16 simülatörü, iOS 26 · Xcode 26.4
