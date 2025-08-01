#!/bin/bash

# 🚀 Скрипт автоматического деплоя бота на TimeWeb
# Использование: ./deploy_timeweb.sh

echo "🤖 Начинаем деплой бота на TimeWeb..."

# Проверка наличия необходимых файлов
if [ ! -f "bot.py" ]; then
    echo "❌ Ошибка: файл bot.py не найден!"
    exit 1
fi

if [ ! -f "requirements.txt" ]; then
    echo "❌ Ошибка: файл requirements.txt не найден!"
    exit 1
fi

if [ ! -f ".env" ]; then
    echo "❌ Ошибка: файл .env не найден!"
    echo "Создайте файл .env с вашим токеном бота"
    exit 1
fi

echo "✅ Все необходимые файлы найдены"

# Обновление системы
echo "📦 Обновление системы..."
apt update && apt upgrade -y

# Установка зависимостей
echo "🔧 Установка Python и зависимостей..."
apt install python3 python3-pip python3-venv git supervisor -y

# Создание директории проекта
echo "📁 Создание директории проекта..."
mkdir -p /root/burncheckbot-v2
cd /root/burncheckbot-v2

# Клонирование репозитория (если еще не клонирован)
if [ ! -d ".git" ]; then
    echo "📥 Клонирование репозитория..."
    git clone https://github.com/GlebNutri/burncheckbot-v2.git .
fi

# Создание виртуального окружения
echo "🐍 Создание виртуального окружения..."
python3 -m venv venv
source venv/bin/activate

# Установка зависимостей
echo "📚 Установка зависимостей Python..."
pip install -r requirements.txt

# Копирование .env файла
echo "🔐 Настройка переменных окружения..."
cp .env /root/burncheckbot-v2/.env

# Создание конфигурации Supervisor
echo "⚙️ Настройка автозапуска..."
cat > /etc/supervisor/conf.d/burncheckbot.conf << EOF
[program:burncheckbot]
command=/root/burncheckbot-v2/venv/bin/python /root/burncheckbot-v2/bot.py
directory=/root/burncheckbot-v2
user=root
autostart=true
autorestart=true
stderr_logfile=/var/log/burncheckbot.err.log
stdout_logfile=/var/log/burncheckbot.out.log
environment=PYTHONPATH="/root/burncheckbot-v2"
EOF

# Перезапуск Supervisor
echo "🔄 Перезапуск Supervisor..."
supervisorctl reread
supervisorctl update

# Остановка существующих процессов
echo "🛑 Остановка существующих процессов..."
supervisorctl stop burncheckbot 2>/dev/null || true
pkill -f "python.*bot.py" 2>/dev/null || true

# Запуск бота
echo "🚀 Запуск бота..."
supervisorctl start burncheckbot

# Проверка статуса
echo "📊 Проверка статуса..."
sleep 3
supervisorctl status burncheckbot

echo "✅ Деплой завершен!"
echo "📝 Логи бота:"
echo "   - Стандартный вывод: tail -f /var/log/burncheckbot.out.log"
echo "   - Ошибки: tail -f /var/log/burncheckbot.err.log"
echo "🔄 Управление:"
echo "   - Статус: supervisorctl status burncheckbot"
echo "   - Перезапуск: supervisorctl restart burncheckbot"
echo "   - Остановка: supervisorctl stop burncheckbot" 