#!/bin/zsh
set -e
cd "${0:A:h}"
DEVICE_ID=$(xcrun simctl list devices available -j | /usr/bin/python3 -c 'import json,sys; d=json.load(sys.stdin); a=[v for group in d["devices"].values() for v in group if v.get("isAvailable") and "iPhone" in v["name"]]; print(next((v["udid"] for v in a if v["state"]=="Booted"), a[0]["udid"] if a else ""))')
if [[ -z "$DEVICE_ID" ]]; then
  print '尚无可用的 iPhone 模拟器。请在 Xcode → Settings → Components 中安装 iOS Simulator 并创建 iPhone。'
  open IELTS100.xcodeproj
  exit 1
fi
xcodebuild -quiet -project IELTS100.xcodeproj -scheme IELTS100 -destination "id=$DEVICE_ID" -derivedDataPath build CODE_SIGNING_ALLOWED=NO build
xcrun simctl boot "$DEVICE_ID" 2>/dev/null || true
DEV_DIR=$(xcode-select -p)
if [[ -d "$DEV_DIR/Applications/Simulator.app" ]]; then
  open -a "$DEV_DIR/Applications/Simulator.app" --args -CurrentDeviceUDID "$DEVICE_ID"
else
  open -a "${DEV_DIR:h}/Applications/DeviceHub.app"
fi
xcrun simctl install "$DEVICE_ID" build/Build/Products/Debug-iphonesimulator/IELTS100.app
APP_ID=$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' build/Build/Products/Debug-iphonesimulator/IELTS100.app/Info.plist)
xcrun simctl launch --terminate-running-process "$DEVICE_ID" "$APP_ID"
