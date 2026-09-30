#!/bin/bash
#
# FFmpeg — yalnız iOS'un çözemediği kapsayıcılar için, yalnız KOD ÇÖZME.
#
# Neden var: ölçtük, iOS AVFoundation MKV, WebM, AVI, WMV, FLV, MPG ve TS
# dosyalarını açamıyor (tools/ffmpeg/MEASURED.md). Rakiplerin "21 biçim"
# iddiasının arkasında da bu var.
#
# Kapsam bilerek dar tutuldu, üç sebeple:
#
#   1. LİSANS. `--disable-gpl` ve `--disable-nonfree`: yalnız LGPL-2.1.
#      GPL bileşenler (x264, x265) uygulamanın tamamını GPL'e sokardı.
#      Kodlama FFmpeg'e hiç verilmiyor — MP3'ü LAME, AAC/ALAC/PCM'i
#      AVFoundation yazmaya devam ediyor. FFmpeg yalnız PCM'e çözüyor.
#
#   2. BOYUT. Her şey kapalı başlanıp yalnız gereken demuxer/decoder
#      açılıyor. `--enable-small` ve ölü kod eleme ile ölçülen boyut
#      MEASURED.md'de.
#
#   3. PATENT. AC-3, DTS, E-AC-3 gibi patent yükü olan çözücüler
#      açılmıyor. Bu formatlar bizim hedefimizde de değil.
#
# LGPL §6: kütüphaneler **dinamik** derleniyor (`--enable-shared`), böylece
# kullanıcı kendi FFmpeg derlemesiyle değiştirip yeniden bağlayabiliyor.
# SwiftLAME'de kurduğumuz düzenin aynısı.
#
# Kullanım:  sh tools/ffmpeg/build.sh
# Çıktı:     mp3_converter/Packages/FFDecode/Frameworks/*.xcframework

set -euo pipefail

FFMPEG_VERSION="7.1.1"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
WORK="${FFMPEG_WORK:-/tmp/ffmpeg-build}"
OUT="$ROOT/mp3_converter/Packages/FFDecode/Frameworks"
MIN_IOS="18.0"

# Yalnız iOS'un beceremediği kapsayıcılar. mp4/mov/m4a/mp3/wav zaten
# AVFoundation'da çalışıyor; onları buraya koymak boyutu boşa şişirirdi.
DEMUXERS="matroska,avi,asf,flv,mpegps,mpegts,ogg"
# O kapsayıcıların içinden çıkan ses akışları.
# mp2: ÖLÇÜLDÜ. MPEG program akışı (.mpg/.vob) ve çoğu yayın .ts dosyası
# sesini MP2 taşıyor. İlk derlemede atlanmıştı ve .mpg dosyaları FFmpeg'e
# düştüğü hâlde "unsupportedCodec(mp2)" ile geri dönüyordu — yani yedek yol
# tam da en çok gerektiği yerde çalışmıyordu.
DECODERS="vorbis,opus,wmav1,wmav2,wmapro,wmalossless,mp3,mp3float,mp2,mp2float,aac,aac_latm,flac,\
pcm_s16le,pcm_s16be,pcm_u8,pcm_s24le,pcm_s32le,pcm_f32le,pcm_alaw,pcm_mulaw,\
adpcm_ima_wav,adpcm_ms,nellymoser,speex"
PARSERS="vorbis,opus,mpegaudio,aac,flac"   # mpegaudio zaten MP1/2/3 katmanlarını ayrıştırıyor
PROTOCOLS="file"

echo "FFmpeg $FFMPEG_VERSION · yalnız kod çözme · LGPL-2.1"
mkdir -p "$WORK" && cd "$WORK"

if [ ! -d "ffmpeg-$FFMPEG_VERSION" ]; then
  echo "→ kaynak indiriliyor"
  curl -fsSL "https://ffmpeg.org/releases/ffmpeg-$FFMPEG_VERSION.tar.xz" -o src.tar.xz
  tar xf src.tar.xz
fi

build_arch() {
  local platform="$1" arch="$2" sdk="$3" extra="$4"
  local prefix="$WORK/build/$platform-$arch"
  [ -f "$prefix/lib/libavformat.dylib" ] && { echo "→ $platform/$arch hazır, atlanıyor"; return; }

  echo "→ $platform/$arch derleniyor"
  local sysroot; sysroot="$(xcrun --sdk "$sdk" --show-sdk-path)"
  rm -rf "$WORK/obj-$platform-$arch"
  cp -R "ffmpeg-$FFMPEG_VERSION" "$WORK/obj-$platform-$arch"
  cd "$WORK/obj-$platform-$arch"

  ./configure \
    --prefix="$prefix" \
    --enable-cross-compile --target-os=darwin --arch="$arch" \
    --cc="$(xcrun -f clang)" \
    --sysroot="$sysroot" \
    --extra-cflags="-arch $arch -isysroot $sysroot $extra -fembed-bitcode-marker -Os" \
    --extra-ldflags="-arch $arch -isysroot $sysroot $extra" \
    --enable-shared --disable-static \
    --disable-gpl --disable-nonfree --disable-version3 \
    --disable-programs --disable-doc --disable-avdevice --disable-swscale \
    --disable-postproc --disable-avfilter --disable-network --disable-iconv \
    --disable-sdl2 --disable-securetransport --disable-videotoolbox \
    --disable-audiotoolbox --disable-coreimage --disable-appkit \
    --disable-everything --enable-small \
    --enable-demuxer="$DEMUXERS" \
    --enable-decoder="$DECODERS" \
    --enable-parser="$PARSERS" \
    --enable-protocol="$PROTOCOLS" \
    --enable-swresample \
    --enable-pic \
    >"$WORK/configure-$platform-$arch.log" 2>&1 || {
      echo "configure başarısız — $WORK/configure-$platform-$arch.log"
      tail -25 "$WORK/configure-$platform-$arch.log"; exit 1; }

  make -j"$(sysctl -n hw.ncpu)" >"$WORK/make-$platform-$arch.log" 2>&1 || {
    echo "make başarısız — $WORK/make-$platform-$arch.log"
    tail -25 "$WORK/make-$platform-$arch.log"; exit 1; }
  make install >>"$WORK/make-$platform-$arch.log" 2>&1
  cd "$WORK"
}

build_arch "ios"    "arm64" "iphoneos"       "-mios-version-min=$MIN_IOS"
build_arch "iossim" "arm64" "iphonesimulator" "-mios-simulator-version-min=$MIN_IOS"

echo "→ boyutlar"
for d in "$WORK"/build/*/lib; do
  printf "  %-24s %s\n" "$(basename "$(dirname "$d")")" \
    "$(du -sh "$d" 2>/dev/null | cut -f1)"
done
echo
echo "Kütüphane başına (ios/arm64):"
ls -l "$WORK/build/ios-arm64/lib"/*.dylib 2>/dev/null | awk '{printf "  %-26s %6.2f MB\n", $9, $5/1048576}' | sed 's|.*/lib/||'
