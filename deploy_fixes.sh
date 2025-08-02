#!/bin/bash

echo "🚀 Развертывание исправлений на сервер TimeWeb..."

# Копируем исправленные файлы на сервер
echo "📁 Копируем исправленные файлы..."
scp bot.py root@46.149.70.11:/root/burncheckbot-v2/
scp config.py root@46.149.70.11:/root/burncheckbot-v2/
scp env_example.txt root@46.149.70.11:/root/burncheckbot-v2/

# Подключаемся к серверу и перезапускаем бота
echo "🔄 Перезапускаем бота..."
ssh root@46.149.70.11 << 'EOF'
cd /root/burncheckbot-v2

# Останавливаем текущий процесс бота
echo "⏹️ Останавливаем текущий процесс..."
pkill -f "python3 bot.py" || true

# Ждем немного
sleep 2

# Активируем виртуальное окружение и запускаем бота
echo "▶️ Запускаем бота..."
source venv/bin/activate
nohup python3 bot.py > output.log 2>&1 &

# Проверяем, что бот запустился
sleep 3
if pgrep -f "python3 bot.py" > /dev/null; then
    echo "✅ Бот успешно запущен!"
    echo "📊 PID: $(pgrep -f 'python3 bot.py')"
else
    echo "❌ Ошибка запуска бота!"
    echo "📋 Последние логи:"
    tail -n 20 output.log
fi
EOF

echo "🎉 Развертывание завершено!"
echo "📝 Проверьте логи: ssh root@46.149.70.11 'tail -f /root/burncheckbot-v2/output.log'" 