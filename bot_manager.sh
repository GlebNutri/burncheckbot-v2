#!/bin/bash

# 🚀 Скрипт управления ботом с защитой от дублирования
# Использование: ./bot_manager.sh [start|stop|restart|status]

BOT_DIR="/root/burncheckbot-v2"
PID_FILE="$BOT_DIR/bot.pid"
LOG_FILE="$BOT_DIR/output.log"

# Функция для проверки, запущен ли бот
is_bot_running() {
    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            return 0  # Бот запущен
        else
            rm -f "$PID_FILE"  # Удаляем неактуальный PID файл
        fi
    fi
    return 1  # Бот не запущен
}

# Функция для остановки бота
stop_bot() {
    echo "🛑 Останавливаем бота..."
    
    # Останавливаем все процессы бота
    pkill -9 -f "python3 bot.py" 2>/dev/null || true
    
    # Ждем полного завершения
    sleep 5
    
    # Удаляем PID файл
    rm -f "$PID_FILE"
    
    echo "✅ Бот остановлен"
}

# Функция для запуска бота
start_bot() {
    echo "🚀 Запускаем бота..."
    
    # Проверяем, не запущен ли уже бот
    if is_bot_running; then
        echo "⚠️ Бот уже запущен с PID $(cat $PID_FILE)"
        return 1
    fi
    
    # Переходим в директорию бота
    cd "$BOT_DIR" || {
        echo "❌ Ошибка: директория $BOT_DIR не найдена"
        return 1
    }
    
    # Активируем виртуальное окружение и запускаем бота
    source venv/bin/activate
    nohup python3 bot.py > "$LOG_FILE" 2>&1 &
    
    # Сохраняем PID
    echo $! > "$PID_FILE"
    
    # Ждем немного и проверяем
    sleep 3
    if is_bot_running; then
        echo "✅ Бот успешно запущен с PID $(cat $PID_FILE)"
    else
        echo "❌ Ошибка запуска бота"
        echo "📋 Последние логи:"
        tail -n 10 "$LOG_FILE"
        return 1
    fi
}

# Функция для перезапуска бота
restart_bot() {
    echo "🔄 Перезапускаем бота..."
    stop_bot
    sleep 2
    start_bot
}

# Функция для показа статуса
show_status() {
    if is_bot_running; then
        echo "✅ Бот запущен с PID $(cat $PID_FILE)"
        echo "📊 Использование памяти:"
        ps -o pid,ppid,cmd,%mem,%cpu --pid=$(cat $PID_FILE) 2>/dev/null || echo "Процесс не найден"
    else
        echo "❌ Бот не запущен"
    fi
}

# Основная логика
case "$1" in
    start)
        start_bot
        ;;
    stop)
        stop_bot
        ;;
    restart)
        restart_bot
        ;;
    status)
        show_status
        ;;
    *)
        echo "Использование: $0 {start|stop|restart|status}"
        echo ""
        echo "Команды:"
        echo "  start   - Запустить бота"
        echo "  stop    - Остановить бота"
        echo "  restart - Перезапустить бота"
        echo "  status  - Показать статус бота"
        exit 1
        ;;
esac 