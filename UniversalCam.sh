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
INSTALL_DIR="/usr/lib/enigma2/python/Plugins/Extensions"

PLUGIN_URL="https://raw.githubusercontent.com/Ham-ahmed/Universal/refs/heads/main/UniversalCamConfig.tar.gz"

# === Functions ===
find_plugin_directory() {
    local search_dir="$1"
    local found_dir=""
    
    echo "    Searching for plugin directory in: $search_dir"
    
    # قائمة بأنماط البحث المختلفة للمجلد
    local search_patterns=(
        "$PLUGIN_NAME"
        "*Universal*Cam*Config*"
        "*Universal*"
        "*Cam*Config*"
        "plugin"
        "extensions"
    )
    
    # البحث أولاً عن هيكل إنيغما 2 القياسي
    found_dir=$(find "$search_dir" -type d -path "*/usr/lib/enigma2/python/Plugins/Extensions/*" 2>/dev/null | head -1)
    if [ -n "$found_dir" ]; then
        echo "    Found Enigma2 plugin structure at: $found_dir"
        # العودة إلى دليل المكون الإضافي نفسه
        found_dir=$(dirname "$found_dir" 2>/dev/null | head -1)
    fi
    
    # إذا لم نجد الهيكل القياسي، نبحث بأنماط مختلفة
    if [ -z "$found_dir" ]; then
        for pattern in "${search_patterns[@]}"; do
            found_dir=$(find "$search_dir" -type d -name "$pattern" 2>/dev/null | head -1)
            if [ -n "$found_dir" ]; then
                echo "    Found directory with pattern '$pattern': $found_dir"
                break
            fi
        done
    fi
    
    # البحث عن أي دليل يحتوي على ملف plugin.py (معيار إنيغما 2)
    if [ -z "$found_dir" ]; then
        found_dir=$(find "$search_dir" -type f -name "plugin.py" 2>/dev/null | head -1)
        if [ -n "$found_dir" ]; then
            found_dir=$(dirname "$found_dir")
            echo "    Found plugin.py at: $found_dir"
        fi
    fi
    
    # إذا لم نجد بعد، نبحث عن أي دليل يحتوي على ملف __init__.py
    if [ -z "$found_dir" ]; then
        found_dir=$(find "$search_dir" -type f -name "__init__.py" 2>/dev/null | head -1)
        if [ -n "$found_dir" ]; then
            found_dir=$(dirname "$found_dir")
            echo "    Found __init__.py at: $found_dir"
        fi
    fi
    
    # إذا لم نجد أي شيء، نستخدم دليل البحث نفسه
    if [ -z "$found_dir" ]; then
        echo "    No specific plugin directory found, using extraction directory"
        found_dir="$search_dir"
    fi
    
    echo "$found_dir"
}

validate_plugin_directory() {
    local dir="$1"
    
    # التحقق من وجود الملفات الأساسية للمكون الإضافي
    if [ ! -d "$dir" ]; then
        echo "    ❌ Directory does not exist: $dir"
        return 1
    fi
    
    # التحقق من وجود ملفات Python الأساسية
    local has_python_files=$(find "$dir" -name "*.py" 2>/dev/null | head -1)
    if [ -z "$has_python_files" ]; then
        echo "    ⚠️  No Python files found in directory, might not be a valid plugin"
        # نستمر رغم ذلك، قد تكون هناك ملفات أخرى
    fi
    
    # التحقق من وجود ملف plugin.py أو __init__.py
    if [ -f "$dir/plugin.py" ] || [ -f "$dir/__init__.py" ]; then
        echo "    ✅ Valid plugin directory structure detected"
        return 0
    else
        echo "    ⚠️  Missing standard plugin files (plugin.py or __init__.py)"
        # نستمر رغم ذلك، قد يكون المكون الإضافي له هيكل مختلف
        return 0
    fi
}

# === Step 1: Download ===
echo "[1/4] 📥 Downloading plugin package..."
echo "    Source: $PLUGIN_URL"
cd /tmp || { echo "❌ Cannot change directory to /tmp. Aborting."; exit 1; }

# حذف أي ملفات قديمة
rm -f "$ZIP_PATH" 2>/dev/null
rm -rf "/tmp/UniversalCamConfig" 2>/dev/null
rm -rf "/tmp/plugin_extract" 2>/dev/null

# تحميل الملف
wget -q --show-progress "$PLUGIN_URL" -O "$ZIP_PATH"
if [ $? -ne 0 ]; then
    echo "❌ Failed to download the plugin. Please check your connection or URL."
    exit 1
fi

# التحقق من أن الملف المحمل موجود وغير فارغ
if [ ! -s "$ZIP_PATH" ]; then
    echo "❌ Downloaded file is empty. Please check the URL."
    exit 1
fi

echo "    ✅ Download completed: $(ls -lh "$ZIP_PATH" | awk '{print $5}')"

# === Step 2: Extract & Install ===
echo "[2/4] 📦 Extracting files and installing..."

# إنشاء دليل استخراج مخصص
EXTRACT_DIR="/tmp/plugin_extract_$$"
mkdir -p "$EXTRACT_DIR"

# استخراج الملفات مع عرض التقدم
echo "    Extracting files..."
tar -xzf "$ZIP_PATH" -C "$EXTRACT_DIR" 2>&1 | while read line; do
    echo -n "." >&2
done
echo ""

if [ $? -ne 0 ]; then
    echo "❌ Extraction failed. The file may be corrupted or not a valid tar.gz archive."
    echo "    Trying alternative extraction method..."
    
    # محاولة باستخدام gunzip ثم tar
    if command -v gunzip >/dev/null 2>&1; then
        mkdir -p "/tmp/alt_extract"
        gunzip -c "$ZIP_PATH" | tar -x -C "/tmp/alt_extract" 2>/dev/null
        if [ $? -eq 0 ]; then
            mv "/tmp/alt_extract" "$EXTRACT_DIR"
            rm -rf "/tmp/alt_extract" 2>/dev/null
        else
            echo "❌ Alternative extraction also failed."
            exit 1
        fi
    else
        exit 1
    fi
fi

echo "    Extraction completed"

# البحث عن دليل المكون الإضافي
echo "    Looking for plugin directory..."
PLUGIN_SOURCE_DIR=$(find_plugin_directory "$EXTRACT_DIR")

# التحقق من صحة دليل المكون الإضافي
if ! validate_plugin_directory "$PLUGIN_SOURCE_DIR"; then
    echo "    ⚠️  Plugin directory validation warning, but continuing..."
fi

echo "    Plugin source directory: $PLUGIN_SOURCE_DIR"

# عرض محتويات الدليل
echo "    Contents of source directory:"
ls -la "$PLUGIN_SOURCE_DIR/" 2>/dev/null | head -10

# إنشاء مجلد التثبيت إذا لم يكن موجوداً
mkdir -p "$INSTALL_DIR"

# حذف التثبيت القديم إن وجد
rm -rf "$INSTALL_DIR/$PLUGIN_NAME"

# نسخ الملفات مع التحقق
echo "    Copying files to: $INSTALL_DIR/$PLUGIN_NAME"

# نسخ الملفات مع الحفاظ على الصلاحيات
cp -rf "$PLUGIN_SOURCE_DIR" "$INSTALL_DIR/$PLUGIN_NAME" 2>/dev/null || {
    echo "    ❌ Initial copy failed, trying alternative method..."
    
    # محاولة بديلة: إنشاء الدليل أولاً ثم نسخ المحتويات
    mkdir -p "$INSTALL_DIR/$PLUGIN_NAME"
    cp -rf "$PLUGIN_SOURCE_DIR"/* "$INSTALL_DIR/$PLUGIN_NAME/" 2>/dev/null || {
        echo "❌ Failed to copy plugin files."
        echo "    Please check if you have write permissions to: $INSTALL_DIR"
        
        # محاولة باستخدام rsync إذا كان متوفراً
        if command -v rsync >/dev/null 2>&1; then
            echo "    Trying with rsync..."
            rsync -av "$PLUGIN_SOURCE_DIR/" "$INSTALL_DIR/$PLUGIN_NAME/" 2>/dev/null || {
                echo "❌ rsync also failed."
                
                # محاولة أخيرة مع tar
                cd "$PLUGIN_SOURCE_DIR" && tar cf - . | (cd "$INSTALL_DIR/$PLUGIN_NAME" && tar xf -) 2>/dev/null
                if [ $? -ne 0 ]; then
                    echo "❌ All copy methods failed."
                    exit 1
                fi
            }
        else
            # استخدام tar مباشرة
            cd "$PLUGIN_SOURCE_DIR" && tar cf - . | (cd "$INSTALL_DIR/$PLUGIN_NAME" && tar xf -) 2>/dev/null
            if [ $? -ne 0 ]; then
                echo "❌ tar copy method failed."
                exit 1
            fi
        fi
    }
}

# التأكد من أن الملفات قد نسخت بنجاح
if [ ! -d "$INSTALL_DIR/$PLUGIN_NAME" ]; then
    echo "❌ Plugin was not copied successfully."
    
    # البحث عن أي دليل جديد في مجلد التثبيت
    echo "    Looking for any new directories in $INSTALL_DIR..."
    NEW_DIRS=$(find "$INSTALL_DIR" -type d -mmin -1 2>/dev/null)
    if [ -n "$NEW_DIRS" ]; then
        echo "    Found recently modified directories:"
        echo "$NEW_DIRS"
        # استخدام أول دليل جديد
        NEW_DIR=$(echo "$NEW_DIRS" | head -1)
        echo "    Using directory: $NEW_DIR"
        mv "$NEW_DIR" "$INSTALL_DIR/$PLUGIN_NAME"
    else
        exit 1
    fi
fi

# التحقق من وجود بعض الملفات بعد النسخ
if [ -f "$INSTALL_DIR/$PLUGIN_NAME/plugin.py" ] || [ -f "$INSTALL_DIR/$PLUGIN_NAME/__init__.py" ]; then
    echo "    ✅ Plugin files verified"
else
    echo "    ⚠️  Warning: Standard plugin files not found, but continuing..."
fi

# === Step 3: Set Permissions ===
echo "[3/4] 🔧 Setting permissions..."
chmod -R 755 "$INSTALL_DIR/$PLUGIN_NAME"
chown -R root:root "$INSTALL_DIR/$PLUGIN_NAME" 2>/dev/null || {
    echo "    ⚠️  Could not change ownership (might be running as non-root)"
}

# === Step 4: Cleanup ===
echo "[4/4] 🧹 Cleaning up..."
rm -rf "$EXTRACT_DIR" 2>/dev/null
rm -rf "/tmp/UniversalCamConfig" 2>/dev/null
rm -rf "/tmp/plugin_extract" 2>/dev/null
rm -rf "/tmp/alt_extract" 2>/dev/null
rm -f "$ZIP_PATH" 2>/dev/null

# === Final Message ===
echo ""
echo "✅ Installation complete!"
echo ""
echo "The plugin \"Universal Cam Config\" (v$PLUGIN_VERSION) has been installed successfully."
echo "Location: $INSTALL_DIR/$PLUGIN_NAME"
echo ""
echo "Files installed:"
find "$INSTALL_DIR/$PLUGIN_NAME" -type f 2>/dev/null | wc -l | xargs echo "    Total files:"
echo ""

# عرض بعض الملفات المهمة إذا وجدت
if [ -f "$INSTALL_DIR/$PLUGIN_NAME/plugin.py" ]; then
    echo "    ✓ plugin.py found"
fi
if [ -f "$INSTALL_DIR/$PLUGIN_NAME/__init__.py" ]; then
    echo "    ✓ __init__.py found"
fi

# === Restart info ===
echo ""
echo "#########################################################"
echo "#           Plugin Installation Complete               #"
echo "#########################################################"
echo ""
echo "The plugin has been installed. To use it, you need to:"
echo "1. Restart Enigma2"
echo "2. Find the plugin in the Extensions menu"
echo ""

read -p "Do you want to restart Enigma2 now? (y/n): " -t 30 -n 1 RESTART
echo ""

if [ "$RESTART" = "y" ] || [ "$RESTART" = "Y" ]; then
    echo "Restarting Enigma2 in 5 seconds..."
    sleep 5
    
    # محاولة إعادة التشغيل بطريقة أنظف
    echo "Stopping Enigma2..."
    
    if [ -f /etc/init.d/enigma2 ]; then
        /etc/init.d/enigma2 restart
    elif command -v systemctl >/dev/null 2>&1 && systemctl list-units | grep -q enigma2; then
        systemctl restart enigma2
    else
        killall -9 enigma2 2>/dev/null
        sleep 3
        /usr/bin/enigma2.sh >/dev/null 2>&1 &
    fi
    
    echo "Enigma2 restart initiated."
else
    echo ""
    echo "⚠️  Please restart Enigma2 manually to use the plugin."
    echo ""
    echo "You can restart using one of these methods:"
    echo "1. Menu → Standby/Restart → Restart"
    echo "2. Telnet command: init 4 && sleep 2 && init 3"
    echo "3. SSH command: killall -9 enigma2 && sleep 3 && /usr/bin/enigma2.sh &"
    echo ""
fi

exit 0