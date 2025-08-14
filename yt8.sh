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

# Функция установки youtubeUnblock
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
        YOUTUBEUNBLOCK_FILENAME="youtubeUnblock-${VERSION}-1-${HASH}-${PKGARCH}-openwrt-23.05.ipk"
        DOWNLOAD_URL="${BASE_URL}${YOUTUBEUNBLOCK_FILENAME}"
        echo "Скачиваем $PACK_NAME"
        
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
        YOUTUBEUNBLOCK_FILENAME="luci-app-youtubeUnblock-${VERSION}-1-${HASH}.ipk"
        DOWNLOAD_URL="${BASE_URL}${YOUTUBEUNBLOCK_FILENAME}"
        echo "Скачиваем $PACK_NAME"
        
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
        echo "Конфигурация для Telegram уже существует, пропускаем..."
        return 0
    fi

    echo "Добавляем конфигурацию Telegram в конец файла..."
    cat >> "$CONFIG_FILE" <<EOF

config section
	option name 'CallsWhatsAppTelegram'
	option tls_enabled '0'
	option all_domains '0'
	list sni_domains 'cdn-telegram.org'
	list sni_domains 'comments.app'
	list sni_domains 'contest.com'
	list sni_domains 'fragment.com'
	list sni_domains 'graph.org'
	list sni_domains 'quiz.directory'
	list sni_domains 't.me'
	list sni_domains 'tdesktop.com'
	list sni_domains 'telega.one'
	list sni_domains 'telegra.ph'
	list sni_domains 'telegram-cdn.org'
	list sni_domains 'telegram.dog'
	list sni_domains 'telegram.me'
	list sni_domains 'telegram.org'
	list sni_domains 'telegram.space'
	list sni_domains 'telesco.pe'
	list sni_domains 'tg.dev'
	list sni_domains 'tx.me'
	list sni_domains 'usercontent.dev'
	option sni_detection 'parse'
	option quic_drop '0'
	option udp_mode 'fake'
	option udp_faking_strategy 'none'
	option udp_fake_seq_len '6'
	option udp_fake_len '64'
	option udp_filter_quic 'disabled'
	option enabled '1'
	option udp_stun_filter '1'
EOF

    echo "Применяем изменения конфигурации..."
    uci commit youtubeUnblock
}

# Основное выполнение
echo "Процесс установки запущен..."

# Установка пакетов
install_youtubeunblock_packages

# Добавление конфигурации
add_telegram_config

# Настройка сервиса
manage_package "youtubeUnblock" "enable" "start" || {
    echo "Не удалось настроить youtubeUnblock!"
    exit 1
}

echo "Перезапуск службы..."
service youtubeUnblock restart || {
    echo "Не удалось перезапустить службу youtubeUnblock"
    exit 1
}

printf "\033[32;1mУстановка завершена успешно!\n\nУправление youtubeUnblock доступно в веб-интерфейсе вашего роутера:\nhttp://адрес-роутера/cgi-bin/luci/admin/services/youtubeUnblock\033[0m\n"
