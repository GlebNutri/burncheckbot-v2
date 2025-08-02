#!/bin/bash

# 📝 Удобные команды для просмотра логов бота
# Использование: ./log_commands.sh [команда]

LOG_DIR="/var/log/burncheckbot"
BOT_LOG="$LOG_DIR/bot.log"
ERROR_LOG="$LOG_DIR/bot_errors.log"

case "$1" in
    "all")
        echo "📋 Все логи бота:"
        cat "$BOT_LOG"
        ;;
    "errors")
        echo "❌ Логи ошибок:"
        cat "$ERROR_LOG"
        ;;
    "tail")
        echo "📊 Последние логи (в реальном времени):"
        tail -f "$BOT_LOG"
        ;;
    "tail-errors")
        echo "❌ Последние ошибки (в реальном времени):"
        tail -f "$ERROR_LOG"
        ;;
    "status")
        echo "📈 Статус бота:"
        supervisorctl status burncheckbot
        echo ""
        echo "📊 Размер файлов логов:"
        ls -lh "$LOG_DIR"/
        ;;
    "clear")
        echo "🧹 Очистка логов..."
        echo "" > "$BOT_LOG"
        echo "" > "$ERROR_LOG"
        echo "✅ Логи очищены"
        ;;
    "restart")
        echo "🔄 Перезапуск бота..."
        supervisorctl restart burncheckbot
        echo "✅ Бот перезапущен"
        ;;
    *)
        echo "📝 Команды для работы с логами:"
        echo ""
        echo "  ./log_commands.sh all          - Показать все логи"
        echo "  ./log_commands.sh errors       - Показать только ошибки"
        echo "  ./log_commands.sh tail         - Следить за логами в реальном времени"
        echo "  ./log_commands.sh tail-errors  - Следить за ошибками в реальном времени"
        echo "  ./log_commands.sh status       - Статус бота и размер логов"
        echo "  ./log_commands.sh clear        - Очистить логи"
        echo "  ./log_commands.sh restart      - Перезапустить бота"
        echo ""
        echo "📁 Логи находятся в: $LOG_DIR"
        ;;
esac 