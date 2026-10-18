#!/bin/zsh
set -e
cd "${0:A:h}"
mkdir -p tools/cache
trap 'print "安装未完成。请查看上方提示，确认手机已连接、解锁，且 Xcode 已登录 Apple 账号。"; read -r "?按回车关闭窗口…"' ZERR

print '正在查找已连接的 iPhone…'
xcrun devicectl list devices --json-output tools/cache/renewal-devices.json >/dev/null
PHONE_ID=$(/usr/bin/python3 - <<'PY'
import json
from pathlib import Path
devices = json.loads(Path('tools/cache/renewal-devices.json').read_text())['result']['devices']
phones = [d for d in devices if d.get('hardwareProperties', {}).get('reality') == 'physical'
          and d['hardwareProperties'].get('deviceType') == 'iPhone'
          and d.get('connectionProperties', {}).get('tunnelState') == 'connected']
if len(phones) != 1:
    raise SystemExit('请只连接一台要安装的 iPhone，并保持解锁。')
print(phones[0]['hardwareProperties']['udid'])
PY
)
print '正在编译并使用你的 Apple 账号签名…'
xcodebuild -quiet -project IELTS100.xcodeproj -scheme IELTS100 -configuration Release \
  -destination "id=$PHONE_ID" -derivedDataPath build-iphone \
  -allowProvisioningUpdates -allowProvisioningDeviceRegistration build
APP_PATH='build-iphone/Build/Products/Release-iphoneos/IELTS100.app'
APP_ID=$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$APP_PATH/Info.plist")
/usr/bin/codesign --verify --strict "$APP_PATH"
print '正在安装「100句」；学习记录会保留。'
xcrun devicectl device install app --device "$PHONE_ID" "$APP_PATH"
if xcrun devicectl device process launch --device "$PHONE_ID" "$APP_ID"; then
  print '安装完成，已打开「100句」。'
else
  print 'App 已安装。若首次打开提示未受信任，请在 iPhone「设置 → 通用 → VPN与设备管理」中信任自己的开发者账号，再打开「100句」。'
fi
read -r '?按回车关闭窗口…'
