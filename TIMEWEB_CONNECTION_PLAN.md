# 🚀 План подключения к TimeWeb серверу

## 📋 Варианты подключения

### 1. **Прямое SSH подключение (Рекомендуется)**
```bash
ssh root@YOUR_SERVER_IP
```

### 2. **Через SSH ключ (Более безопасно)**
```bash
ssh -i ~/.ssh/your_private_key root@YOUR_SERVER_IP
```

### 3. **Через GitHub Actions (Автоматизация)**
Использование `appleboy/ssh-action` для автоматического деплоя

## 🔧 Подготовка к подключению

### Шаг 1: Получение данных сервера
- **IP адрес сервера** (от TimeWeb)
- **Логин** (обычно `root`)
- **Пароль** или **SSH ключ**
- **Порт SSH** (обычно `22`)

### Шаг 2: Проверка доступности сервера
```bash
ping YOUR_SERVER_IP
telnet YOUR_SERVER_IP 22
```

### Шаг 3: Генерация SSH ключа (опционально)
```bash
ssh-keygen -t ed25519 -a 200 -C "your_email@example.com"
```

## 🎯 Пошаговый план деплоя

### Этап 1: Подключение и базовая настройка
```bash
# 1. Подключение к серверу
ssh root@YOUR_SERVER_IP

# 2. Обновление системы
apt update && apt upgrade -y

# 3. Установка необходимых пакетов
apt install python3 python3-pip python3-venv git supervisor curl wget -y
```

### Этап 2: Клонирование и настройка проекта
```bash
# 1. Переход в домашнюю директорию
cd /root

# 2. Клонирование репозитория
git clone https://github.com/GlebNutri/burncheckbot-v2.git
cd burncheckbot-v2

# 3. Создание виртуального окружения
python3 -m venv venv
source venv/bin/activate

# 4. Установка зависимостей
pip install -r requirements.txt
```

### Этап 3: Настройка переменных окружения
```bash
# 1. Копирование примера конфигурации
cp env_example.txt .env

# 2. Редактирование файла с токеном
nano .env
```

**Содержимое .env:**
```
BOT_TOKEN=8363984382:AAHxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

### Этап 4: Настройка автозапуска через Supervisor
```bash
# 1. Создание конфигурации
nano /etc/supervisor/conf.d/burncheckbot.conf
```

**Содержимое конфигурации:**
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

```bash
# 2. Перезапуск Supervisor
supervisorctl reread
supervisorctl update
supervisorctl start burncheckbot
```

## 🤖 Автоматический деплой через скрипт

### Вариант 1: Загрузка и запуск скрипта
```bash
# 1. Подключение к серверу
ssh root@YOUR_SERVER_IP

# 2. Скачивание скрипта
wget https://raw.githubusercontent.com/GlebNutri/burncheckbot-v2/main/deploy_timeweb.sh

# 3. Создание .env файла с токеном
echo "BOT_TOKEN=8363984382:AAHxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx" > .env

# 4. Запуск скрипта
chmod +x deploy_timeweb.sh
./deploy_timeweb.sh
```

### Вариант 2: GitHub Actions автоматизация
Создать `.github/workflows/deploy.yml`:

```yaml
name: Deploy to TimeWeb
on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Deploy to server
        uses: appleboy/ssh-action@v1
        with:
          host: ${{ secrets.HOST }}
          username: ${{ secrets.USERNAME }}
          key: ${{ secrets.KEY }}
          port: ${{ secrets.PORT }}
          script: |
            cd /root/burncheckbot-v2
            git pull origin main
            source venv/bin/activate
            pip install -r requirements.txt
            supervisorctl restart burncheckbot
```

## 📊 Мониторинг и управление

### Проверка статуса
```bash
supervisorctl status burncheckbot
```

### Просмотр логов
```bash
# Стандартный вывод
tail -f /var/log/burncheckbot.out.log

# Ошибки
tail -f /var/log/burncheckbot.err.log
```

### Управление ботом
```bash
# Перезапуск
supervisorctl restart burncheckbot

# Остановка
supervisorctl stop burncheckbot

# Запуск
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

### Убийство процессов
```bash
pkill -f "python.*bot.py"
```

### Проверка прав доступа
```bash
ls -la /root/burncheckbot-v2/
chmod +x /root/burncheckbot-v2/bot.py
```

## 🔐 Безопасность

### Настройка SSH ключей
```bash
# На локальной машине
ssh-keygen -t ed25519 -a 200 -C "your_email@example.com"

# Копирование ключа на сервер
ssh-copy-id root@YOUR_SERVER_IP
```

### Настройка firewall
```bash
# Установка UFW
apt install ufw

# Настройка правил
ufw allow ssh
ufw allow 22
ufw enable
```

## 📝 Чек-лист деплоя

- [ ] Получен IP адрес сервера
- [ ] Проверена доступность сервера
- [ ] Подключение по SSH работает
- [ ] Система обновлена
- [ ] Установлены необходимые пакеты
- [ ] Репозиторий склонирован
- [ ] Виртуальное окружение создано
- [ ] Зависимости установлены
- [ ] Файл .env настроен с токеном
- [ ] Supervisor настроен
- [ ] Бот запущен
- [ ] Логи проверены
- [ ] Бот отвечает в Telegram

## 🎉 Готово!

После выполнения всех шагов ваш бот будет:
- ✅ Автоматически запускаться при перезагрузке сервера
- ✅ Работать в фоновом режиме
- ✅ Логироваться в файлы
- ✅ Управляться через supervisorctl 