#!/bin/bash

# 🤖 Главный скрипт управления ботом - координатор
# Использование: ./bot_manager.sh [local|remote] [команда] [параметры]

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

# Функция для показа справки
show_help() {
    echo -e "${BLUE}🤖 Главный скрипт управления ботом${NC}"
    echo ""
    echo -e "${YELLOW}Использование: $0 {local|remote} [команда] [параметры]${NC}"
    echo ""
    echo -e "${GREEN}Локальное управление (на сервере):${NC}"
    echo -e "  ${BLUE}local start${NC}     - Запустить бота"
    echo -e "  ${BLUE}local stop${NC}      - Остановить бота"
    echo -e "  ${BLUE}local restart${NC}   - Перезапустить бота"
    echo -e "  ${BLUE}local status${NC}    - Показать статус"
    echo -e "  ${BLUE}local logs${NC}      - Показать логи"
    echo -e "  ${BLUE}local update${NC}    - Обновить код с git"
    echo -e "  ${BLUE}local deploy${NC}    - Полный деплой"
    echo -e "  ${BLUE}local killall${NC}   - Принудительная очистка"
    echo ""
    echo -e "${GREEN}Удаленное управление (с локального компьютера):${NC}"
    echo -e "  ${BLUE}remote update <IP> [SSH_KEY]${NC} - Обновить бота на сервере"
    echo -e "  ${BLUE}remote deploy <IP> [SSH_KEY]${NC} - Полный деплой на сервер"
    echo -e "  ${BLUE}remote status <IP> [SSH_KEY]${NC} - Статус бота на сервере"
    echo -e "  ${BLUE}remote logs <IP> [SSH_KEY]${NC}   - Логи бота на сервере"
    echo -e "  ${BLUE}remote restart <IP> [SSH_KEY]${NC} - Перезапуск на сервере"
    echo ""
    echo -e "${GREEN}Примеры:${NC}"
    echo -e "  ${BLUE}./bot_manager.sh local start${NC}"
    echo -e "  ${BLUE}./bot_manager.sh local status${NC}"
    echo -e "  ${BLUE}./bot_manager.sh remote update 123.456.789.012${NC}"
    echo -e "  ${BLUE}./bot_manager.sh remote deploy 123.456.789.012${NC}"
    echo -e "  ${BLUE}./bot_manager.sh remote status 123.456.789.012 ~/.ssh/custom_key${NC}"
    echo ""
    echo -e "${GREEN}🔒 Защита от дублирования:${NC}"
    echo -e "  - Использование PID файлов"
    echo -e "  - Принудительная остановка перед запуском"
    echo -e "  - Игнорирование существующих дублей"
}

# Функция для локального управления (на сервере)
local_management() {
    local command="$1"
    
    case "$command" in
            start)
                log_message "${YELLOW}🚀 Запуск бота...${NC}"
                nohup python3 bot.py > output.log 2>&1 &
                echo $! > bot.pid
                log_message "${GREEN}✅ Бот запущен с PID $(cat bot.pid)${NC}"
                ;;
            stop)
                log_message "${YELLOW}🛑 Остановка бота...${NC}"
                if [ -f "bot.pid" ]; then
                    kill $(cat bot.pid) 2>/dev/null || true
                    rm -f bot.pid
                fi
                pkill -f "python.*bot.py" 2>/dev/null || true
                log_message "${GREEN}✅ Бот остановлен${NC}"
                ;;
            restart)
                log_message "${YELLOW}🔄 Перезапуск бота...${NC}"
                $0 local stop
                sleep 2
                $0 local start
                ;;
            status)
                log_message "${BLUE}📊 Статус бота:${NC}"
                if [ -f "bot.pid" ] && kill -0 $(cat bot.pid) 2>/dev/null; then
                    echo -e "${GREEN}✅ Бот запущен с PID $(cat bot.pid)${NC}"
                else
                    echo -e "${RED}❌ Бот не запущен${NC}"
                fi
                ;;
            logs)
                log_message "${BLUE}📋 Логи бота:${NC}"
                tail -n 50 output.log 2>/dev/null || echo "Файл лога не найден"
                ;;
            update)
                log_message "${YELLOW}📥 Обновление с git...${NC}"
                $0 local stop
                git fetch origin
                git reset --hard origin/main
                source venv/bin/activate
                pip install -r requirements.txt
                $0 local start
                ;;
            deploy)
                log_message "${YELLOW}🚀 Полный деплой бота на сервер...${NC}"
                
                # Проверка наличия необходимых файлов
                if [ ! -f "bot.py" ]; then
                    log_message "${RED}❌ Ошибка: файл bot.py не найден!${NC}"
                    return 1
                fi
                
                if [ ! -f "requirements.txt" ]; then
                    log_message "${RED}❌ Ошибка: файл requirements.txt не найден!${NC}"
                    return 1
                fi
                
                if [ ! -f ".env" ]; then
                    log_message "${RED}❌ Ошибка: файл .env не найден!${NC}"
                    log_message "${YELLOW}Создайте файл .env с вашим токеном бота${NC}"
                    return 1
                fi
                
                log_message "${GREEN}✅ Все необходимые файлы найдены${NC}"
                
                # Обновление системы
                log_message "${BLUE}📦 Обновление системы...${NC}"
                apt update && apt upgrade -y
                
                # Установка зависимостей
                log_message "${BLUE}🔧 Установка Python и зависимостей...${NC}"
                apt install python3 python3-pip python3-venv git supervisor -y
                
                # Создание директории проекта
                log_message "${BLUE}📁 Создание директории проекта...${NC}"
                mkdir -p /root/burncheckbot-v2
                cd /root/burncheckbot-v2
                
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
                
                # Копирование .env файла
                log_message "${BLUE}🔐 Настройка переменных окружения...${NC}"
                cp .env /root/burncheckbot-v2/.env
                
                # Создание конфигурации Supervisor
                log_message "${BLUE}⚙️ Настройка автозапуска...${NC}"
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
                log_message "${BLUE}🔄 Перезапуск Supervisor...${NC}"
                supervisorctl reread
                supervisorctl update
                
                # Остановка существующих процессов
                log_message "${BLUE}🛑 Остановка существующих процессов...${NC}"
                supervisorctl stop burncheckbot 2>/dev/null || true
                pkill -f "python.*bot.py" 2>/dev/null || true
                
                # Запуск бота
                log_message "${BLUE}🚀 Запуск бота...${NC}"
                supervisorctl start burncheckbot
                
                # Проверка статуса
                log_message "${BLUE}📊 Проверка статуса...${NC}"
                sleep 3
                supervisorctl status burncheckbot
                
                log_message "${GREEN}✅ Деплой завершен!${NC}"
                log_message "${BLUE}📝 Логи бота:${NC}"
                log_message "${BLUE}   - Стандартный вывод: tail -f /var/log/burncheckbot.out.log${NC}"
                log_message "${BLUE}   - Ошибки: tail -f /var/log/burncheckbot.err.log${NC}"
                log_message "${BLUE}🔄 Управление:${NC}"
                log_message "${BLUE}   - Статус: supervisorctl status burncheckbot${NC}"
                log_message "${BLUE}   - Перезапуск: supervisorctl restart burncheckbot${NC}"
                log_message "${BLUE}   - Остановка: supervisorctl stop burncheckbot${NC}"
                ;;
            killall)
                log_message "${YELLOW}💀 Принудительная очистка...${NC}"
                pkill -9 -f "python.*bot.py" 2>/dev/null || true
                rm -f bot.pid
                log_message "${GREEN}✅ Очистка завершена${NC}"
                ;;
            *)
                log_message "${RED}❌ Неизвестная команда: $command${NC}"
                show_help
                exit 1
                ;;
        esac
}

# Функция для удаленного управления
remote_management() {
    local command="$1"
    local server_ip="$2"
    local ssh_key="${3:-~/.ssh/id_rsa}"
    
    if [ -z "$server_ip" ]; then
        log_message "${RED}❌ Не указан IP сервера${NC}"
        show_help
        exit 1
    fi
    
    log_message "${YELLOW}🌐 Удаленное управление сервером $server_ip${NC}"
    
    # Проверка доступности сервера
    if ! ping -c 1 "$server_ip" > /dev/null 2>&1; then
        log_message "${RED}❌ Сервер $server_ip недоступен${NC}"
        exit 1
    fi
    
    # Проверка SSH ключа
    if [ ! -f "$ssh_key" ]; then
        log_message "${RED}❌ SSH ключ $ssh_key не найден${NC}"
        exit 1
    fi
    
    case "$command" in
        update)
            log_message "${BLUE}📥 Обновление бота на сервере...${NC}"
            ssh -i "$ssh_key" -o StrictHostKeyChecking=no root@"$server_ip" << 'EOF'
# Цвета для вывода на сервере
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_message() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

BOT_DIR="/root/burncheckbot-v2"

log_message "${YELLOW}📥 Обновление бота на сервере...${NC}"

# Переходим в директорию бота
cd "$BOT_DIR" || {
    log_message "${RED}❌ Директория $BOT_DIR не найдена${NC}"
    exit 1
}

# Останавливаем бота перед обновлением
log_message "${BLUE}🛑 Останавливаем бота для обновления...${NC}"
pkill -9 -f "python.*bot.py" 2>/dev/null || true
supervisorctl stop burncheckbot 2>/dev/null || true

# Обновляем код
log_message "${BLUE}📥 Обновление кода с git...${NC}"
git fetch origin
git reset --hard origin/main

# Обновляем зависимости
log_message "${BLUE}📚 Обновление зависимостей...${NC}"
source venv/bin/activate
pip install -r requirements.txt

# Делаем скрипт исполняемым (если существует)
if [ -f "bot_manager.sh" ]; then
    chmod +x bot_manager.sh
fi

# Запускаем бота
log_message "${BLUE}🚀 Запуск бота...${NC}"
if [ -f "bot_manager.sh" ]; then
    ./bot_manager.sh local start
else
    supervisorctl start burncheckbot
fi

log_message "${GREEN}✅ Обновление завершено${NC}"
EOF
            ;;
        deploy)
            log_message "${BLUE}🚀 Полный деплой бота на сервер...${NC}"
            ssh -i "$ssh_key" -o StrictHostKeyChecking=no root@"$server_ip" << 'EOF'
# Цвета для вывода на сервере
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_message() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

BOT_DIR="/root/burncheckbot-v2"

log_message "${YELLOW}🤖 Начинаем деплой бота на сервер...${NC}"

# Проверка наличия необходимых файлов (если уже есть проект)
if [ -d "$BOT_DIR" ]; then
    log_message "${BLUE}📁 Проект уже существует, обновляем...${NC}"
    cd "$BOT_DIR"
    
    # Останавливаем существующие процессы
    log_message "${BLUE}🛑 Останавливаем существующие процессы...${NC}"
    pkill -9 -f "python.*bot.py" 2>/dev/null || true
    supervisorctl stop burncheckbot 2>/dev/null || true
    
    # Обновляем код
    log_message "${BLUE}📥 Обновление кода с git...${NC}"
    git fetch origin
    git reset --hard origin/main
    
    # Обновляем зависимости
    log_message "${BLUE}📚 Обновление зависимостей...${NC}"
    source venv/bin/activate
    pip install -r requirements.txt
    
else
    log_message "${BLUE}📁 Создание нового проекта...${NC}"
    
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
    
    # Клонирование репозитория
    log_message "${BLUE}📥 Клонирование репозитория...${NC}"
    git clone https://github.com/GlebNutri/burncheckbot-v2.git .
    
    # Создание виртуального окружения
    log_message "${BLUE}🐍 Создание виртуального окружения...${NC}"
    python3 -m venv venv
    source venv/bin/activate
    
    # Установка зависимостей
    log_message "${BLUE}📚 Установка зависимостей Python...${NC}"
    pip install -r requirements.txt
    
    # Создание конфигурации Supervisor
    log_message "${BLUE}⚙️ Настройка автозапуска...${NC}"
    cat > /etc/supervisor/conf.d/burncheckbot.conf << SUPERVISOR_EOF
[program:burncheckbot]
command=$BOT_DIR/venv/bin/python $BOT_DIR/bot.py
directory=$BOT_DIR
user=root
autostart=true
autorestart=true
stderr_logfile=/var/log/burncheckbot.err.log
stdout_logfile=/var/log/burncheckbot.out.log
environment=PYTHONPATH="$BOT_DIR"
SUPERVISOR_EOF
    
    # Перезапуск Supervisor
    log_message "${BLUE}🔄 Перезапуск Supervisor...${NC}"
    supervisorctl reread
    supervisorctl update
fi

# Делаем скрипты исполняемыми
chmod +x bot_manager.sh bot_manager_unified.sh

# Запускаем бота через новый скрипт (если есть)
if [ -f "bot_manager.sh" ]; then
    log_message "${BLUE}🚀 Запуск бота через новый скрипт управления...${NC}"
    ./bot_manager.sh local start
else
    log_message "${BLUE}🚀 Запуск бота через supervisor...${NC}"
    supervisorctl start burncheckbot
fi

# Проверка статуса
log_message "${BLUE}📊 Проверка статуса...${NC}"
sleep 3

if [ -f "bot_manager.sh" ]; then
    ./bot_manager.sh local status
else
    supervisorctl status burncheckbot
fi

log_message "${GREEN}✅ Деплой завершен!${NC}"
log_message "${BLUE}📝 Логи бота:${NC}"
log_message "${BLUE}   - Стандартный вывод: tail -f /var/log/burncheckbot.out.log${NC}"
log_message "${BLUE}   - Ошибки: tail -f /var/log/burncheckbot.err.log${NC}"
log_message "${BLUE}🔄 Управление:${NC}"
if [ -f "bot_manager.sh" ]; then
    log_message "${BLUE}   - Статус: ./bot_manager.sh local status${NC}"
    log_message "${BLUE}   - Перезапуск: ./bot_manager.sh local restart${NC}"
    log_message "${BLUE}   - Остановка: ./bot_manager.sh local stop${NC}"
else
    log_message "${BLUE}   - Статус: supervisorctl status burncheckbot${NC}"
    log_message "${BLUE}   - Перезапуск: supervisorctl restart burncheckbot${NC}"
    log_message "${BLUE}   - Остановка: supervisorctl stop burncheckbot${NC}"
fi
EOF
            ;;
        status)
            log_message "${BLUE}📊 Статус бота на сервере...${NC}"
            ssh -i "$ssh_key" -o StrictHostKeyChecking=no root@"$server_ip" << 'EOF'
BOT_DIR="/root/burncheckbot-v2"
cd "$BOT_DIR" 2>/dev/null || {
    echo "❌ Директория $BOT_DIR не найдена"
    exit 1
}

if [ -f "bot_manager.sh" ]; then
    ./bot_manager.sh local status
else
    echo "📊 Статус бота:"
    if supervisorctl status burncheckbot 2>/dev/null | grep -q "RUNNING"; then
        echo "✅ Бот запущен"
        supervisorctl status burncheckbot
    else
        echo "❌ Бот не запущен"
    fi
fi
EOF
            ;;
        logs)
            log_message "${BLUE}📋 Логи бота на сервере...${NC}"
            ssh -i "$ssh_key" -o StrictHostKeyChecking=no root@"$server_ip" << 'EOF'
BOT_DIR="/root/burncheckbot-v2"
cd "$BOT_DIR" 2>/dev/null || {
    echo "❌ Директория $BOT_DIR не найдена"
    exit 1
}

if [ -f "bot_manager.sh" ]; then
    ./bot_manager.sh local logs
else
    echo "📋 Логи бота:"
    echo "📄 Последние 50 строк лога:"
    tail -n 50 output.log 2>/dev/null || echo "Файл лога не найден"
    echo ""
    echo "🔍 Supervisor логи:"
    echo "   Стандартный вывод: tail -f /var/log/burncheckbot.out.log"
    echo "   Ошибки: tail -f /var/log/burncheckbot.err.log"
fi
EOF
            ;;
        restart)
            log_message "${BLUE}🔄 Перезапуск бота на сервере...${NC}"
            ssh -i "$ssh_key" -o StrictHostKeyChecking=no root@"$server_ip" << 'EOF'
BOT_DIR="/root/burncheckbot-v2"
cd "$BOT_DIR" 2>/dev/null || {
    echo "❌ Директория $BOT_DIR не найдена"
    exit 1
}

if [ -f "bot_manager.sh" ]; then
    ./bot_manager.sh local restart
else
    echo "🔄 Перезапуск бота..."
    supervisorctl restart burncheckbot
    echo "✅ Перезапуск завершен"
fi
EOF
            ;;
        *)
            log_message "${RED}❌ Неизвестная команда: $command${NC}"
            show_help
            exit 1
            ;;
    esac
}

# Основная логика
case "$1" in
    local)
        local_management "$2"
        ;;
    remote)
        remote_management "$2" "$3" "$4"
        ;;
    *)
        show_help
        exit 1
        ;;
esac 