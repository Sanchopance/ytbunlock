#!/bin/sh

URL="https://raw.githubusercontent.com/Sanchopance/ytbunlock/refs/heads/main"
DIR="/etc/config"
DIR_BACKUP="/root/backup"
config_files="youtubeUnblock"

# Функция управления пакетами
manage_package() {
    local name="$1"
    local autostart="$2"
    local process="$3"

    if ! opkg list-installed | grep -q "^$name"; then
        echo "Пакет $name не установлен!"
        return 1
    fi

    # Управление автозапуском
    case "$autostart" in
        enable) /etc/init.d/$name enable ;;
        disable) /etc/init.d/$name disable ;;
    esac

    # Управление процессом
    case "$process" in
        start) /etc/init.d/$name start ;;
        stop) /etc/init.d/$name stop ;;
        restart) /etc/init.d/$name restart ;;
    esac
}

# Функция установки youtubeUnblock
install_youtubeunblock_packages() {
    echo "Обновляем списки пакетов..."
    opkg update || {
        echo "Не удалось обновить списки пакетов! Проверьте время на устройстве"
        exit 1
    }

    PKGARCH=$(opkg print-architecture | awk 'BEGIN {max=0} {if ($3 > max) {max = $3; arch = $2}} END {print arch}')
    VERSION=$(ubus call system board | jsonfilter -e '@.release.version')
    BASE_URL="https://github.com/Waujito/youtubeUnblock/releases/download/v1.0.0/"
    PACK_NAME="youtubeUnblock"

    AWG_DIR="/tmp/$PACK_NAME"
    mkdir -p "$AWG_DIR"
    
    if opkg list-installed | grep -q $PACK_NAME; then
        echo "$PACK_NAME уже установлен"
    else
        # Установка зависимостей
        PACKAGES="kmod-nft-queue kmod-nf-conntrack"
        for pkg in $PACKAGES; do
            if ! opkg list-installed | grep -q "^$pkg "; then
                echo "Устанавливаем $pkg..."
                opkg install $pkg || {
                    echo "Не удалось установить $pkg!"
                    exit 1
                }
            fi
        done
        
        # Установка основного пакета
        YOUTUBEUNBLOCK_FILENAME="youtubeUnblock-1.0.0-10-f37c3dd-${PKGARCH}-openwrt-23.05.ipk"
        DOWNLOAD_URL="${BASE_URL}${YOUTUBEUNBLOCK_FILENAME}"
        echo "Скачиваем $PACK_NAME с $DOWNLOAD_URL"
        
        wget -O "$AWG_DIR/$YOUTUBEUNBLOCK_FILENAME" "$DOWNLOAD_URL" || {
            echo "Не удалось скачать $PACK_NAME!"
            exit 1
        }
        
        opkg install "$AWG_DIR/$YOUTUBEUNBLOCK_FILENAME" || {
            echo "Не удалось установить $PACK_NAME!"
            exit 1
        }
    fi
    
    # Установка Luci интерфейса
    PACK_NAME="luci-app-youtubeUnblock"
    if ! opkg list-installed | grep -q $PACK_NAME; then
        YOUTUBEUNBLOCK_FILENAME="luci-app-youtubeUnblock-1.0.0-10-f37c3dd.ipk"
        DOWNLOAD_URL="${BASE_URL}${YOUTUBEUNBLOCK_FILENAME}"
        echo "Скачиваем $PACK_NAME с $DOWNLOAD_URL"
        
        wget -O "$AWG_DIR/$YOUTUBEUNBLOCK_FILENAME" "$DOWNLOAD_URL" || {
            echo "Не удалось скачать $PACK_NAME!"
            exit 1
        }
        
        opkg install "$AWG_DIR/$YOUTUBEUNBLOCK_FILENAME" || {
            echo "Не удалось установить $PACK_NAME!"
            exit 1
        }
    fi

    rm -rf "$AWG_DIR"
}

# Основное выполнение
echo "Процесс установки запущен..."

# Создание бэкапа конфигурации
if [ ! -d "$DIR_BACKUP" ]; then
    echo "Создаем резервную копию..."
    mkdir -p "$DIR_BACKUP"
    for file in $config_files; do
        if [ -f "$DIR/$file" ]; then
            cp -f "$DIR/$file" "$DIR_BACKUP/$file" || {
                echo "Не удалось сделать резервную копию $file!"
                exit 1
            }
        fi
    done

    echo "Загружаем новые конфиги..."
    for file in $config_files; do
        wget -O "$DIR/$file" "$URL/config_files/$file" || {
            echo "Не удалось загрузить конфигурацию $file!"
            exit 1
        }
    done
fi

# Установка пакетов
install_youtubeunblock_packages

# Настройка сервиса
manage_package "youtubeUnblock" "enable" "start" || {
    echo "Не удалось установить youtubeUnblock!"
    exit 1
}

echo "Перезапуск службы..."
service youtubeUnblock restart || {
    echo "Не удалось перезапустить службу youtubeUnblock"
    exit 1
}

printf "\033[32;1mВроде все прошло норм, управление youtubeUnblock доступно в службах web интерфейса вашего роутера после перелогина\033[0m\n"
