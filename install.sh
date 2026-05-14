#!/bin/bash
set -euo pipefail

# Проверка прав root
if [[ $EUID -ne 0 ]]; then
   echo "Этот скрипт нужно запускать от root" >&2
   exit 1
fi

# Обновление индекса пакетов
apt-get update

# Установка необходимых пакетов
apt-get install -y glpi-agent perl-Parse-EDID

# Создание директории для конфигов (если не существует)
mkdir -p /etc/glpi-agent/conf.d

# --- Первый файл: сервер ---
cat > /etc/glpi-agent/conf.d/00-server.cfg <<'EOF'
server = http://inventory.admgornnov.ru/front/inventory.php
EOF

# --- Второй файл: основные настройки ---
cat > /etc/glpi-agent/conf.d/10-base.cfg <<'EOF'
# Добавление сканирование профилей пользователей, а не только общие настройки ПК
# Особенно полезно в контексте установленного ПО на машинах с Windows
scan-profiles = 1
backend-collect-timeout = 300
# С какого сервера или подсети принимать запросы на управление агентом
httpd-trust = 10.50.64.0/22
# Задержка перед первым запуском (в секундах)
delaytime = 3600
# Не будить сервер раньше времени
lazy = 1
# Использовать FQDN имя ПК для записи в базу. 1 - использование "короткого" имени из hostname
assetname-support = 2
# Пишем логи в отдельный файл
logger = file
logfile = /var/log/glpi-agent.log
# Ограничиваем размер (чтобы не забить диск), например 10 МБ
logfile-maxsize = 10
# Уровень детализации (0=минимум, 1=info, 2=debug)
debug = 1
EOF

echo "Установка и настройка glpi-agent успешно завершены."
