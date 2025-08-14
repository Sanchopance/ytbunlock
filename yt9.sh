#!/bin/sh

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

# Функция установки/обновления youtubeUnblock
install_youtubeunblock_packages() {
    echo "Обновляем списки пакетов..."
    opkg update || {
        echo "Не удалось обновить списки пакетов! Проверьте время на устройстве"
        exit 1
    }

    PKGARCH=$(opkg print-architecture | awk 'BEGIN {max=0} {if ($3 > max) {max = $3; arch = $2}} END {print arch}')
    VERSION="1.1.0"
    HASH="473af29"
    BASE_URL="https://github.com/Waujito/youtubeUnblock/releases/download/v${VERSION}/"
    PACK_NAME="youtubeUnblock"

    TEMP_DIR="/tmp/$PACK_NAME"
    mkdir -p "$TEMP_DIR"
    
    # Удаляем старую версию, если установлена
    if opkg list-installed | grep -q "^$PACK_NAME"; then
        CURRENT_VERSION=$(opkg list-installed | grep "^$PACK_NAME" | cut -d' ' -f3)
        echo "Найдена установленная версия $CURRENT_VERSION, обновляем до $VERSION"
        opkg remove $PACK_NAME
    fi

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
    YOUTUBEUNBLOCK_FILENAME="youtubeUnblock-${VERSION}-1-${HASH}-${PKGARCH}-openwrt-23.05.ipk"
    DOWNLOAD_URL="${BASE_URL}${YOUTUBEUNBLOCK_FILENAME}"
    echo "Скачиваем $PACK_NAME версии $VERSION"
    
    wget -O "$TEMP_DIR/$YOUTUBEUNBLOCK_FILENAME" "$DOWNLOAD_URL" || {
        echo "Не удалось скачать $PACK_NAME!"
        exit 1
    }
    
    opkg install "$TEMP_DIR/$YOUTUBEUNBLOCK_FILENAME" || {
        echo "Не удалось установить $PACK_NAME!"
        exit 1
    }
    
    # Установка Luci интерфейса
    PACK_NAME="luci-app-youtubeUnblock"
    if opkg list-installed | grep -q "^$PACK_NAME"; then
        echo "Удаляем старую версию Luci интерфейса..."
        opkg remove $PACK_NAME
    fi
    
    YOUTUBEUNBLOCK_FILENAME="luci-app-youtubeUnblock-${VERSION}-1-${HASH}.ipk"
    DOWNLOAD_URL="${BASE_URL}${YOUTUBEUNBLOCK_FILENAME}"
    echo "Скачиваем $PACK_NAME"
    
    wget -O "$TEMP_DIR/$YOUTUBEUNBLOCK_FILENAME" "$DOWNLOAD_URL" || {
        echo "Не удалось скачать $PACK_NAME!"
        exit 1
    }
    
    opkg install "$TEMP_DIR/$YOUTUBEUNBLOCK_FILENAME" || {
        echo "Не удалось установить $PACK_NAME!"
        exit 1
    }

    rm -rf "$TEMP_DIR"
}

# Функция добавления конфигурации Telegram
add_telegram_config() {
    CONFIG_FILE="/etc/config/youtubeUnblock"
    
    # Проверяем существует ли файл
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "Конфигурационный файл не найден, создаем новый..."
        touch "$CONFIG_FILE"
    fi

    # Проверяем есть ли уже секция для Telegram
    if uci show youtubeUnblock | grep -q "CallsWhatsAppTelegram"; then
        echo "Конфигурация для Telegram уже существует, обновляем..."
        uci delete youtubeUnblock.@section[0]
    fi

    echo "Добавляем конфигурацию Telegram..."
    uci add youtubeUnblock section
    uci set youtubeUnblock.@section[-1].name='CallsWhatsAppTelegram'
    uci set youtubeUnblock.@section[-1].tls_enabled='0'
    uci set youtubeUnblock.@section[-1].all_domains='0'
    uci add_list youtubeUnblock.@section[-1].sni_domains='cdn-telegram.org'
    uci add_list youtubeUnblock.@section[-1].sni_domains='comments.app'
    uci add_list youtubeUnblock.@section[-1].sni_domains='contest.com'
    uci add_list youtubeUnblock.@section[-1].sni_domains='fragment.com'
    uci add_list youtubeUnblock.@section[-1].sni_domains='graph.org'
    uci add_list youtubeUnblock.@section[-1].sni_domains='quiz.directory'
    uci add_list youtubeUnblock.@section[-1].sni_domains='t.me'
    uci add_list youtubeUnblock.@section[-1].sni_domains='tdesktop.com'
    uci add_list youtubeUnblock.@section[-1].sni_domains='telega.one'
    uci add_list youtubeUnblock.@section[-1].sni_domains='telegra.ph'
    uci add_list youtubeUnblock.@section[-1].sni_domains='telegram-cdn.org'
    uci add_list youtubeUnblock.@section[-1].sni_domains='telegram.dog'
    uci add_list youtubeUnblock.@section[-1].sni_domains='telegram.me'
    uci add_list youtubeUnblock.@section[-1].sni_domains='telegram.org'
    uci add_list youtubeUnblock.@section[-1].sni_domains='telegram.space'
    uci add_list youtubeUnblock.@section[-1].sni_domains='telesco.pe'
    uci add_list youtubeUnblock.@section[-1].sni_domains='tg.dev'
    uci add_list youtubeUnblock.@section[-1].sni_domains='tx.me'
    uci add_list youtubeUnblock.@section[-1].sni_domains='usercontent.dev'
    uci set youtubeUnblock.@section[-1].sni_detection='parse'
    uci set youtubeUnblock.@section[-1].quic_drop='0'
    uci set youtubeUnblock.@section[-1].udp_mode='fake'
    uci set youtubeUnblock.@section[-1].udp_faking_strategy='none'
    uci set youtubeUnblock.@section[-1].udp_fake_seq_len='6'
    uci set youtubeUnblock.@section[-1].udp_fake_len='64'
    uci set youtubeUnblock.@section[-1].udp_filter_quic='disabled'
    uci set youtubeUnblock.@section[-1].enabled='1'
    uci set youtubeUnblock.@section[-1].udp_stun_filter='1'
    
    echo "Применяем изменения конфигурации..."
    uci commit youtubeUnblock
}

# Основное выполнение
echo "=== Начало установки/обновления youtubeUnblock ==="

# Установка/обновление пакетов
install_youtubeunblock_packages

# Добавление/обновление конфигурации
add_telegram_config

# Настройка сервиса
manage_package "youtubeUnblock" "enable" "restart" || {
    echo "Не удалось настроить youtubeUnblock!"
    exit 1
}

echo "Проверяем версию..."
opkg list-installed | grep youtubeUnblock

printf "\033[32;1m\nОбновление до версии 1.1.0 успешно завершено!\n"
printf "Управление доступно в веб-интерфейсе:\n"
printf "http://адрес-роутера/cgi-bin/luci/admin/services/youtubeUnblock\033[0m\n"
