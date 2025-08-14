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

    case "$autostart" in
        enable) /etc/init.d/$name enable ;;
        disable) /etc/init.d/$name disable ;;
    esac

    case "$process" in
        start) /etc/init.d/$name start ;;
        stop) /etc/init.d/$name stop ;;
        restart) /etc/init.d/$name restart ;;
    esac
}

# Функция определения архитектуры
get_architecture() {
    ARCH=$(uname -m)
    case $ARCH in
        "mips24kc") echo "mipsel_24kc" ;;
        "mips74kc") echo "mipsel_74kc" ;;
        "aarch64") echo "aarch64_cortex-a53" ;;
        "armv7l") echo "arm_cortex-a7_neon-vfpv4" ;;
        "x86_64") echo "x86_64" ;;
        *)
            ARCH=$(opkg print-architecture | awk '{print $2}' | head -1)
            [ -z "$ARCH" ] && ARCH="unknown"
            echo "$ARCH"
            ;;
    esac
}

# Функция установки youtubeUnblock
install_youtubeunblock_packages() {
    echo "Обновляем списки пакетов..."
    opkg update || {
        echo "Не удалось обновить списки пакетов! Проверьте время на устройстве"
        exit 1
    }

    # Определяем архитектуру
    PKGARCH=$(get_architecture)
    if [ "$PKGARCH" = "unknown" ]; then
        echo "Не удалось определить архитектуру процессора!"
        echo "Доступные архитектуры:"
        opkg print-architecture
        exit 1
    fi
    echo "Архитектура устройства: $PKGARCH"

    VERSION="1.1.0"
    HASH="473af29"
    BASE_URL="https://github.com/Waujito/youtubeUnblock/releases/download/v${VERSION}/"
    PACK_NAME="youtubeUnblock"

    TEMP_DIR="/tmp/$PACK_NAME"
    mkdir -p "$TEMP_DIR"
    
    # Проверяем установлен ли пакет
    if opkg list-installed | grep -q "^$PACK_NAME"; then
        CURRENT_VERSION=$(opkg list-installed | grep "^$PACK_NAME" | cut -d' ' -f3)
        if [ "$CURRENT_VERSION" = "$VERSION" ]; then
            echo "$PACK_NAME версии $VERSION уже установлен"
        else
            echo "Обновляем $PACK_NAME с версии $CURRENT_VERSION на $VERSION"
        fi
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
    echo "Скачиваем пакет: $YOUTUBEUNBLOCK_FILENAME"
    
    if ! wget -O "$TEMP_DIR/$YOUTUBEUNBLOCK_FILENAME" "$DOWNLOAD_URL"; then
        echo "Пробуем альтернативное имя пакета..."
        YOUTUBEUNBLOCK_FILENAME="youtubeUnblock-${VERSION}-1-${HASH}-${PKGARCH}.ipk"
        DOWNLOAD_URL="${BASE_URL}${YOUTUBEUNBLOCK_FILENAME}"
        wget -O "$TEMP_DIR/$YOUTUBEUNBLOCK_FILENAME" "$DOWNLOAD_URL" || {
            echo "Не удалось скачать пакет для архитектуры $PKGARCH"
            echo "Пожалуйста, установите вручную с:"
            echo "https://github.com/Waujito/youtubeUnblock/releases/tag/v$VERSION"
            exit 1
        }
    fi
    
    echo "Устанавливаем $PACK_NAME..."
    opkg install "$TEMP_DIR/$YOUTUBEUNBLOCK_FILENAME" || {
        echo "Ошибка установки $PACK_NAME!"
        exit 1
    }
    
    # Установка Luci интерфейса
    PACK_NAME="luci-app-youtubeUnblock"
    if ! opkg list-installed | grep -q "^$PACK_NAME"; then
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
    fi

    rm -rf "$TEMP_DIR"
}

# Функция добавления конфигурации Telegram
add_telegram_config() {
    CONFIG_FILE="/etc/config/youtubeUnblock"
    
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "Создаем конфигурационный файл..."
        touch "$CONFIG_FILE"
    fi

    if uci show youtubeUnblock | grep -q "CallsWhatsAppTelegram"; then
        echo "Конфигурация Telegram уже существует"
        return 0
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
    
    echo "Применяем изменения..."
    uci commit youtubeUnblock
}

# Основной процесс
echo "=== Установка youtubeUnblock $VERSION ==="

install_youtubeunblock_packages
add_telegram_config

manage_package "youtubeUnblock" "enable" "start" || {
    echo "Ошибка запуска сервиса!"
    exit 1
}

echo "Проверяем статус сервиса..."
service youtubeUnblock status || {
    echo "Сервис не запущен!"
    exit 1
}

printf "\033[32;1m\nУстановка успешно завершена!\n"
printf "Управление доступно в веб-интерфейсе:\n"
printf "http://адрес-роутера/cgi-bin/luci/admin/services/youtubeUnblock\033[0m\n"
