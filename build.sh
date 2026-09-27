#!/bin/bash
set -euo pipefail

APP_NAME="DumpViewer"
BUNDLE_ID="com.local.dumpviewer"
VERSION="1.0"
MIN_IOS="16.0"
OUT="build"

echo "==> 清理"
rm -rf "$OUT"
mkdir -p "$OUT/Payload/${APP_NAME}.app"

# 不管文件是平铺在根目录，还是放在 Sources/ Tools/ 子目录里，都能找到
SRC_FILES=$(find . -name '*.swift' -not -name 'make-icon.swift' -not -path './build/*' | sort)
ICON_FILE=$(find . -name 'make-icon.swift' -not -path './build/*' | head -1)
PLIST_SRC=$(find . -maxdepth 2 -name 'Info.plist' -not -path './build/*' | head -1)

if [ -z "$SRC_FILES" ]; then
  echo "!! 找不到 .swift 源文件，检查一下文件传全了没"
  exit 1
fi
echo "找到源文件："
echo "$SRC_FILES"
echo ""

echo "==> 生成图标"
if [ -n "$ICON_FILE" ]; then
  swift "$ICON_FILE" || echo "!! 图标生成失败，跳过继续"
else
  echo "!! 没找到 make-icon.swift，跳过图标"
fi

echo "==> 编译 Swift"
SDK_PATH=$(xcrun --sdk iphoneos --show-sdk-path)
# shellcheck disable=SC2086
xcrun --sdk iphoneos swiftc \
  -sdk "$SDK_PATH" \
  -target arm64-apple-ios${MIN_IOS} \
  -swift-version 5 \
  -O \
  -parse-as-library \
  $SRC_FILES \
  -o "$OUT/Payload/${APP_NAME}.app/${APP_NAME}"

echo "==> 编译图标资源"
if [ -d Assets.xcassets ]; then
  xcrun actool Assets.xcassets \
    --compile "$OUT/Payload/${APP_NAME}.app" \
    --platform iphoneos \
    --minimum-deployment-target "$MIN_IOS" \
    --app-icon AppIcon \
    --output-partial-info-plist "$OUT/asset-info.plist" \
    --target-device iphone \
    > /dev/null || echo "!! actool 警告（不影响）"
else
  echo "!! 没有 Assets.xcassets，跳过图标资源"
fi

echo "==> 写入 Info.plist"
cp "${PLIST_SRC:-Info.plist}" "$OUT/Payload/${APP_NAME}.app/Info.plist"
PLIST="$OUT/Payload/${APP_NAME}.app/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier ${BUNDLE_ID}" "$PLIST"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${VERSION}" "$PLIST"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${VERSION}" "$PLIST"
if [ -f "$OUT/asset-info.plist" ]; then
  /usr/libexec/PlistBuddy -c "Merge $OUT/asset-info.plist" "$PLIST" || true
fi

echo "==> 签名（ad-hoc）"
codesign --force --sign - "$OUT/Payload/${APP_NAME}.app"

echo "==> 打包 ipa"
( cd "$OUT" && zip -qry "${APP_NAME}.ipa" Payload )

echo ""
echo "完成 -> $OUT/${APP_NAME}.ipa"
ls -lh "$OUT/${APP_NAME}.ipa"