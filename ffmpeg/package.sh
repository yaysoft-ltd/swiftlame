#!/bin/bash
#
# Derlenen dylib'leri xcframework'e paketler.
#
# Neden çerçeve: iOS'ta gömülü dinamik kütüphaneler Frameworks/ altında ve
# imzalı olmak zorunda. Ayrıca install_name'ler mutlak derleme yolu olarak
# çıkıyor; @rpath'e çevrilmezse uygulama çalışma anında kütüphaneyi bulamaz.
#
# Dinamik kalıyorlar çünkü LGPL §6 kullanıcıya kendi FFmpeg derlemesiyle
# değiştirip yeniden bağlama hakkı veriyor — SwiftLAME'deki gerekçenin aynısı.

set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
WORK="${FFMPEG_WORK:-/tmp/ffmpeg-build}"
OUT="$ROOT/mp3_converter/Packages/FFDecode/Frameworks"
LIBS="avutil swresample avcodec avformat"

# dylib dosya adı → çerçeve adı eşlemesi
declare -a SLOTS=("ios-arm64:iphoneos" "iossim-arm64:iphonesimulator")

make_framework() {
  local slot="$1" lib="$2"
  local src="$WORK/build/$slot/lib"
  local fw="$WORK/frameworks/$slot/$lib.framework"
  local real; real="$(cd "$src" && ls lib$lib.*.dylib | grep -E "lib$lib\.[0-9]+\.[0-9]+" | head -1)"
  [ -z "$real" ] && real="$(cd "$src" && ls lib$lib.*.dylib | head -1)"

  # Çerçeve YALNIZ ikili taşıyor. Başlıklar bilerek dışarıda: FFmpeg başlıkları
  # birbirine `#include "libavutil/x.h"` diye, include köküne göreli atıf
  # yapıyor. `.framework/Headers/` düz bir klasör olduğu için o yapıyı oraya
  # kopyalamak 127 başlığın çapraz include'unu kırardı. Başlıklar SwiftPM'deki
  # CFFmpeg hedefinde, dizin yapısı korunarak duruyor (headers.sh).
  rm -rf "$fw"; mkdir -p "$fw"
  cp "$src/$real" "$fw/$lib"

  # Kendi kimliği ve bağımlılıkları @rpath'e
  install_name_tool -id "@rpath/$lib.framework/$lib" "$fw/$lib"
  for dep in $LIBS; do
    local depreal
    depreal="$(cd "$src" && ls lib$dep.*.dylib 2>/dev/null | grep -E "lib$dep\.[0-9]+\.dylib" | head -1)" || true
    [ -z "${depreal:-}" ] && continue
    install_name_tool -change "$src/$depreal" "@rpath/$dep.framework/$dep" "$fw/$lib" 2>/dev/null || true
  done

  cat > "$fw/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>org.ffmpeg.$lib</string>
  <key>CFBundleName</key><string>$lib</string>
  <key>CFBundleExecutable</key><string>$lib</string>
  <key>CFBundlePackageType</key><string>FMWK</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>CFBundleShortVersionString</key><string>7.1.1</string>
  <key>MinimumOSVersion</key><string>18.0</string>
</dict></plist>
PLIST

}

echo "→ çerçeveler kuruluyor"
for slot in "${SLOTS[@]}"; do
  s="${slot%%:*}"
  for lib in $LIBS; do make_framework "$s" "$lib"; done
done

echo "→ xcframework'ler"
mkdir -p "$OUT"
for lib in $LIBS; do
  rm -rf "$OUT/$lib.xcframework"
  xcodebuild -create-xcframework \
    -framework "$WORK/frameworks/ios-arm64/$lib.framework" \
    -framework "$WORK/frameworks/iossim-arm64/$lib.framework" \
    -output "$OUT/$lib.xcframework" >/dev/null
  printf "  %-14s %s\n" "$lib.xcframework" "$(du -sh "$OUT/$lib.xcframework" | cut -f1)"
done
echo "→ $OUT"

# Başlıklar: dizin yapısı korunarak C hedefine. Cihaz ve simülatör dilimlerinin
# başlıkları aynı (aynı configure), o yüzden biri yeterli.
echo "→ başlıklar"
HDR="$ROOT/mp3_converter/Packages/FFDecode/Sources/CFFmpeg/include"
rm -rf "$HDR"/libav* "$HDR"/libsw*
mkdir -p "$HDR"
for lib in $LIBS; do
  cp -R "$WORK/build/ios-arm64/include/lib$lib" "$HDR/"
done
printf "  %s başlık → %s\n" "$(find "$HDR" -name '*.h' | wc -l | tr -d ' ')" "${HDR#$ROOT/}"
