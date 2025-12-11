#!/bin/sh

# ------------------------------
#   Universal Cam Config Plugin Installer (Updated)
# ------------------------------

PLUGIN_NAME="UniversalCamConfig"
PLUGIN_VERSION="2.1"

clear
echo ""
echo "┌────────────────────────────────────────────────────┐"
echo "│       Universal Cam Config Plugin Installer        │"
echo "├────────────────────────────────────────────────────┤"
echo "│ This script will install the                       │"
echo "│ Universal Cam Config plugin                        │"
echo "│ on your Enigma2-based receiver.                    │"
echo "│                                                    │"
echo "│ Version   : 2.1                                    │"
echo "│ Developer : H-Ahmed                                │"
echo "└────────────────────────────────────────────────────┘"
echo ""

# === Configuration ===
ZIP_PATH="/tmp/UniversalCamConfig.tar.gz"
EXTRACT_DIR="/tmp/UniversalCamConfig"
INSTALL_DIR="/usr/lib/enigma2/python/Plugins/Extensions"

PLUGIN_URL="https://raw.githubusercontent.com/Ham-ahmed/Universal/refs/heads/main/UniversalCamConfig.tar.gz"

# === Step 1: Download ===
echo "[1/4] 📥 Downloading plugin package from:"
echo "    https://raw.githubusercontent.com/Ham-ahmed/Universal/refs/heads/main/UniversalCamConfig.tar.gz"
cd /tmp || { echo "❌ Cannot change directory to /tmp. Aborting."; exit 1; }
wget -q --show-progress "$PLUGIN_URL" -O "$ZIP_PATH"
if [ $? -ne 0 ]; then
    echo "❌ Failed to download the plugin. Please check your connection or URL."
    exit 1
fi

# === Step 2: Extract & Install ===
echo "[2/4] 📦 Extracting files and installing..."

# إنشاء مجلد الاستخراج
mkdir -p "$EXTRACT_DIR"

# استخراج الملفات
tar -xzf "$ZIP_PATH" -C "$EXTRACT_DIR" 2>/dev/null
if [ $? -ne 0 ]; then
    echo "❌ Extraction failed. The file may be corrupted."
    exit 1
fi

# التحقق من وجود المجلد المستخرج
if [ ! -d "$EXTRACT_DIR/$PLUGIN_NAME" ]; then
    # محاولة البحث عن المجلد داخل الأرشيف
    FOUND_DIR=$(find "$EXTRACT_DIR" -name "$PLUGIN_NAME" -type d | head -1)
    if [ -z "$FOUND_DIR" ]; then
        echo "❌ Plugin directory not found in archive."
        exit 1
    fi
    EXTRACT_DIR="$FOUND_DIR"
fi

# إنشاء مجلد التثبيت إذا لم يكن موجوداً
mkdir -p "$INSTALL_DIR"

# حذف التثبيت القديم إن وجد
rm -rf "$INSTALL_DIR/$PLUGIN_NAME"

# نسخ الملفات
cp -r "$EXTRACT_DIR/$PLUGIN_NAME" "$INSTALL_DIR/"
if [ $? -ne 0 ]; then
    echo "❌ Failed to copy plugin to Enigma2 plugins directory."
    exit 1
fi

# === Step 3: Cleanup ===
echo "[3/4] 🧹 Cleaning up..."
rm -rf "/tmp/UniversalCamConfig" 2>/dev/null
rm -f "$ZIP_PATH" 2>/dev/null

# === Step 4: Set Permissions ===
echo "[4/4] 🔧 Setting permissions..."
chmod -R 755 "$INSTALL_DIR/$PLUGIN_NAME"

# === Final Message ===
echo ""
echo "✅ Installation complete!"
echo ""
echo "The plugin \"Universal Cam Config\" (v2.1) has been installed successfully."
echo "Location: $INSTALL_DIR/$PLUGIN_NAME"
echo ""

# === Restart info ===
echo "#########################################################"
echo "#           Your Device will RESTART Now                #"
echo "#########################################################"
echo ""
echo "Restarting Enigma2 in 3 seconds..."
sleep 3

# إعادة تشغيل Enigma2
killall -9 enigma2 2>/dev/null

exit 0