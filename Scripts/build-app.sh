#!/bin/zsh
set -euo pipefail

script_dir=${0:A:h}
project_root=${script_dir:h}
app_dir="$project_root/dist/Quota Grove.app"
iconset_dir="$project_root/.build/QuotaGrove.iconset"
master_icon="$project_root/.build/QuotaGrove-1024.png"

cd "$project_root"
swift build -c release

if [[ -d "$app_dir" ]]; then
  rm -rf "$app_dir"
fi
mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
cp "$project_root/.build/release/QuotaGrove" "$app_dir/Contents/MacOS/QuotaGrove"
cp "$project_root/Support/Info.plist" "$app_dir/Contents/Info.plist"
cp "$project_root/Assets/CodexIcon.png" "$app_dir/Contents/Resources/CodexIcon.png"
mkdir -p "$app_dir/Contents/Resources/Backgrounds"
cp "$project_root"/bg/*.png "$app_dir/Contents/Resources/Backgrounds/"
for background_set in AstralTerrarium CloudseaBeacon MoonlitConservatory AbyssalReverie Chronoforge; do
  mkdir -p "$app_dir/Contents/Resources/BackgroundSets/$background_set"
  cp "$project_root"/Assets/BackgroundSets/$background_set/*.png "$app_dir/Contents/Resources/BackgroundSets/$background_set/"
done
mkdir -p "$app_dir/Contents/Resources/Leaves"
for theme in forest autumn apocalypse wasteland; do
  cp "$project_root"/Assets/Leaves/$theme-*.png "$app_dir/Contents/Resources/Leaves/"
done

rm -rf "$iconset_dir"
mkdir -p "$iconset_dir"
if sips -s format png "$project_root/Assets/QuotaGroveIcon.svg" --out "$master_icon" >/dev/null; then
  for size in 16 32 128 256 512; do
    sips -z "$size" "$size" "$master_icon" --out "$iconset_dir/icon_${size}x${size}.png" >/dev/null
    double_size=$((size * 2))
    sips -z "$double_size" "$double_size" "$master_icon" --out "$iconset_dir/icon_${size}x${size}@2x.png" >/dev/null
  done
  iconutil -c icns "$iconset_dir" -o "$app_dir/Contents/Resources/QuotaGrove.icns"
fi

codesign --force --deep --sign - "$app_dir" >/dev/null
echo "$app_dir"
