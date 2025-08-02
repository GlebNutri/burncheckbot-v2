#!/bin/bash

# 🔒 Надежный скрипт управления ботом с максимальной защитой от дублирования
# Использование: ./bot_manager_secure.sh [start|stop|restart|status|killall]

BOT_DIR="/root/burncheckbot-v2"
PID_FILE="$BOT_DIR/bot.pid"
LOG_FILE="$BOT_DIR/output.log"
LOCK_FILE="$BOT_DIR/bot.lock"

# Функция для полной очистки всех процессов бота
kill_all_bot_processes() {
    echo "🗑️ Полная очистка всех процессов бота..."
    
    # Останавливаем все возможные процессы бота
    pkill -9 -f "python.*bot.py" 2>/dev/null || true
    pkill -9 -f "bot.py" 2>/dev/null || true
    pkill -9 -f "python3.*bot" 2>/dev/null || true
    pkill -9 -f "venv/bin/python.*bot" 2>/dev/null || true
    
    # Ждем полного завершения
    sleep 10
    
    # Удаляем все файлы состояния
    rm -f "$PID_FILE"
    rm -f "$LOCK_FILE"
    
    echo "✅ Все процессы бота остановлены"
}

# Функция для проверки, запущен ли бот
is_bot_running() {
    # Проверяем lock файл
    if [ -f "$LOCK_FILE" ]; then
        local lock_pid=$(cat "$LOCK_FILE")
        if kill -0 "$lock_pid" 2>/dev/null; then
            return 0  # Бот запущен
        else
            rm -f "$LOCK_FILE"  # Удаляем неактуальный lock файл
        fi
    fi
    
    # Проверяем PID файл
    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            return 0  # Бот запущен
        else
            rm -f "$PID_FILE"  # Удаляем неактуальный PID файл
        fi
    fi
    
    # Проверяем процессы в системе
    if pgrep -f "python.*bot.py" > /dev/null 2>&1; then
        return 0  # Бот запущен
    fi
    
    return 1  # Бот не запущен
}

# Функция для остановки бота
stop_bot() {
    echo "🛑 Останавливаем бота..."
    kill_all_bot_processes
}

# Функция для запуска бота
start_bot() {
    echo "🚀 Запускаем бота..."
    
    # Проверяем, не запущен ли уже бот
    if is_bot_running; then
        echo "⚠️ Бот уже запущен! Останавливаем старый процесс..."
        kill_all_bot_processes
        sleep 5
    fi
    
    # Переходим в директорию бота
    cd "$BOT_DIR" || {
        echo "❌ Ошибка: директория $BOT_DIR не найдена"
        return 1
    }
    
    # Создаем lock файл с PID текущего скрипта
    echo $$ > "$LOCK_FILE"
    
    # Активируем виртуальное окружение и запускаем бота
    source venv/bin/activate
    
    # Запускаем бота в фоне
    nohup python3 bot.py > "$LOG_FILE" 2>&1 &
    local bot_pid=$!
    
    # Сохраняем PID бота
    echo $bot_pid > "$PID_FILE"
    
    # Ждем и проверяем
    sleep 5
    if kill -0 $bot_pid 2>/dev/null; then
        echo "✅ Бот успешно запущен с PID $bot_pid"
        echo "📊 Использование памяти:"
        ps -o pid,ppid,cmd,%mem,%cpu --pid=$bot_pid 2>/dev/null || echo "Процесс не найден"
    else
        echo "❌ Ошибка запуска бота"
        echo "📋 Последние логи:"
        tail -n 10 "$LOG_FILE"
        rm -f "$PID_FILE" "$LOCK_FILE"
        return 1
    fi
}

# Функция для перезапуска бота
restart_bot() {
    echo "🔄 Перезапускаем бота..."
    stop_bot
    sleep 5
    start_bot
}

# Функция для показа статуса
show_status() {
    echo "📊 Статус бота:"
    
    if is_bot_running; then
        echo "✅ Бот запущен"
        if [ -f "$PID_FILE" ]; then
            local pid=$(cat "$PID_FILE")
            echo "📋 PID: $pid"
            echo "📊 Использование ресурсов:"
            ps -o pid,ppid,cmd,%mem,%cpu --pid=$pid 2>/dev/null || echo "Процесс не найден"
        fi
    else
        echo "❌ Бот не запущен"
    fi
    
    echo ""
    echo "🔍 Все процессы Python:"
    ps aux | grep python | grep -v grep || echo "Процессы Python не найдены"
}

# Функция для принудительной очистки
killall() {
    echo "💀 Принудительная очистка всех процессов..."
    kill_all_bot_processes
    echo "✅ Очистка завершена"
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
    killall)
        killall
        ;;
    *)
        echo "Использование: $0 {start|stop|restart|status|killall}"
        echo ""
        echo "Команды:"
        echo "  start   - Запустить бота (с защитой от дублирования)"
        echo "  stop    - Остановить бота"
        echo "  restart - Перезапустить бота"
        echo "  status  - Показать статус бота"
        echo "  killall - Принудительно остановить ВСЕ процессы бота"
        echo ""
        echo "🔒 Защита от дублирования:"
        echo "  - Проверка всех возможных процессов"
        echo "  - Использование lock файлов"
        echo "  - Принудительная остановка перед запуском"
        exit 1
        ;;
esac 