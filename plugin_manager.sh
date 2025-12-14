#!/bin/sh

# ----------------------------------------------------
#   Universal Cam Config Plugin Installer (Updated)
# ----------------------------------------------------

PLUGIN_NAME="UniversalCamConfig"
PLUGIN_VERSION="2.1"
PLUGIN_URL="https://raw.githubusercontent.com/Ham-ahmed/Universal/main/UniversalCamConfig.tar.gz"

clear
echo ""
echo "#######################################"
echo "  Universal CamConfig Plugin Installer "
echo "#######################################"
echo "    This script will install the       "
echo "    Universal Cam Config plugin        "
echo "  on your Enigma2-based receiver.      "
echo "                                       "
echo "      Version   : 2.1                  "
echo "    Developer : H-Ahmed                "
echo "#######################################"
echo ""

if [ "$(id -u)" != "0" ]; then
    echo " This script must be run as root. Use: sudo $0"
    exit 1
fi

command -v wget >/dev/null 2>&1 || { echo " wget is not installed. Aborting."; exit 1; }
command -v tar >/dev/null 2>&1 || { echo " tar is not installed. Aborting."; exit 1; }

ZIP_PATH="/tmp/UniversalCamConfig.tar.gz"
EXTRACT_BASE_DIR="/tmp"
EXTRACT_DIR="/tmp/UniversalCamConfig"
INSTALL_DIR="/usr/lib/enigma2/python/Plugins/Extensions"
BACKUP_DIR="/tmp/plugin_backup_$(date +%Y%m%d_%H%M%S)"

echo "[1/5]  Downloading plugin package..."
echo "    Source: $PLUGIN_URL"
echo "    Destination: $ZIP_PATH"

cd /tmp || { echo " Cannot change directory to /tmp. Aborting."; exit 1; }

if [ -d "$INSTALL_DIR/$PLUGIN_NAME" ]; then
    echo "      Existing plugin found. Creating backup..."
    mkdir -p "$BACKUP_DIR"
    cp -r "$INSTALL_DIR/$PLUGIN_NAME" "$BACKUP_DIR/" 2>/dev/null
    echo "    Backup created at: $BACKUP_DIR"
fi

for i in 1 2 3; do
    echo "    Download attempt $i/3..."
    wget --no-check-certificate --timeout=30 --tries=3 "$PLUGIN_URL" -O "$ZIP_PATH" 2>&1 | \
    tail -n 1 | grep -o '[0-9]\+%' | while read percent; do
        echo -ne "    Progress: $percent\r"
    done
    
    if [ $? -eq 0 ] && [ -f "$ZIP_PATH" ] && [ $(stat -c%s "$ZIP_PATH" 2>/dev/null || echo 0) -gt 1000 ]; then
        echo "     Download completed successfully."
        break
    else
        echo "     Download attempt $i failed."
        rm -f "$ZIP_PATH" 2>/dev/null
        if [ $i -eq 3 ]; then
            echo " All download attempts failed. Please check your internet connection."
            exit 1
        fi
        sleep 2
    fi
done

if [ ! -f "$ZIP_PATH" ] || [ $(stat -c%s "$ZIP_PATH" 2>/dev/null || echo 0) -lt 1000 ]; then
    echo " Downloaded file is too small or missing. Please check the URL."
    exit 1
fi

echo "[2/5]  Extracting files..."
rm -rf "$EXTRACT_DIR" 2>/dev/null

if ! tar -tzf "$ZIP_PATH" >/dev/null 2>&1; then
    echo " Archive is corrupted or invalid."
    exit 1
fi

tar -xzf "$ZIP_PATH" -C "$EXTRACT_BASE_DIR" 2>&1
if [ $? -ne 0 ]; then
    echo " Extraction failed. The archive may be corrupted."
    exit 1
fi

if [ ! -d "$EXTRACT_DIR" ]; then
    EXTRACT_DIR=$(find "$EXTRACT_BASE_DIR" -maxdepth 2 -type d -name "*$PLUGIN_NAME*" -o -name "*Cam*" -o -name "*Config*" | head -1)
    if [ -z "$EXTRACT_DIR" ]; then
        EXTRACT_DIR="/tmp/${PLUGIN_NAME}_extract"
        rm -rf "$EXTRACT_DIR" 2>/dev/null
        mkdir -p "$EXTRACT_DIR"
        tar -xzf "$ZIP_PATH" -C "$EXTRACT_DIR" 2>&1
        if [ ! -d "$EXTRACT_DIR" ] || [ -z "$(ls -A "$EXTRACT_DIR" 2>/dev/null)" ]; then
            echo " Cannot find plugin files in archive."
            exit 1
        fi
    fi
fi

echo "    Extracted to: $EXTRACT_DIR"

echo "[3/5]  Locating plugin files..."
PLUGIN_CONTENT_DIR=""

possible_paths=(
    "$EXTRACT_DIR/$PLUGIN_NAME"
    "$EXTRACT_DIR/usr/lib/enigma2/python/Plugins/Extensions/$PLUGIN_NAME"
    "$EXTRACT_DIR/Extensions/$PLUGIN_NAME"
    "$EXTRACT_DIR"
)

for path in "${possible_paths[@]}"; do
    if [ -d "$path" ] && [ -f "$path/__init__.py" ] || [ -f "$path/plugin.py" ]; then
        PLUGIN_CONTENT_DIR="$path"
        break
    fi
done

if [ -z "$PLUGIN_CONTENT_DIR" ]; then
    PLUGIN_CONTENT_DIR=$(find "$EXTRACT_DIR" -type f \( -name "plugin.py" -o -name "__init__.py" \) -exec dirname {} \; | head -1)
fi

if [ -z "$PLUGIN_CONTENT_DIR" ]; then
    echo " Cannot locate plugin files in the extracted archive."
    echo "    Archive structure:"
    find "$EXTRACT_DIR" -type f | head -20
    exit 1
fi

echo "    Plugin files found at: $PLUGIN_CONTENT_DIR"

echo "[4/5]  Installing plugin..."

mkdir -p "$INSTALL_DIR"

rm -rf "$INSTALL_DIR/$PLUGIN_NAME" 2>/dev/null

# Copy files
echo "    Copying to: $INSTALL_DIR/$PLUGIN_NAME"
if cp -r "$PLUGIN_CONTENT_DIR" "$INSTALL_DIR/$PLUGIN_NAME" 2>&1; then
    echo "     Files copied successfully."
else
    echo "      cp command failed, trying alternative method..."
    
    (cd "$PLUGIN_CONTENT_DIR" && find . -type f -print | cpio -pdum "$INSTALL_DIR/$PLUGIN_NAME" 2>/dev/null)
    
    if [ $? -ne 0 ] || [ ! -d "$INSTALL_DIR/$PLUGIN_NAME" ]; then
        echo " Failed to copy plugin files."
        exit 1
    fi
fi

if [ ! -d "$INSTALL_DIR/$PLUGIN_NAME" ]; then
    echo " Installation failed. Plugin directory not created."
    exit 1
fi

echo "[5/5]  Setting permissions and cleaning up..."

chmod -R 755 "$INSTALL_DIR/$PLUGIN_NAME"
find "$INSTALL_DIR/$PLUGIN_NAME" -type f -name "*.py" -exec chmod 644 {} \; 2>/dev/null
find "$INSTALL_DIR/$PLUGIN_NAME" -type f -name "*.pyo" -exec chmod 644 {} \; 2>/dev/null
find "$INSTALL_DIR/$PLUGIN_NAME" -type f -name "*.so" -exec chmod 755 {} \; 2>/dev/null

if [ "$(id -u)" -eq 0 ]; then
    chown -R root:root "$INSTALL_DIR/$PLUGIN_NAME" 2>/dev/null
fi

rm -rf "$EXTRACT_DIR" 2>/dev/null
rm -f "$ZIP_PATH" 2>/dev/null

echo "     Permissions set."
echo "     Temporary files cleaned."

echo ""
echo "#######################################"
echo "#        INSTALLATION COMPLETE        #"
echo "#######################################"
echo "#     Plugin: Universal Cam Config    #"
echo "#       Version: $PLUGIN_VERSION      #"
echo "# Location: $INSTALL_DIR/$PLUGIN_NAME #"
echo "#######################################"
echo ""

echo "###################################################################################"
echo "# Files installed: $(find "$INSTALL_DIR/$PLUGIN_NAME" -type f 2>/dev/null | wc -l)#"                        
echo "###################################################################################"
echo ""

echo "###########################################"
echo "#   Plugin installation requires restart  #"
echo "###########################################"
echo ""
echo "Select an option:"
echo "1) Restart Enigma2 now"
echo "2) Restart Enigma2 later"
echo "3) Test plugin without restart (experimental)"
echo ""
read -p "Enter choice [1-3] (default: 1): " -t 30 choice

case "${choice:-1}" in
    1)
        echo ""
        echo " Restarting Enigma2 in 3 seconds..."
        sleep 3
        
        # Try different restart methods
        if [ -f /etc/init.d/enigma2 ]; then
            /etc/init.d/enigma2 restart
        elif [ -f /etc/init.d/rcS ]; then
            killall -9 enigma2 2>/dev/null
            sleep 2
            /usr/bin/enigma2.sh >/dev/null 2>&1 &
        elif command -v systemctl >/dev/null 2>&1; then
            systemctl restart enigma2 2>/dev/null || {
                killall -9 enigma2 2>/dev/null
                sleep 2
                /usr/bin/enigma2.sh >/dev/null 2>&1 &
            }
        else
            killall -9 enigma2 2>/dev/null
            sleep 2
            /usr/bin/enigma2.sh >/dev/null 2>&1 &
        fi
        
        echo "Enigma2 is restarting..."
        ;;
    
    2)
        echo ""
        echo "  Please restart Enigma2 manually to use the plugin."
        echo ""
        echo "Manual restart methods:"
        echo "  - Via receiver menu: Menu → Standby/Restart → Restart"
        echo "  - Via telnet: init 4 && sleep 2 && init 3"
        echo "  - Via command: killall -9 enigma2 && sleep 2 && /usr/bin/enigma2.sh &"
        ;;
    
    3)
        echo ""
        echo "  Experimental: Trying to reload plugins without restart..."
        echo "    This may not work on all receivers."
        
        # Try to reload plugins
        if [ -f /usr/lib/enigma2/python/Components/PluginComponent.py ]; then
            echo "    Attempting plugin reload..."
            python3 -c "
import sys
sys.path.append('/usr/lib/enigma2/python')
try:
    from Plugins.Plugin import PluginDescriptor
    from Components.PluginComponent import plugins
    plugins.clear()
    plugins.readPluginList('/etc/enigma2/plugins')
    print('    Plugin list reloaded. You may need to restart GUI.')
except Exception as e:
    print('    Error:', str(e))
    print('    Full restart is recommended.')
" 2>/dev/null || echo "    Plugin reload failed. Full restart required."
        else
            echo "    Cannot reload plugins automatically."
        fi
        
        echo ""
        echo "  For full functionality, please restart Enigma2."
        ;;
    
    *)
        echo "Invalid choice. No restart initiated."
        ;;
esac

echo ""
echo "######################################"
echo "#   Installation process completed!  #"
echo "######################################"

if [ -d "$BACKUP_DIR" ]; then
    echo ""
    echo " Backup of previous version saved at:"
    echo "   $BACKUP_DIR"
    echo "   To restore: cp -r \"$BACKUP_DIR/$PLUGIN_NAME\" \"$INSTALL_DIR/\""
fi

echo ""
exit 0