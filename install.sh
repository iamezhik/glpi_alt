#!/bin/bash
set -euo pipefail

# Проверка прав root
if [[ $EUID -ne 0 ]]; then
   echo "Этот скрипт нужно запускать от root" >&2
   exit 1
fi

# Обновление индекса пакетов
echo ">>> Обновление списка пакетов..."
apt-get update

# Установка необходимых пакетов
echo ">>> Установка glpi-agent и perl-Parse-EDID..."
apt-get install -y glpi-agent perl-Parse-EDID

# Создание директории для конфигов (если не существует)
mkdir -p /etc/glpi-agent/conf.d

# --- Первый файл: сервер ---
echo ">>> Создание 00-server.cfg..."
cat > /etc/glpi-agent/conf.d/00-server.cfg <<'EOF'
server = http://inventory.admgornnov.ru/front/inventory.php
EOF

# --- Второй файл: основные настройки ---
echo ">>> Создание 10-base.cfg..."
cat > /etc/glpi-agent/conf.d/10-base.cfg <<'EOF'
# Добавление сканирование профилей пользователей, а не только общие настройки ПК
# Особенно полезно в контексте установленного ПО на машинах с Windows
scan-homedirs = 1
scan-profiles = 1
backend-collect-timeout = 300
# С какого сервера или подсети принимать запросы на управление агентом
httpd-trust = 10.50.100.0/24
# Задержка перед первым запуском (в секундах)
delaytime = 3600
# Не будить сервер раньше времени
lazy = 1
# Использовать FQDN имя ПК для записи в базу. 1 - использование "короткого" имени из hostname
assetname-support = 1
# Пишем логи в отдельный файл
logger = file
logfile = /var/log/glpi-agent.log
# Ограничиваем размер (чтобы не забить диск), например 10 МБ
logfile-maxsize = 10
# Уровень детализации (0=минимум, 1=info, 2=debug)
debug = 1
EOF

# --- Третий файл: теги (интерактивный выбор) ---
echo ">>> Настройка тегов..."
TAGS_LIST=("DIT" "WAREHOUSE" "LINUX-PC" "WIN-PC")
if [ -t 0 ]; then
    echo "--- Интерактивный выбор тегов ---"
    echo "Доступные теги:"
    for i in "${!TAGS_LIST[@]}"; do
        echo "$((i+1))) ${TAGS_LIST[$i]}"
    done
    while true; do
        read -p "Введите номера тегов через пробел (например, 1 3): " choices
        if [ -z "$choices" ]; then
            echo "Необходимо выбрать хотя бы один тег."
            continue
        fi
        valid=true
        selected_tags=()
        for choice in $choices; do
            if ! [[ "$choice" =~ ^[1-4]$ ]]; then
                echo "Некорректный номер: $choice"
                valid=false
                break
            fi
            selected_tags+=("${TAGS_LIST[$((choice-1))]}")
        done
        if $valid; then
            break
        fi
    done
    TAG_VALUE=$(IFS=:; echo "${selected_tags[*]}")
else
    # Неинтерактивный режим: можно задать теги через переменную окружения TAG
    if [ -n "${TAG:-}" ]; then
        TAG_VALUE="$TAG"
        echo "Используются теги из переменной окружения: $TAG_VALUE"
    else
        TAG_VALUE="LINUX-PC"
        echo "Неинтерактивный режим: используется тег по умолчанию «$TAG_VALUE»"
    fi
fi

cat > /etc/glpi-agent/conf.d/20-tag.cfg <<EOF
tag = ${TAG_VALUE}
EOF
echo "Теги сохранены: tag = ${TAG_VALUE}"

# Включение и запуск сервиса
echo ">>> Включение автозапуска и старт glpi-agent..."
systemctl enable glpi-agent
systemctl start glpi-agent

# Финальная проверка
if systemctl is-active --quiet glpi-agent; then
    echo "✅ Установка и настройка glpi-agent успешно завершены. Сервис активен."
else
    echo "❌ Ошибка: сервис glpi-agent не запустился!" >&2
    exit 1
fi
