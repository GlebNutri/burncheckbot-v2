#!/bin/bash

# 🚀 Скрипт обновления бота на сервере
# Использование: ./server_update.sh [server_ip] [ssh_key_path]

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

# Проверка аргументов
if [ $# -lt 1 ]; then
    echo -e "${RED}❌ Ошибка: не указан IP сервера${NC}"
    echo -e "${YELLOW}Использование: $0 <server_ip> [ssh_key_path]${NC}"
    echo -e "${BLUE}Пример: $0 123.456.789.012 ~/.ssh/id_rsa${NC}"
    exit 1
fi

SERVER_IP="$1"
SSH_KEY="${2:-~/.ssh/id_rsa}"

log_message "${YELLOW}🚀 Начинаем обновление бота на сервере $SERVER_IP${NC}"

# Проверка доступности сервера
log_message "${BLUE}🔍 Проверка доступности сервера...${NC}"
if ! ping -c 1 "$SERVER_IP" > /dev/null 2>&1; then
    log_message "${RED}❌ Сервер $SERVER_IP недоступен${NC}"
    exit 1
fi

# Проверка SSH ключа
if [ ! -f "$SSH_KEY" ]; then
    log_message "${RED}❌ SSH ключ $SSH_KEY не найден${NC}"
    exit 1
fi

log_message "${GREEN}✅ Сервер доступен${NC}"

# Подключение к серверу и выполнение обновления
log_message "${BLUE}🔗 Подключение к серверу...${NC}"

ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no root@"$SERVER_IP" << 'EOF'
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

log_message "${YELLOW}🤖 Обновление бота на сервере...${NC}"

# Переходим в директорию бота
cd "$BOT_DIR" || {
    log_message "${RED}❌ Директория $BOT_DIR не найдена${NC}"
    exit 1
}

# Проверяем, есть ли единый скрипт управления
if [ ! -f "bot_manager_unified.sh" ]; then
    log_message "${YELLOW}⚠️ Единый скрипт управления не найден, используем старый метод...${NC}"
    
    # Останавливаем все процессы бота
    log_message "${BLUE}🛑 Останавливаем все процессы бота...${NC}"
    pkill -9 -f "python.*bot.py" 2>/dev/null || true
    pkill -9 -f "bot.py" 2>/dev/null || true
    supervisorctl stop burncheckbot 2>/dev/null || true
    
    # Обновляем код
    log_message "${BLUE}📥 Обновление кода с git...${NC}"
    git fetch origin
    git reset --hard origin/main
    
    # Обновляем зависимости
    log_message "${BLUE}📚 Обновление зависимостей...${NC}"
    source venv/bin/activate
    pip install -r requirements.txt
    
    # Запускаем бота
    log_message "${BLUE}🚀 Запуск бота...${NC}"
    nohup python3 bot.py > output.log 2>&1 &
    
    log_message "${GREEN}✅ Обновление завершено${NC}"
else
    log_message "${GREEN}✅ Единый скрипт управления найден${NC}"
    
    # Делаем скрипт исполняемым
    chmod +x bot_manager_unified.sh
    
    # Обновляем код с помощью единого скрипта
    log_message "${BLUE}📥 Обновление с помощью единого скрипта...${NC}"
    ./bot_manager_unified.sh update
    
    # Запускаем бота
    log_message "${BLUE}🚀 Запуск бота...${NC}"
    ./bot_manager_unified.sh start
    
    # Показываем статус
    log_message "${BLUE}📊 Статус бота:${NC}"
    ./bot_manager_unified.sh status
fi

log_message "${GREEN}✅ Обновление на сервере завершено!${NC}"
EOF

if [ $? -eq 0 ]; then
    log_message "${GREEN}✅ Обновление на сервере $SERVER_IP успешно завершено!${NC}"
else
    log_message "${RED}❌ Ошибка при обновлении на сервере $SERVER_IP${NC}"
    exit 1
fi

log_message "${BLUE}📋 Команды для управления ботом на сервере:${NC}"
echo -e "${BLUE}   Статус:${NC} ssh -i $SSH_KEY root@$SERVER_IP 'cd /root/burncheckbot-v2 && ./bot_manager_unified.sh status'"
echo -e "${BLUE}   Логи:${NC} ssh -i $SSH_KEY root@$SERVER_IP 'cd /root/burncheckbot-v2 && ./bot_manager_unified.sh logs'"
echo -e "${BLUE}   Перезапуск:${NC} ssh -i $SSH_KEY root@$SERVER_IP 'cd /root/burncheckbot-v2 && ./bot_manager_unified.sh restart'"
echo -e "${BLUE}   Остановка:${NC} ssh -i $SSH_KEY root@$SERVER_IP 'cd /root/burncheckbot-v2 && ./bot_manager_unified.sh stop'" 