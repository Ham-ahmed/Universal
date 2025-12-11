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
EXTRACT_BASE_DIR="/tmp"
EXTRACT_DIR="/tmp/UniversalCamConfig"
INSTALL_DIR="/usr/lib/enigma2/python/Plugins/Extensions"

PLUGIN_URL="https://raw.githubusercontent.com/Ham-ahmed/Universal/refs/heads/main/UniversalCamConfig.tar.gz"

# === Step 1: Download ===
echo "[1/4] 📥 Downloading plugin package..."
echo "    Source: $PLUGIN_URL"
cd /tmp || { echo "❌ Cannot change directory to /tmp. Aborting."; exit 1; }
wget -q --show-progress "$PLUGIN_URL" -O "$ZIP_PATH"
if [ $? -ne 0 ]; then
    echo "❌ Failed to download the plugin. Please check your connection or URL."
    exit 1
fi

# === Step 2: Extract & Install ===
echo "[2/4] 📦 Extracting files and installing..."

# تنظيف مجلد الاستخراج القديم إن وجد
rm -rf "$EXTRACT_DIR" 2>/dev/null

# استخراج الملفات
tar -xzf "$ZIP_PATH" -C "$EXTRACT_BASE_DIR" 2>/dev/null
if [ $? -ne 0 ]; then
    echo "❌ Extraction failed. The file may be corrupted."
    exit 1
fi

# التحقق من وجود المجلد المستخرج
if [ ! -d "$EXTRACT_DIR" ]; then
    # محاولة البحث عن المجلد المستخرج
    EXTRACT_DIR=$(find "$EXTRACT_BASE_DIR" -name "*UniversalCamConfig*" -type d | head -1)
    if [ -z "$EXTRACT_DIR" ]; then
        echo "❌ Plugin directory not found in archive. Trying alternative method..."
        # إنشاء دليل استخراج جديد ومحاولة استخراج مباشرة
        mkdir -p "/tmp/plugin_extract"
        tar -xzf "$ZIP_PATH" -C "/tmp/plugin_extract" 2>/dev/null
        EXTRACT_DIR=$(find "/tmp/plugin_extract" -name "*UniversalCamConfig*" -type d | head -1)
        if [ -z "$EXTRACT_DIR" ]; then
            echo "❌ Cannot find plugin directory in archive."
            exit 1
        fi
    fi
fi

echo "    Found plugin directory: $EXTRACT_DIR"

# التحقق من هيكل الملفات داخل المجلد
PLUGIN_CONTENT_DIR=""
if [ -d "$EXTRACT_DIR/$PLUGIN_NAME" ]; then
    PLUGIN_CONTENT_DIR="$EXTRACT_DIR/$PLUGIN_NAME"
elif [ -d "$EXTRACT_DIR/usr/lib/enigma2/python/Plugins/Extensions/$PLUGIN_NAME" ]; then
    PLUGIN_CONTENT_DIR="$EXTRACT_DIR/usr/lib/enigma2/python/Plugins/Extensions/$PLUGIN_NAME"
else
    # البحث عن أي دليل باسم المكون الإضافي
    PLUGIN_CONTENT_DIR=$(find "$EXTRACT_DIR" -type d -name "$PLUGIN_NAME" | head -1)
    if [ -z "$PLUGIN_CONTENT_DIR" ]; then
        # إذا لم نجد، نفترض أن EXTRACT_DIR نفسه هو محتوى المكون الإضافي
        PLUGIN_CONTENT_DIR="$EXTRACT_DIR"
    fi
fi

echo "    Plugin content directory: $PLUGIN_CONTENT_DIR"

# إنشاء مجلد التثبيت إذا لم يكن موجوداً
mkdir -p "$INSTALL_DIR"

# حذف التثبيت القديم إن وجد
rm -rf "$INSTALL_DIR/$PLUGIN_NAME"

# نسخ الملفات مع التحقق
echo "    Copying files to: $INSTALL_DIR/$PLUGIN_NAME"
cp -r "$PLUGIN_CONTENT_DIR" "$INSTALL_DIR/" || {
    echo "❌ Failed to copy plugin to Enigma2 plugins directory."
    echo "    Source: $PLUGIN_CONTENT_DIR"
    echo "    Destination: $INSTALL_DIR"
    
    # محاولة بديلة باستخدام rsync إذا كان متوفراً
    if command -v rsync >/dev/null 2>&1; then
        echo "    Trying with rsync..."
        rsync -av "$PLUGIN_CONTENT_DIR/" "$INSTALL_DIR/$PLUGIN_NAME/" || {
            echo "❌ rsync also failed."
            exit 1
        }
    else
        exit 1
    fi
}

# التأكد من أن الملفات قد نسخت بنجاح
if [ ! -d "$INSTALL_DIR/$PLUGIN_NAME" ]; then
    echo "❌ Plugin was not copied successfully. Checking for alternative names..."
    # البحث عن أي دليل تم نسخه حديثاً
    NEW_PLUGIN_DIR=$(find "$INSTALL_DIR" -type d -name "*Universal*" -o -name "*Cam*" -o -name "*Config*" | head -1)
    if [ -n "$NEW_PLUGIN_DIR" ]; then
        echo "    Found alternative directory: $NEW_PLUGIN_DIR"
        echo "    Renaming to proper name..."
        mv "$NEW_PLUGIN_DIR" "$INSTALL_DIR/$PLUGIN_NAME"
    else
        echo "❌ No plugin files found in destination directory."
        exit 1
    fi
fi

# === Step 3: Set Permissions ===
echo "[3/4] 🔧 Setting permissions..."
chmod -R 755 "$INSTALL_DIR/$PLUGIN_NAME"
chown -R root:root "$INSTALL_DIR/$PLUGIN_NAME" 2>/dev/null

# === Step 4: Cleanup ===
echo "[4/4] 🧹 Cleaning up..."
rm -rf "$EXTRACT_DIR" 2>/dev/null
rm -rf "/tmp/plugin_extract" 2>/dev/null
rm -f "$ZIP_PATH" 2>/dev/null

# === Final Message ===
echo ""
echo "✅ Installation complete!"
echo ""
echo "The plugin \"Universal Cam Config\" (v$PLUGIN_VERSION) has been installed successfully."
echo "Location: $INSTALL_DIR/$PLUGIN_NAME"
echo "Files installed:"
find "$INSTALL_DIR/$PLUGIN_NAME" -type f | wc -l | xargs echo "    Total files:"
echo ""

# === Restart info ===
echo "#########################################################"
echo "#           Your Device will RESTART Now                #"
echo "#########################################################"
echo ""
read -p "Do you want to restart Enigma2 now? (y/n): " -t 10 -n 1 RESTART
echo ""

if [ "$RESTART" = "y" ] || [ "$RESTART" = "Y" ]; then
    echo "Restarting Enigma2 in 3 seconds..."
    sleep 3
    
    # محاولة إعادة التشغيل بطريقة أنظف
    if [ -f /etc/init.d/enigma2 ]; then
        /etc/init.d/enigma2 restart
    elif [ -f /etc/init.d/rcS ]; then
        killall -9 enigma2
        sleep 2
        /usr/bin/enigma2.sh &
    else
        killall -9 enigma2
        sleep 2
        systemctl restart enigma2 2>/dev/null || /usr/bin/enigma2.sh &
    fi
else
    echo ""
    echo "⚠️  Please restart Enigma2 manually to use the plugin."
    echo "   You can restart from the device menu or using:"
    echo "   killall -9 enigma2 && sleep 2 && /usr/bin/enigma2.sh &"
    echo ""
fi

exit 0