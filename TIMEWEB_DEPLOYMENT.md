# 🚀 Деплой бота на TimeWeb

## 📋 Подготовка к деплою

### 1. Подключение к серверу
```bash
ssh root@YOUR_SERVER_IP
```

### 2. Обновление системы
```bash
apt update && apt upgrade -y
```

### 3. Установка Python и зависимостей
```bash
apt install python3 python3-pip python3-venv git supervisor -y
```

## 🔧 Настройка проекта

### 1. Клонирование репозитория
```bash
cd /root
git clone https://github.com/GlebNutri/burncheckbot-v2.git
cd burncheckbot-v2
```

### 2. Создание виртуального окружения
```bash
python3 -m venv venv
source venv/bin/activate
```

### 3. Установка зависимостей
```bash
pip install -r requirements.txt
```

### 4. Настройка переменных окружения
```bash
cp env_example.txt .env
nano .env
```

В файле `.env` укажите ваш токен бота:
```
BOT_TOKEN=your_actual_bot_token_here
```

## 🎯 Настройка автозапуска через Supervisor

### 1. Создание конфигурации Supervisor
```bash
nano /etc/supervisor/conf.d/burncheckbot.conf
```

### 2. Добавьте следующую конфигурацию:
```ini
[program:burncheckbot]
command=/root/burncheckbot-v2/venv/bin/python /root/burncheckbot-v2/bot.py
directory=/root/burncheckbot-v2
user=root
autostart=true
autorestart=true
stderr_logfile=/var/log/burncheckbot.err.log
stdout_logfile=/var/log/burncheckbot.out.log
environment=PYTHONPATH="/root/burncheckbot-v2"
```

### 3. Перезапуск Supervisor
```bash
supervisorctl reread
supervisorctl update
supervisorctl start burncheckbot
```

## 📊 Управление ботом

### Проверка статуса
```bash
supervisorctl status burncheckbot
```

### Просмотр логов
```bash
tail -f /var/log/burncheckbot.out.log
tail -f /var/log/burncheckbot.err.log
```

### Перезапуск бота
```bash
supervisorctl restart burncheckbot
```

### Остановка бота
```bash
supervisorctl stop burncheckbot
```

## 🔄 Обновление кода

### 1. Остановка бота
```bash
supervisorctl stop burncheckbot
```

### 2. Обновление кода
```bash
cd /root/burncheckbot-v2
git pull origin main
```

### 3. Обновление зависимостей (если нужно)
```bash
source venv/bin/activate
pip install -r requirements.txt
```

### 4. Запуск бота
```bash
supervisorctl start burncheckbot
```

## 🛠️ Устранение неполадок

### Проверка процессов
```bash
ps aux | grep python
ps aux | grep bot.py
```

### Проверка портов
```bash
netstat -tlnp | grep python
```

### Убийство процессов (если нужно)
```bash
pkill -f "python.*bot.py"
```

### Проверка прав доступа
```bash
ls -la /root/burncheckbot-v2/
chmod +x /root/burncheckbot-v2/bot.py
```

## 📝 Важные замечания

1. **Безопасность**: Убедитесь, что файл `.env` не доступен публично
2. **Логи**: Регулярно проверяйте логи на наличие ошибок
3. **Обновления**: Регулярно обновляйте систему и зависимости
4. **Резервное копирование**: Делайте бэкапы конфигурации

## 🎉 Готово!

После выполнения всех шагов ваш бот будет автоматически запускаться при перезагрузке сервера и работать в фоновом режиме. 