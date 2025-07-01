#!/bin/bash

# DMG 创建脚本
APP_NAME="MacEasySymbol"
APP_PATH="./signed-release/MacEasySymbol.app"
DMG_NAME="MacEasySymbol"
TEMP_DIR="./temp_dmg"
DMG_TEMP="temp_${DMG_NAME}.dmg"
DMG_FINAL="${DMG_NAME}.dmg"

# 清理之前的临时文件
rm -rf "$TEMP_DIR"
rm -f "$DMG_TEMP"
rm -f "$DMG_FINAL"

# 创建临时目录
mkdir -p "$TEMP_DIR"

# 复制 app 到临时目录
echo "复制应用程序..."
cp -R "$APP_PATH" "$TEMP_DIR/"

# 创建 Applications 文件夹的符号链接
echo "创建 Applications 链接..."
ln -s /Applications "$TEMP_DIR/Applications"

# 计算需要的大小（app 大小 + 一些余量）
APP_SIZE=$(du -sm "$APP_PATH" | cut -f1)
DMG_SIZE=$((APP_SIZE + 10))

# 创建临时 DMG
echo "创建临时 DMG..."
hdiutil create -srcfolder "$TEMP_DIR" -volname "$APP_NAME" -fs HFS+ \
    -fsargs "-c c=64,a=16,e=16" -format UDRW -size ${DMG_SIZE}m "$DMG_TEMP"

# 挂载临时 DMG
echo "挂载 DMG 进行配置..."
MOUNT_DIR="/Volumes/$APP_NAME"
hdiutil attach "$DMG_TEMP"

# 等待挂载完成
sleep 2

# 设置 Finder 视图选项（通过 AppleScript）
osascript <<EOD
tell application "Finder"
    tell disk "$APP_NAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {400, 100, 880, 420}
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 72
        # 不设置背景图片
        delay 1
        set position of item "$APP_NAME.app" of container window to {120, 120}
        set position of item "Applications" of container window to {360, 120}
        close
        open
        update without registering applications
        delay 2
    end tell
end tell
EOD

# 等待设置完成
sleep 3

# 卸载临时 DMG
echo "卸载临时 DMG..."
hdiutil detach "$MOUNT_DIR"

# 转换为最终的只读 DMG
echo "创建最终 DMG..."
hdiutil convert "$DMG_TEMP" -format UDZO -imagekey zlib-level=9 -o "$DMG_FINAL"

# 清理临时文件
rm -f "$DMG_TEMP"
rm -rf "$TEMP_DIR"

echo "DMG 创建完成: $DMG_FINAL" 