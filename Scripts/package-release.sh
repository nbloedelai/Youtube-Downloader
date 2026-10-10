#!/bin/zsh
set -euo pipefail

project_dir=${0:A:h:h}
source_dir="$project_dir/Sources"
assets_dir="$project_dir/Assets"
third_party_dir="$project_dir/ThirdParty"
output_dir="$project_dir/dist"
cache_dir="${TMPDIR:-/tmp}/youtube-downloader-2.6.4-build"
app="$output_dir/YouTube Downloader 2.6.4 Beta.app"
zip="$output_dir/YouTube Downloader 2.6.4 Beta.zip"
dmg="$output_dir/YouTube Downloader 2.6.4 Beta.dmg"
staging="$cache_dir/dmg-staging"
hybrid="$cache_dir/YouTube Downloader 2.6.4 Beta.hfs.dmg"
sdk=$(xcrun --sdk macosx --show-sdk-path)

mkdir -p "$cache_dir" "$output_dir"
python3 - "$app" "$zip" "$dmg" "$staging" "$hybrid" <<'PY'
from pathlib import Path
import shutil, sys
for raw in sys.argv[1:]:
    path = Path(raw)
    if path.is_dir() and not path.is_symlink(): shutil.rmtree(path)
    elif path.exists() or path.is_symlink(): path.unlink()
PY

mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources/Licenses"
CLANG_MODULE_CACHE_PATH="$cache_dir/clang-cache" \
SWIFTPM_MODULECACHE_OVERRIDE="$cache_dir/clang-cache" \
swiftc -swift-version 6 -parse-as-library -target arm64-apple-macosx26.0 -sdk "$sdk" -O \
    "$source_dir/YouTubeDownloader.swift" -o "$app/Contents/MacOS/YouTubeDownloader"

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
<key>CFBundleShortVersionString</key><string>2.6.4</string>
<key>CFBundleVersion</key><string>22</string>
<key>LSMinimumSystemVersion</key><string>26.0</string>
<key>NSHighResolutionCapable</key><true/>
<key>NSHumanReadableCopyright</key><string>Copyright © 2026 Noah Bloedel</string>
</dict></plist>
PLIST

cp "$assets_dir/AppIcon-OrangeCoral.icns" "$app/Contents/Resources/AppIcon.icns"
cp "$third_party_dir/THIRD_PARTY_NOTICES.md" "$app/Contents/Resources/Licenses/THIRD_PARTY_NOTICES.md"
cp "$third_party_dir/Licenses/"* "$app/Contents/Resources/Licenses/"

# Local beta signature. A future public-trust build should replace this with
# Developer ID signing, hardened runtime, notarization, and stapling.
codesign --force --deep --sign - "$app"
codesign --verify --deep --strict "$app"
ditto -c -k --sequesterRsrc --keepParent "$app" "$zip"
unzip -t "$zip" >/dev/null

mkdir -p "$staging/.background"
ditto "$app" "$staging/YouTube Downloader.app"
ln -s /Applications "$staging/Applications"
cp "$assets_dir/installer-background-final.png" "$staging/.background/installer.png"
cp "$assets_dir/DS_Store.template" "$staging/.DS_Store"
/usr/bin/SetFile -a V "$staging/.background" "$staging/.background/installer.png"
hdiutil makehybrid -hfs -hfs-volume-name "YouTube Downloader" -o "$hybrid" "$staging" >/dev/null
hdiutil convert "$hybrid" -format UDZO -o "$dmg" >/dev/null
hdiutil verify "$dmg" >/dev/null

(
    cd "$output_dir"
    shasum -a 256 "${dmg:t}" "${zip:t}" > "SHA256SUMS-2.6.4.txt"
)

echo "Built: $app"
echo "ZIP:   $zip"
echo "DMG:   $dmg"
echo "Tools bundled: none"
