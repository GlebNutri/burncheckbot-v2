# 🤖 BurnCheck Bot

Телеграм-бот для диагностики выгорания с использованием научно обоснованной методики MBI-GS.

## 🚀 Быстрый старт

### Управление ботом

**Единый скрипт управления** - `bot_manager.sh`:

```bash
# Локальное управление (на сервере)
./bot_manager.sh local start      # Запустить бота
./bot_manager.sh local stop       # Остановить бота
./bot_manager.sh local restart    # Перезапустить бота
./bot_manager.sh local status     # Показать статус
./bot_manager.sh local logs       # Показать логи
./bot_manager.sh local update     # Обновить код с git
./bot_manager.sh local deploy     # Полный деплой

# Удаленное управление (с локального компьютера)
./bot_manager.sh remote update 123.456.789.012    # Обновить на сервере
./bot_manager.sh remote deploy 123.456.789.012    # Деплой на сервер
./bot_manager.sh remote status 123.456.789.012    # Статус на сервере
./bot_manager.sh remote logs 123.456.789.012      # Логи на сервере
```

### Первый деплой

```bash
# Подключитесь к серверу
ssh root@YOUR_SERVER_IP

# Клонируйте репозиторий
git clone https://github.com/GlebNutri/burncheckbot-v2.git
cd burncheckbot-v2

# Настройте переменные окружения
cp env_example.txt .env
nano .env  # Добавьте ваш BOT_TOKEN

# Запустите полный деплой
./bot_manager.sh local deploy
```

## 📁 Структура проекта

```
burncheckbot/
├── bot_manager.sh              # 🎯 ГЛАВНЫЙ скрипт управления
├── bot_manager_unified.sh      # Единый скрипт управления (на сервере)
├── bot.py                      # Основной код бота
├── config.py                   # Конфигурация
├── requirements.txt            # Зависимости Python
├── .env                        # Переменные окружения
├── evolventa/                  # Шрифты (TTF, OTF, WOFF)
│   ├── ttf/
│   ├── otf/
│   └── woff/
└── README.md                   # Эта документация
```

## 🔧 Настройка

### Переменные окружения

Создайте файл `.env` на основе `env_example.txt`:

```bash
BOT_TOKEN=your_telegram_bot_token_here
```

### Зависимости

```bash
pip install -r requirements.txt
```

## 🔒 Защита от дублирования

Система использует:
- **PID файлы** для отслеживания процессов
- **Lock файлы** для предотвращения одновременного запуска
- **Принудительную остановку** всех процессов перед запуском
- **Множественные проверки** статуса бота

## 📊 Мониторинг

### Логи
```bash
# Логи бота
./bot_manager.sh local logs

# Supervisor логи
tail -f /var/log/burncheckbot.out.log
tail -f /var/log/burncheckbot.err.log
```

### Статус
```bash
./bot_manager.sh local status
```

## 🚀 Деплой

### Автоматический деплой
```bash
# С локального компьютера
./bot_manager.sh remote deploy YOUR_SERVER_IP

# На сервере
./bot_manager.sh local deploy
```

### Ручной деплой
1. Подключитесь к серверу: `ssh root@YOUR_SERVER_IP`
2. Перейдите в директорию: `cd /root/burncheckbot-v2`
3. Запустите деплой: `./bot_manager.sh local deploy`

## 🔄 Обновление

### Автоматическое обновление
```bash
# С локального компьютера
./bot_manager.sh remote update YOUR_SERVER_IP

# На сервере
./bot_manager.sh local update
```

### Ручное обновление
```bash
git fetch origin
git reset --hard origin/main
./bot_manager.sh local restart
```

## 🛠️ Устранение неполадок

### Бот не запускается
```bash
# Проверка статуса
./bot_manager.sh local status

# Принудительная очистка
./bot_manager.sh local killall

# Попытка запуска
./bot_manager.sh local start
```

### Проблемы с обновлением
```bash
# Проверка git статуса
git status

# Принудительное обновление
git fetch origin
git reset --hard origin/main

# Перезапуск
./bot_manager.sh local restart
```

### Проблемы с supervisor
```bash
# Перезапуск supervisor
supervisorctl reread
supervisorctl update

# Проверка статуса
supervisorctl status burncheckbot
```

## 📞 Поддержка

При возникновении проблем:
1. Проверьте логи: `./bot_manager.sh local logs`
2. Проверьте статус: `./bot_manager.sh local status`
3. Попробуйте принудительную очистку: `./bot_manager.sh local killall`
4. Перезапустите бота: `./bot_manager.sh local restart`

## 📝 Лицензия

Проект использует шрифт Evolventa под лицензией GPL. 