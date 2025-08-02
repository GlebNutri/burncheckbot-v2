#!/bin/bash

# 🤖 Единый скрипт управления ботом с максимальной защитой
# Использование: ./bot_manager_unified.sh [start|stop|restart|status|deploy|update|killall|logs]

BOT_DIR="/root/burncheckbot-v2"
PID_FILE="$BOT_DIR/bot.pid"
LOCK_FILE="$BOT_DIR/bot.lock"
LOG_FILE="$BOT_DIR/output.log"
SUPERVISOR_CONF="/etc/supervisor/conf.d/burncheckbot.conf"

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Функция для логирования
log_message() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

# Функция для принудительной остановки всех процессов бота
force_kill_all_bot_processes() {
    log_message "${YELLOW}🗑️ Принудительная остановка всех процессов бота...${NC}"
    
    # Останавливаем supervisor процесс
    supervisorctl stop burncheckbot 2>/dev/null || true
    
    # Убиваем все возможные процессы бота
    pkill -9 -f "python.*bot.py" 2>/dev/null || true
    pkill -9 -f "bot.py" 2>/dev/null || true
    pkill -9 -f "python3.*bot" 2>/dev/null || true
    pkill -9 -f "venv/bin/python.*bot" 2>/dev/null || true
    
    # Ждем полного завершения
    sleep 5
    
    # Удаляем все файлы состояния
    rm -f "$PID_FILE"
    rm -f "$LOCK_FILE"
    
    log_message "${GREEN}✅ Все процессы бота остановлены${NC}"
}

# Функция для проверки статуса бота
check_bot_status() {
    # Проверяем supervisor статус
    if supervisorctl status burncheckbot 2>/dev/null | grep -q "RUNNING"; then
        return 0  # Бот запущен через supervisor
    fi
    
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
    log_message "${YELLOW}🛑 Останавливаем бота...${NC}"
    force_kill_all_bot_processes
}

# Функция для запуска бота
start_bot() {
    log_message "${YELLOW}🚀 Запускаем бота...${NC}"
    
    # Проверяем, не запущен ли уже бот
    if check_bot_status; then
        log_message "${YELLOW}⚠️ Бот уже запущен! Останавливаем старый процесс...${NC}"
        force_kill_all_bot_processes
        sleep 3
    fi
    
    # Переходим в директорию бота
    cd "$BOT_DIR" || {
        log_message "${RED}❌ Ошибка: директория $BOT_DIR не найдена${NC}"
        return 1
    }
    
    # Проверяем наличие необходимых файлов
    if [ ! -f "bot.py" ]; then
        log_message "${RED}❌ Ошибка: файл bot.py не найден${NC}"
        return 1
    fi
    
    if [ ! -f ".env" ]; then
        log_message "${RED}❌ Ошибка: файл .env не найден${NC}"
        return 1
    fi
    
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
        log_message "${GREEN}✅ Бот успешно запущен с PID $bot_pid${NC}"
        log_message "${BLUE}📊 Использование ресурсов:${NC}"
        ps -o pid,ppid,cmd,%mem,%cpu --pid=$bot_pid 2>/dev/null || log_message "Процесс не найден"
    else
        log_message "${RED}❌ Ошибка запуска бота${NC}"
        log_message "${BLUE}📋 Последние логи:${NC}"
        tail -n 10 "$LOG_FILE"
        rm -f "$PID_FILE" "$LOCK_FILE"
        return 1
    fi
}

# Функция для перезапуска бота
restart_bot() {
    log_message "${YELLOW}🔄 Перезапускаем бота...${NC}"
    stop_bot
    sleep 3
    start_bot
}

# Функция для показа статуса
show_status() {
    log_message "${BLUE}📊 Статус бота:${NC}"
    
    if check_bot_status; then
        echo -e "${GREEN}✅ Бот запущен${NC}"
        
        # Показываем информацию о supervisor
        if supervisorctl status burncheckbot 2>/dev/null | grep -q "RUNNING"; then
            echo -e "${BLUE}📋 Supervisor статус:${NC}"
            supervisorctl status burncheckbot
        fi
        
        # Показываем информацию о PID
        if [ -f "$PID_FILE" ]; then
            local pid=$(cat "$PID_FILE")
            echo -e "${BLUE}📋 PID: $pid${NC}"
            echo -e "${BLUE}📊 Использование ресурсов:${NC}"
            ps -o pid,ppid,cmd,%mem,%cpu --pid=$pid 2>/dev/null || echo "Процесс не найден"
        fi
    else
        echo -e "${RED}❌ Бот не запущен${NC}"
    fi
    
    echo ""
    echo -e "${BLUE}🔍 Все процессы Python:${NC}"
    ps aux | grep python | grep -v grep || echo "Процессы Python не найдены"
}

# Функция для обновления с git
update_from_git() {
    log_message "${YELLOW}📥 Обновление с git...${NC}"
    
    cd "$BOT_DIR" || {
        log_message "${RED}❌ Ошибка: директория $BOT_DIR не найдена${NC}"
        return 1
    }
    
    # Останавливаем бота перед обновлением
    if check_bot_status; then
        log_message "${YELLOW}🛑 Останавливаем бота для обновления...${NC}"
        stop_bot
    fi
    
    # Обновляем код
    git fetch origin
    git reset --hard origin/main
    
    # Обновляем зависимости
    source venv/bin/activate
    pip install -r requirements.txt
    
    log_message "${GREEN}✅ Обновление завершено${NC}"
}

# Функция для деплоя
deploy_bot() {
    log_message "${YELLOW}🚀 Начинаем деплой бота...${NC}"
    
    # Обновление системы
    log_message "${BLUE}📦 Обновление системы...${NC}"
    apt update && apt upgrade -y
    
    # Установка зависимостей
    log_message "${BLUE}🔧 Установка Python и зависимостей...${NC}"
    apt install python3 python3-pip python3-venv git supervisor -y
    
    # Создание директории проекта
    log_message "${BLUE}📁 Создание директории проекта...${NC}"
    mkdir -p "$BOT_DIR"
    cd "$BOT_DIR"
    
    # Клонирование репозитория (если еще не клонирован)
    if [ ! -d ".git" ]; then
        log_message "${BLUE}📥 Клонирование репозитория...${NC}"
        git clone https://github.com/GlebNutri/burncheckbot-v2.git .
    fi
    
    # Создание виртуального окружения
    log_message "${BLUE}🐍 Создание виртуального окружения...${NC}"
    python3 -m venv venv
    source venv/bin/activate
    
    # Установка зависимостей
    log_message "${BLUE}📚 Установка зависимостей Python...${NC}"
    pip install -r requirements.txt
    
    # Создание конфигурации Supervisor
    log_message "${BLUE}⚙️ Настройка автозапуска...${NC}"
    cat > "$SUPERVISOR_CONF" << EOF
[program:burncheckbot]
command=$BOT_DIR/venv/bin/python $BOT_DIR/bot.py
directory=$BOT_DIR
user=root
autostart=true
autorestart=true
stderr_logfile=/var/log/burncheckbot.err.log
stdout_logfile=/var/log/burncheckbot.out.log
environment=PYTHONPATH="$BOT_DIR"
EOF
    
    # Перезапуск Supervisor
    log_message "${BLUE}🔄 Перезапуск Supervisor...${NC}"
    supervisorctl reread
    supervisorctl update
    
    log_message "${GREEN}✅ Деплой завершен!${NC}"
}

# Функция для показа логов
show_logs() {
    log_message "${BLUE}📋 Логи бота:${NC}"
    echo ""
    echo -e "${BLUE}📄 Последние 50 строк лога:${NC}"
    tail -n 50 "$LOG_FILE" 2>/dev/null || echo "Файл лога не найден"
    echo ""
    echo -e "${BLUE}🔍 Supervisor логи:${NC}"
    echo -e "${BLUE}   Стандартный вывод:${NC} tail -f /var/log/burncheckbot.out.log"
    echo -e "${BLUE}   Ошибки:${NC} tail -f /var/log/burncheckbot.err.log"
}

# Функция для принудительной очистки
killall() {
    log_message "${YELLOW}💀 Принудительная очистка всех процессов...${NC}"
    force_kill_all_bot_processes
    log_message "${GREEN}✅ Очистка завершена${NC}"
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
    deploy)
        deploy_bot
        ;;
    update)
        update_from_git
        ;;
    logs)
        show_logs
        ;;
    killall)
        killall
        ;;
    *)
        echo -e "${BLUE}🤖 Единый скрипт управления ботом${NC}"
        echo ""
        echo -e "${YELLOW}Использование: $0 {start|stop|restart|status|deploy|update|logs|killall}${NC}"
        echo ""
        echo -e "${GREEN}Команды:${NC}"
        echo -e "  ${BLUE}start${NC}   - Запустить бота (с защитой от дублирования)"
        echo -e "  ${BLUE}stop${NC}    - Остановить бота"
        echo -e "  ${BLUE}restart${NC} - Перезапустить бота"
        echo -e "  ${BLUE}status${NC}  - Показать статус бота"
        echo -e "  ${BLUE}deploy${NC}  - Полный деплой на сервер"
        echo -e "  ${BLUE}update${NC}  - Обновить код с git"
        echo -e "  ${BLUE}logs${NC}    - Показать логи бота"
        echo -e "  ${BLUE}killall${NC} - Принудительно остановить ВСЕ процессы бота"
        echo ""
        echo -e "${GREEN}🔒 Защита от дублирования:${NC}"
        echo -e "  - Проверка всех возможных процессов"
        echo -e "  - Использование PID и lock файлов"
        echo -e "  - Принудительная остановка перед запуском"
        echo -e "  - Игнорирование существующих дублей"
        exit 1
        ;;
esac 