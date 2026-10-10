#!/bin/zsh
set -euo pipefail

repo_dir=${0:A:h:h}
build_dir="$repo_dir/.build/release"
output_dir="$repo_dir/dist"
app="$output_dir/YouTube Downloader 2.6.1 Beta.app"
zip="$output_dir/YouTube Downloader 2.6.1 Beta.zip"
cache_dir="$repo_dir/.build/downloads"

mkdir -p "$build_dir" "$output_dir" "$cache_dir"
python3 - "$app" "$zip" <<'PY'
from pathlib import Path
import shutil, sys
for raw in sys.argv[1:]:
    path = Path(raw)
    if path.is_dir(): shutil.rmtree(path)
    elif path.exists(): path.unlink()
PY

fetch_verified() {
    local url=$1 destination=$2 expected=$3
    if [[ ! -f "$destination" ]] || [[ "$(shasum -a 256 "$destination" | awk '{print $1}')" != "$expected" ]]; then
        curl --fail --location --retry 3 --output "$destination" "$url"
    fi
    local actual
    actual=$(shasum -a 256 "$destination" | awk '{print $1}')
    [[ "$actual" == "$expected" ]] || { print -u2 "Checksum mismatch for $destination"; return 1; }
}

fetch_verified \
  'https://github.com/yt-dlp/yt-dlp/releases/download/2026.08.19/yt-dlp_macos' \
  "$cache_dir/yt-dlp" \
  '0f192b7ec147ab6288885d6351d9ab67367640029b4377576ef46dd79cf7b202'
fetch_verified \
  'https://ffmpeg.martin-riedl.de/download/macos/arm64/1789931890_9.0.2/ffmpeg.zip' \
  "$cache_dir/ffmpeg.zip" \
  'c8ed4c4e6978a03c485edbfe4e0a5dc2380f8a30bba5150531b31b094492d924'
fetch_verified \
  'https://ffmpeg.martin-riedl.de/download/macos/arm64/1789931890_9.0.2/ffprobe.zip' \
  "$cache_dir/ffprobe.zip" \
  'fcbe839537485eaee7a7a8bc5cbc0f90d53617e80943e8a5b2e31cb851197ea6'

python3 - "$build_dir/ffmpeg" "$build_dir/ffprobe" <<'PY'
from pathlib import Path
import shutil, sys
for raw in sys.argv[1:]:
    path = Path(raw)
    if path.exists(): shutil.rmtree(path)
    path.mkdir(parents=True)
PY
ditto -x -k "$cache_dir/ffmpeg.zip" "$build_dir/ffmpeg"
ditto -x -k "$cache_dir/ffprobe.zip" "$build_dir/ffprobe"

sdk=$(xcrun --sdk macosx --show-sdk-path)
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources/Tools" "$app/Contents/Resources/Licenses"
CLANG_MODULE_CACHE_PATH="$build_dir/clang-cache" \
SWIFTPM_MODULECACHE_OVERRIDE="$build_dir/clang-cache" \
swiftc -swift-version 6 -parse-as-library -target arm64-apple-macosx26.0 -sdk "$sdk" -O \
  "$repo_dir/Sources/YouTubeDownloader.swift" \
  -o "$app/Contents/MacOS/YouTubeDownloader"

cat > "$app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleDisplayName</key><string>YouTube Downloader</string>
<key>CFBundleExecutable</key><string>YouTubeDownloader</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>CFBundleIdentifier</key><string>local.codex.youtube-downloader.app</string>
<key>CFBundleName</key><string>YouTube Downloader</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>2.6.1</string>
<key>CFBundleVersion</key><string>19</string>
<key>LSMinimumSystemVersion</key><string>26.0</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST

cp "$repo_dir/Assets/AppIcon-OrangeCoral.icns" "$app/Contents/Resources/AppIcon.icns"
cp "$cache_dir/yt-dlp" "$app/Contents/Resources/Tools/yt-dlp"
cp "$build_dir/ffmpeg/ffmpeg" "$app/Contents/Resources/Tools/ffmpeg"
cp "$build_dir/ffprobe/ffprobe" "$app/Contents/Resources/Tools/ffprobe"
chmod 755 "$app/Contents/MacOS/YouTubeDownloader" "$app/Contents/Resources/Tools/"*
print '2026.08.19' > "$app/Contents/Resources/Tools/yt-dlp-version.txt"
cp "$repo_dir/ThirdParty/THIRD_PARTY_NOTICES.md" "$app/Contents/Resources/Licenses/"
cp "$repo_dir/ThirdParty/Licenses/"* "$app/Contents/Resources/Licenses/"

# This ad hoc signature is for local testing. Public releases need a Developer ID
# signature, hardened runtime, Apple notarization, and stapling.
codesign --force --deep --sign - "$app"
codesign --verify --deep --strict "$app"
ditto -c -k --sequesterRsrc --keepParent "$app" "$zip"
(
  cd "$output_dir"
  shasum -a 256 "${zip:t}" > SHA256SUMS.txt
)
print "Built $app"
