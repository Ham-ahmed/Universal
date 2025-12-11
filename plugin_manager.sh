#!/bin/bash

# سكريبت لإدارة تنزيل وتحديث البلجنات بصيغة tar.gz
# إعداد: [اسمك]
# تاريخ: $(date +%Y-%m-%d)

# الألوان للواجهة
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# المسارات الأساسية
CONFIG_FILE="$HOME/.plugin_manager.conf"
LOG_FILE="$HOME/plugin_manager.log"
BACKUP_DIR="$HOME/plugin_backups"
PLUGINS_DIR=""

# تحميل الإعدادات
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
    else
        # إعدادات افتراضية
        PLUGINS_DIR="$HOME/plugins"
        mkdir -p "$PLUGINS_DIR"
        echo "PLUGINS_DIR=\"$PLUGINS_DIR\"" > "$CONFIG_FILE"
        echo "BACKUP_DIR=\"$BACKUP_DIR\"" >> "$CONFIG_FILE"
        echo "LOG_FILE=\"$LOG_FILE\"" >> "$CONFIG_FILE"
    fi
}

# تسجيل الأحداث
log_message() {
    local message="$1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $message" >> "$LOG_FILE"
    echo -e "${BLUE}[LOG]${NC} $message"
}

# التحقق من المتطلبات
check_dependencies() {
    local dependencies=("wget" "tar")
    local missing=()
    
    for cmd in "${dependencies[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            missing+=("$cmd")
        fi
    done
    
    if [ ${#missing[@]} -gt 0 ]; then
        echo -e "${RED}خطأ:${NC} الأدوات التالية غير مثبتة:"
        for cmd in "${missing[@]}"; do
            echo "  - $cmd"
        done
        echo "يرجى تثبيتها قبل الاستمرار"
        exit 1
    fi
}

# عرض القائمة الرئيسية
show_menu() {
    clear
    echo -e "${GREEN}════════════════════════════════════════${NC}"
    echo -e "${GREEN}     مدير البلجنات - Plugin Manager     ${NC}"
    echo -e "${GREEN}════════════════════════════════════════${NC}"
    echo -e "1. ${YELLOW}تنزيل بلجن جديد${NC}"
    echo -e "2. ${YELLOW}تحديث بلجن موجود${NC}"
    echo -e "3. ${YELLOW}عرض البلجنات المثبتة${NC}"
    echo -e "4. ${YELLOW}نسخة احتياطية للبلجن${NC}"
    echo -e "5. ${YELLOW}استعادة بلجن من النسخة الاحتياطية${NC}"
    echo -e "6. ${YELLOW}ضبط الإعدادات${NC}"
    echo -e "7. ${YELLOW}عرض سجل الأحداث${NC}"
    echo -e "8. ${YELLOW}الخروج${NC}"
    echo -e "${GREEN}════════════════════════════════════════${NC}"
}

# تنزيل بلجن جديد
download_new_plugin() {
    echo -e "${GREEN}── تنزيل بلجن جديد ──${NC}"
    
    read -p "أدخل رابط تنزيل البلجن: " plugin_url
    if [ -z "$plugin_url" ]; then
        echo -e "${RED}خطأ: الرابط فارغ${NC}"
        return 1
    fi
    
    # استخراج اسم الملف من الرابط
    local filename=$(basename "$plugin_url")
    local plugin_name="${filename%.tar.gz}"
    plugin_name="${plugin_name%.tgz}"
    
    echo -e "${YELLOW}جاري تنزيل: $plugin_name${NC}"
    
    # إنشاء مجلد مؤقت
    local temp_dir=$(mktemp -d)
    cd "$temp_dir" || exit 1
    
    # تنزيل الملف
    if wget -q "$plugin_url"; then
        echo -e "${GREEN}تم التنزيل بنجاح${NC}"
        log_message "تم تنزيل $plugin_name من $plugin_url"
    else
        echo -e "${RED}فشل في تنزيل الملف${NC}"
        log_message "فشل في تنزيل $plugin_url"
        rm -rf "$temp_dir"
        return 1
    fi
    
    # فك الضغط
    echo -e "${YELLOW}جاري فك الضغط...${NC}"
    tar -xzf "$filename" 2>/dev/null
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}تم فك الضغط بنجاح${NC}"
    else
        echo -e "${RED}فشل في فك ضغط الملف${NC}"
        rm -rf "$temp_dir"
        return 1
    fi
    
    # البحث عن المجلد الرئيسي للبلجن
    local extracted_dir=$(find . -maxdepth 1 -type d -name "$plugin_name*" | head -1)
    if [ -z "$extracted_dir" ]; then
        extracted_dir=$(find . -maxdepth 1 -type d ! -name "." | head -1)
    fi
    
    if [ -z "$extracted_dir" ]; then
        echo -e "${RED}لم يتم العثور على مجلد البلجن${NC}"
        rm -rf "$temp_dir"
        return 1
    fi
    
    # نقل البلجن إلى المجلد النهائي
    local target_dir="$PLUGINS_DIR/$(basename "$extracted_dir")"
    
    # التحقق إذا كان البلجن موجود مسبقاً
    if [ -d "$target_dir" ]; then
        echo -e "${YELLOW}البلجن موجود مسبقاً. هل تريد استبداله؟${NC}"
        read -p "(y/n): " replace_choice
        if [[ ! "$replace_choice" =~ ^[Yy]$ ]]; then
            echo "تم الإلغاء"
            rm -rf "$temp_dir"
            return 0
        fi
        
        # إنشاء نسخة احتياطية
        backup_plugin "$(basename "$target_dir")"
    fi
    
    # النقل النهائي
    mv "$extracted_dir" "$PLUGINS_DIR/"
    
    echo -e "${GREEN}تم تثبيت البلجن بنجاح في:${NC}"
    echo -e "${BLUE}$PLUGINS_DIR/$(basename "$extracted_dir")${NC}"
    
    # تنظيف الملفات المؤقتة
    rm -rf "$temp_dir"
    
    log_message "تم تثبيت $plugin_name في $PLUGINS_DIR"
    
    # عرض محتويات البلجن
    echo -e "\n${YELLOW}محتويات البلجن:${NC}"
    ls -la "$PLUGINS_DIR/$(basename "$extracted_dir")"
}

# تحديث بلجن موجود
update_existing_plugin() {
    echo -e "${GREEN}── تحديث بلجن موجود ──${NC}"
    
    # عرض البلجنات المثبتة
    list_installed_plugins
    
    if [ ! -d "$PLUGINS_DIR" ] || [ -z "$(ls -A "$PLUGINS_DIR")" ]; then
        echo -e "${RED}لا توجد بلجنات مثبتة${NC}"
        return 1
    fi
    
    read -p "أدخل اسم البلجن الذي تريد تحديثه: " plugin_name
    
    local plugin_path="$PLUGINS_DIR/$plugin_name"
    if [ ! -d "$plugin_path" ]; then
        echo -e "${RED}البلجن غير موجود${NC}"
        return 1
    fi
    
    # طلب رابط التحديث
    read -p "أدخل رابط التحديث (tar.gz) أو اضغط Enter للبحث التلقائي: " update_url
    
    if [ -z "$update_url" ]; then
        # هنا يمكن إضافة منطق للبحث التلقائي عن التحديثات
        echo -e "${YELLOW}ميزة البحث التلقائي تحت التطوير${NC}"
        echo "يرجى إدخال الرابط يدوياً"
        read -p "أدخل رابط التحديث: " update_url
    fi
    
    if [ -z "$update_url" ]; then
        echo -e "${RED}تم الإلغاء${NC}"
        return 1
    fi
    
    # إنشاء نسخة احتياطية قبل التحديث
    backup_plugin "$plugin_name"
    
    # إنشاء مجلد مؤقت
    local temp_dir=$(mktemp -d)
    cd "$temp_dir" || exit 1
    
    echo -e "${YELLOW}جاري تنزيل التحديث...${NC}"
    
    # تنزيل التحديث
    if wget -q "$update_url"; then
        echo -e "${GREEN}تم تنزيل التحديث${NC}"
    else
        echo -e "${RED}فشل في تنزيل التحديث${NC}"
        rm -rf "$temp_dir"
        return 1
    fi
    
    # استخراج اسم الملف
    local filename=$(basename "$update_url")
    
    # فك الضغط
    echo -e "${YELLOW}جاري فك الضغط...${NC}"
    tar -xzf "$filename" 2>/dev/null
    if [ $? -ne 0 ]; then
        echo -e "${RED}فشل في فك ضغط الملف${NC}"
        rm -rf "$temp_dir"
        return 1
    fi
    
    # البحث عن مجلد البلجن المستخرج
    local extracted_dir=$(find . -maxdepth 1 -type d ! -name "." | head -1)
    
    if [ -z "$extracted_dir" ]; then
        echo -e "${RED}لم يتم العثور على مجلد البلجن${NC}"
        rm -rf "$temp_dir"
        return 1
    fi
    
    # حذف البلجن القديم
    echo -e "${YELLOW}جاري تحديث البلجن...${NC}"
    rm -rf "$plugin_path"
    
    # نقل البلجن الجديد
    mv "$extracted_dir" "$PLUGINS_DIR/"
    
    echo -e "${GREEN}تم تحديث البلجن بنجاح${NC}"
    log_message "تم تحديث $plugin_name من $update_url"
    
    # تنظيف الملفات المؤقتة
    rm -rf "$temp_dir"
}

# عرض البلجنات المثبتة
list_installed_plugins() {
    echo -e "${GREEN}── البلجنات المثبتة ──${NC}"
    
    if [ ! -d "$PLUGINS_DIR" ]; then
        echo -e "${RED}مجلد البلجنات غير موجود${NC}"
        return 1
    fi
    
    local plugins=($(ls "$PLUGINS_DIR"))
    
    if [ ${#plugins[@]} -eq 0 ]; then
        echo -e "${YELLOW}لا توجد بلجنات مثبتة${NC}"
        return 0
    fi
    
    echo -e "${BLUE}عدد البلجنات: ${#plugins[@]}${NC}\n"
    
    for i in "${!plugins[@]}"; do
        local plugin_path="$PLUGINS_DIR/${plugins[$i]}"
        local size=$(du -sh "$plugin_path" 2>/dev/null | cut -f1)
        echo -e "$((i+1)). ${YELLOW}${plugins[$i]}${NC}"
        echo -e "   المسار: $plugin_path"
        echo -e "   الحجم: $size"
        echo -e "   التعديل الأخير: $(stat -c %y "$plugin_path" 2>/dev/null | cut -d' ' -f1 2>/dev/null || echo 'غير متاح')"
        echo ""
    done
}

# إنشاء نسخة احتياطية
backup_plugin() {
    local plugin_name="$1"
    
    if [ -z "$plugin_name" ]; then
        list_installed_plugins
        read -p "أدخل اسم البلجن للنسخ الاحتياطي: " plugin_name
    fi
    
    local plugin_path="$PLUGINS_DIR/$plugin_name"
    
    if [ ! -d "$plugin_path" ]; then
        echo -e "${RED}البلجن غير موجود${NC}"
        return 1
    fi
    
    # إنشاء مجلد النسخ الاحتياطية إذا لم يكن موجوداً
    mkdir -p "$BACKUP_DIR"
    
    # إنشاء اسم الملف مع التاريخ
    local backup_file="${BACKUP_DIR}/${plugin_name}_$(date +%Y%m%d_%H%M%S).tar.gz"
    
    echo -e "${YELLOW}جاري إنشاء نسخة احتياطية...${NC}"
    
    # ضغط البلجن
    tar -czf "$backup_file" -C "$PLUGINS_DIR" "$plugin_name"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}تم إنشاء النسخة الاحتياطية:${NC}"
        echo -e "${BLUE}$backup_file${NC}"
        log_message "تم إنشاء نسخة احتياطية لـ $plugin_name في $backup_file"
    else
        echo -e "${RED}فشل في إنشاء النسخة الاحتياطية${NC}"
    fi
}

# استعادة نسخة احتياطية
restore_plugin() {
    echo -e "${GREEN}── استعادة بلجن من النسخة الاحتياطية ──${NC}"
    
    if [ ! -d "$BACKUP_DIR" ]; then
        echo -e "${RED}لا توجد نسخ احتياطية${NC}"
        return 1
    fi
    
    local backups=($(ls "$BACKUP_DIR"/*.tar.gz 2>/dev/null))
    
    if [ ${#backups[@]} -eq 0 ]; then
        echo -e "${RED}لا توجد نسخ احتياطية${NC}"
        return 1
    fi
    
    echo -e "${BLUE}النسخ الاحتياطية المتاحة:${NC}\n"
    
    for i in "${!backups[@]}"; do
        echo -e "$((i+1)). ${YELLOW}$(basename "${backups[$i]}")${NC}"
        echo -e "   الحجم: $(du -h "${backups[$i]}" | cut -f1)"
        echo ""
    done
    
    read -p "اختر رقم النسخة الاحتياطية: " backup_choice
    
    if [[ ! "$backup_choice" =~ ^[0-9]+$ ]] || [ "$backup_choice" -lt 1 ] || [ "$backup_choice" -gt ${#backups[@]} ]; then
        echo -e "${RED}اختيار غير صالح${NC}"
        return 1
    fi
    
    local selected_backup="${backups[$((backup_choice-1))]}"
    local plugin_name=$(basename "$selected_backup" | cut -d'_' -f1)
    
    echo -e "${YELLOW}جاري استعادة: $plugin_name${NC}"
    
    # استخراج النسخة الاحتياطية
    tar -xzf "$selected_backup" -C "$PLUGINS_DIR"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}تم الاستعادة بنجاح${NC}"
        log_message "تم استعادة $plugin_name من $selected_backup"
    else
        echo -e "${RED}فشل في الاستعادة${NC}"
    fi
}

# ضبط الإعدادات
configure_settings() {
    echo -e "${GREEN}── إعدادات مدير البلجنات ──${NC}"
    
    echo -e "الإعدادات الحالية:"
    echo -e "1. مجلد البلجنات: ${YELLOW}$PLUGINS_DIR${NC}"
    echo -e "2. مجلد النسخ الاحتياطية: ${YELLOW}$BACKUP_DIR${NC}"
    echo -e "3. ملف السجل: ${YELLOW}$LOG_FILE${NC}"
    
    echo -e "\nخيارات التعديل:"
    echo "1. تغيير مجلد البلجنات"
    echo "2. تغيير مجلد النسخ الاحتياطية"
    echo "3. العودة"
    
    read -p "اختر خياراً: " setting_choice
    
    case $setting_choice in
        1)
            read -p "أدخل المسار الجديد لمجلد البلجنات: " new_path
            if [ -n "$new_path" ]; then
                mkdir -p "$new_path"
                PLUGINS_DIR="$new_path"
                echo "PLUGINS_DIR=\"$new_path\"" > "$CONFIG_FILE"
                echo "BACKUP_DIR=\"$BACKUP_DIR\"" >> "$CONFIG_FILE"
                echo "LOG_FILE=\"$LOG_FILE\"" >> "$CONFIG_FILE"
                echo -e "${GREEN}تم تغيير المسار بنجاح${NC}"
            fi
            ;;
        2)
            read -p "أدخل المسار الجديد لمجلد النسخ الاحتياطية: " new_backup
            if [ -n "$new_backup" ]; then
                mkdir -p "$new_backup"
                BACKUP_DIR="$new_backup"
                echo "PLUGINS_DIR=\"$PLUGINS_DIR\"" > "$CONFIG_FILE"
                echo "BACKUP_DIR=\"$new_backup\"" >> "$CONFIG_FILE"
                echo "LOG_FILE=\"$LOG_FILE\"" >> "$CONFIG_FILE"
                echo -e "${GREEN}تم تغيير المسار بنجاح${NC}"
            fi
            ;;
        3)
            return 0
            ;;
        *)
            echo -e "${RED}خيار غير صالح${NC}"
            ;;
    esac
}

# عرض سجل الأحداث
show_log() {
    echo -e "${GREEN}── سجل الأحداث ──${NC}"
    
    if [ ! -f "$LOG_FILE" ]; then
        echo -e "${YELLOW}لا يوجد سجل أحداث${NC}"
        return 0
    fi
    
    if [ -s "$LOG_FILE" ]; then
        echo -e "${BLUE}آخر 50 حدث:${NC}\n"
        tail -50 "$LOG_FILE"
    else
        echo -e "${YELLOW}سجل الأحداث فارغ${NC}"
    fi
    
    echo -e "\n${YELLOW}إجمالي حجم السجل: $(du -h "$LOG_FILE" 2>/dev/null | cut -f1)${NC}"
}

# الدالة الرئيسية
main() {
    # تحميل الإعدادات
    load_config
    
    # التحقق من المتطلبات
    check_dependencies
    
    # إنشاء المجلدات إذا لم تكن موجودة
    mkdir -p "$PLUGINS_DIR"
    mkdir -p "$BACKUP_DIR"
    
    # الحلقة الرئيسية
    while true; do
        show_menu
        read -p "اختر خياراً (1-8): " choice
        
        case $choice in
            1) download_new_plugin ;;
            2) update_existing_plugin ;;
            3) list_installed_plugins ;;
            4) backup_plugin "" ;;
            5) restore_plugin ;;
            6) configure_settings ;;
            7) show_log ;;
            8) 
                echo -e "${GREEN}شكراً لاستخدامك مدير البلجنات!${NC}"
                log_message "تم إنهاء البرنامج"
                exit 0
                ;;
            *) 
                echo -e "${RED}اختيار غير صالح، يرجى المحاولة مرة أخرى${NC}"
                sleep 2
                ;;
        esac
        
        echo -e "\n${YELLOW}اضغط Enter للمتابعة...${NC}"
        read
    done
}

# معالجة الإشارات
trap 'echo -e "\n${RED}تم إيقاف البرنامج${NC}"; log_message "تم إيقاف البرنامج بشكل مفاجئ"; exit 1' INT TERM

# بدء البرنامج
echo -e "${GREEN}بدء تشغيل مدير البلجنات...${NC}"
log_message "بدء تشغيل البرنامج"
main
