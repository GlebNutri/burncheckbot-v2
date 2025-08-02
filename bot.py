import logging
import os
from datetime import datetime
from dotenv import load_dotenv
from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup
from telegram.ext import (
    Application, CommandHandler, CallbackQueryHandler, ConversationHandler, MessageHandler, filters, ContextTypes
)
from telegram.error import BadRequest
from PIL import Image, ImageDraw, ImageFont
import io

from config import (
    BOT_TOKEN, TEST_QUESTIONS, SCORING_KEYS, THRESHOLDS, 
    INTERPRETATION, CHANNEL_USERNAME, CHANNEL_LINK, CHANNEL_NAME, 
    DISABLE_SUBSCRIPTION_CHECK
)

# Настройка логирования
import logging.handlers

# Создаем директорию для логов если её нет
log_dir = '/var/log/burncheckbot'
os.makedirs(log_dir, exist_ok=True)

# Настройка форматирования
formatter = logging.Formatter(
    '%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'
)

# Создаем логгер
logger = logging.getLogger(__name__)
logger.setLevel(logging.DEBUG)

# Очищаем существующие обработчики
logger.handlers.clear()

# Файловый обработчик для всех логов
file_handler = logging.handlers.RotatingFileHandler(
    f'{log_dir}/bot.log',
    maxBytes=10*1024*1024,  # 10MB
    backupCount=5,
    encoding='utf-8'
)
file_handler.setLevel(logging.DEBUG)
file_handler.setFormatter(formatter)
logger.addHandler(file_handler)

# Файловый обработчик только для ошибок
error_handler = logging.handlers.RotatingFileHandler(
    f'{log_dir}/bot_errors.log',
    maxBytes=5*1024*1024,  # 5MB
    backupCount=3,
    encoding='utf-8'
)
error_handler.setLevel(logging.ERROR)
error_handler.setFormatter(formatter)
logger.addHandler(error_handler)

# Консольный обработчик для отладки
console_handler = logging.StreamHandler()
console_handler.setLevel(logging.INFO)
console_handler.setFormatter(formatter)
logger.addHandler(console_handler)

# Логируем запуск
logger.info("🤖 Бот запускается...")
logger.info(f"Версия: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")

# Состояния разговора
ASK_NAME, CHOOSING_PHASE, ANSWERING_QUESTIONS, CHECKING_SUBSCRIPTION, SHOWING_RESULTS = range(5)

# Хранилище ответов пользователей
user_answers = {}

async def check_subscription(update: Update, context: ContextTypes.DEFAULT_TYPE) -> bool:
    """Проверка подписки пользователя на канал"""
    # Если проверка отключена, возвращаем True
    if DISABLE_SUBSCRIPTION_CHECK:
        return True
        
    try:
        user_id = update.effective_user.id
        
        # Убираем @ если есть в начале
        channel_username = CHANNEL_USERNAME.lstrip('@')
        
        logger.info(f"Проверяем подписку пользователя {user_id} в канале {channel_username}")
        
        # Пробуем разные варианты проверки
        try:
            # Сначала пробуем с @
            logger.info(f"Пробуем проверить с @{channel_username}")
            chat_member = await context.bot.get_chat_member(chat_id=f"@{channel_username}", user_id=user_id)
            logger.info(f"Статус пользователя: {chat_member.status}")
            return chat_member.status in ['member', 'administrator', 'creator']
        except Exception as e1:
            logger.warning(f"Ошибка при проверке с @: {e1}")
            try:
                # Пробуем без @
                logger.info(f"Пробуем проверить без @: {channel_username}")
                chat_member = await context.bot.get_chat_member(chat_id=channel_username, user_id=user_id)
                logger.info(f"Статус пользователя: {chat_member.status}")
                return chat_member.status in ['member', 'administrator', 'creator']
            except Exception as e2:
                logger.warning(f"Ошибка при проверке без @: {e2}")
                # Пробуем с числовым ID канала (если есть)
                try:
                    # Пробуем получить информацию о канале
                    chat_info = await context.bot.get_chat(f"@{channel_username}")
                    logger.info(f"Информация о канале: {chat_info.id}")
                    chat_member = await context.bot.get_chat_member(chat_id=chat_info.id, user_id=user_id)
                    logger.info(f"Статус пользователя: {chat_member.status}")
                    return chat_member.status in ['member', 'administrator', 'creator']
                except Exception as e3:
                    logger.warning(f"Ошибка при проверке по ID канала: {e3}")
                    logger.warning(f"Не удалось проверить подписку для пользователя {user_id} в канале {channel_username}")
                    logger.warning(f"Возможные причины:")
                    logger.warning(f"1. Бот не добавлен в канал как администратор")
                    logger.warning(f"2. Неправильный username канала: {channel_username}")
                    logger.warning(f"3. Канал не существует или приватный")
                    logger.warning(f"4. У бота нет прав на просмотр участников")
                    return True  # Временно разрешаем всем для тестирования
                
    except Exception as e:
        logger.error(f"Общая ошибка при проверке подписки: {e}")
        return True  # Временно разрешаем всем для тестирования

async def show_subscription_request(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    """Показ экрана с предложением подписаться на канал"""
    query = update.callback_query
    await query.answer()
    
    if DISABLE_SUBSCRIPTION_CHECK:
        # Если проверка отключена, сразу показываем результаты
        return await show_results(update, context)
    
    subscription_text = f"""
🎯 *Почти готово! Остался последний шаг*

📢 **Подпишитесь на наш канал** *"{CHANNEL_NAME}"*

💡 Там вы найдете:
• Мой личный опыт кризиса 30
• То что помогает мне жить жизнь без стресса
• Нейронки, которые облегчают мне жизнь
• Немного крипты

После подписки вы сразу получите результаты вашего теста!
"""
    
    keyboard = [
        [InlineKeyboardButton(f"📢 Подписаться на {CHANNEL_NAME}", url=CHANNEL_LINK)],
        [InlineKeyboardButton("✅ Я подписался, показать результаты", callback_data="check_subscription")],
        [InlineKeyboardButton("🔄 Пройти тест заново", callback_data="restart")]
    ]
    
    reply_markup = InlineKeyboardMarkup(keyboard)
    
    await query.edit_message_text(
        text=subscription_text,
        reply_markup=reply_markup,
        parse_mode='Markdown'
    )
    
    return CHECKING_SUBSCRIPTION

async def handle_subscription_check(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    """Обработка проверки подписки"""
    query = update.callback_query
    await query.answer()
    
    if query.data == "check_subscription":
        # Проверяем подписку
        is_subscribed = await check_subscription(update, context)
        
        if is_subscribed:
            # Пользователь подписан, показываем результаты
            return await show_results(update, context)
        else:
            # Пользователь не подписан
            error_text = f"""
⚠️ **Подписка не найдена**

Пожалуйста, убедитесь что вы:
1. Перешли по ссылке на канал
2. Нажали кнопку "Подписаться" 
3. Дождались подтверждения подписки

Затем нажмите "✅ Я подписался, показать результаты"

Если у вас возникли проблемы, попробуйте:
• Перезапустить Telegram
• Проверить интернет-соединение
• Обратиться в поддержку
"""
            
            keyboard = [
                [InlineKeyboardButton(f"📢 Подписаться на {CHANNEL_NAME}", url=CHANNEL_LINK)],
                [InlineKeyboardButton("✅ Я подписался, показать результаты", callback_data="check_subscription")],
                [InlineKeyboardButton("🔄 Пройти тест заново", callback_data="restart")]
            ]
            
            reply_markup = InlineKeyboardMarkup(keyboard)
            
            try:
                await query.edit_message_text(
                    text=error_text,
                    reply_markup=reply_markup,
                    parse_mode='Markdown'
                )
            except Exception as e:
                if "Message is not modified" in str(e):
                    # Игнорируем эту ошибку - сообщение уже правильное
                    pass
                else:
                    logger.error(f"Ошибка при редактировании сообщения: {e}")
            
            return CHECKING_SUBSCRIPTION
    elif query.data == "restart":
        # Используем логику перезапуска из restart_test
        user_id = update.effective_user.id
        
        # Очищаем предыдущие ответы
        if user_id in user_answers:
            del user_answers[user_id]
        
        welcome_text = """
🔬 *Диагностика уровня эмоционального выгорания*
*Автор: В.В. Бойко (1996)*

Этот тест поможет определить ваш уровень эмоционального выгорания по трем фазам:

 *Фазы выгорания:*

😰 **Напряжение** - Ты вроде держишься, но всё чаще ловишь себя на внутреннем напряге. Вроде ничего критичного, но внутри уже не спокойно. Раздражение, тревожность, недосказанная усталость — первые звоночки.

😤 **Резистенция** - Начинаешь закрываться. Всё и все начинают бесить. Притворяешься, что слушаешь, говоришь «окей» — и в мыслях выключаешься. Хочется просто доработать день и исчезнуть. Идеи, цели, смыслы — на паузе.

😵 **Истощение** - Всё. Пусто. Ни эмоций, ни сил. Утро начинается с вопроса: «Зачем всё это?». Ты просто существуешь на автомате. Энергии нет даже на удовольствие. Это не лень. Это ты выгорел.

Выберите фазу для тестирования:
"""
        
        keyboard = []
        for i, phase_data in enumerate(TEST_QUESTIONS):
            keyboard.append([InlineKeyboardButton(
                phase_data["phase"], 
                callback_data=f"phase_{i}"
            )])
        
        keyboard.append([InlineKeyboardButton("📊 Пройти полный тест", callback_data="full_test")])
        
        reply_markup = InlineKeyboardMarkup(keyboard)
        
        await query.edit_message_text(
            welcome_text,
            reply_markup=reply_markup,
            parse_mode='Markdown'
        )
        
        return CHOOSING_PHASE
    
    return CHECKING_SUBSCRIPTION

async def start(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    """Начало тестирования - приветствие и выбор фазы"""
    logger.info("=== ФУНКЦИЯ START ВЫЗВАНА ===")
    logger.info(f"Update type: {type(update)}")
    logger.info(f"Update message: {update.message}")
    logger.info(f"Update effective user: {update.effective_user}")
    
    user_id = update.effective_user.id
    logger.info(f"User ID: {user_id}")
    
    # Очищаем предыдущие ответы и данные пользователя
    if user_id in user_answers:
        logger.info(f"Удаляем старые ответы для пользователя {user_id}")
        del user_answers[user_id]
    
    # Очищаем сохраненные данные пользователя
    if 'full_name' in context.user_data:
        logger.info("Удаляем сохраненное имя")
        del context.user_data['full_name']
    if 'selected_test' in context.user_data:
        logger.info("Удаляем сохраненный выбор теста")
        del context.user_data['selected_test']
    
    logger.info("Переходим к выбору фазы")
    # Сразу показываем выбор фазы
    return await start_phase_selection(update, context)

async def ask_name(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    text = update.message.text.strip()
    parts = text.split()
    if len(parts) < 2:
        await update.message.reply_text("Пожалуйста, введите Фамилию и Имя через пробел.")
        return ASK_NAME
    
    # Делаем первую букву заглавной для каждого слова
    formatted_name = ' '.join(word.capitalize() for word in parts)
    context.user_data['full_name'] = formatted_name
    
    # Проверяем, есть ли сохраненный выбор теста
    if 'selected_test' in context.user_data:
        user_id = update.effective_user.id
        selected_test = context.user_data['selected_test']
        
        if selected_test == "full_test":
            # Инициализируем ответы для полного теста
            user_answers[user_id] = {
                "current_phase": 0,
                "current_question": 0,
                "answers": {},
                "full_test": True
            }
            return await start_questions(update, context)
        else:
            # Тестирование одной фазы
            phase_index = int(selected_test.split("_")[1])
            user_answers[user_id] = {
                "current_phase": phase_index,
                "current_question": 0,
                "answers": {},
                "full_test": False
            }
            return await start_questions(update, context)
    else:
        # Если нет сохраненного выбора, показываем выбор фазы
        return await start_phase_selection(update, context)

async def start_phase_selection(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    """Обработка выбора фазы тестирования или перехода к фазам после ввода имени"""
    logger.info("=== ФУНКЦИЯ START_PHASE_SELECTION ВЫЗВАНА ===")
    logger.info(f"Update имеет callback_query: {hasattr(update, 'callback_query') and update.callback_query}")
    logger.info(f"Update message: {update.message}")
    logger.info(f"Update type: {type(update)}")
    
    # Если вызов через CallbackQuery (кнопка), иначе через обычное сообщение
    if hasattr(update, 'callback_query') and update.callback_query:
        query = update.callback_query
        await query.answer()
        
        # Проверяем, что это выбор фазы, а не просто показ меню
        if query.data and (query.data.startswith("phase_") or query.data == "full_test"):
            user_id = update.effective_user.id
            
            # Проверяем, есть ли уже имя пользователя
            if 'full_name' not in context.user_data:
                # Сохраняем выбранную фазу и запрашиваем имя
                if query.data == "full_test":
                    context.user_data['selected_test'] = "full_test"
                else:
                    context.user_data['selected_test'] = f"phase_{query.data.split('_')[1]}"
                
                intro = (
                    "Напиши свое Фамилию и Имя, они нужны для генерации персонализированного подарка тебе за прохождение теста.\n"
                    "Мы не собираем и не храним твои данные.\n\n"
                    "Пожалуйста, введи Фамилию и Имя (например: Иванов Иван):"
                )
                await query.edit_message_text(intro)
                return ASK_NAME
            
            # Если имя уже есть, начинаем тест
            if query.data == "full_test":
                # Инициализируем ответы для полного теста
                user_answers[user_id] = {
                    "current_phase": 0,
                    "current_question": 0,
                    "answers": {},
                    "full_test": True
                }
                return await start_questions(update, context)
            else:
                # Тестирование одной фазы
                phase_index = int(query.data.split("_")[1])
                user_answers[user_id] = {
                    "current_phase": phase_index,
                    "current_question": 0,
                    "answers": {},
                    "full_test": False
                }
                return await start_questions(update, context)
        
        send_func = query.edit_message_text
    else:
        # Это обычное сообщение (например, команда /start)
        query = None
        send_func = update.message.reply_text
        logger.info("Обрабатываем обычное сообщение (не callback_query)")

    welcome_text = """
🔬 *Диагностика уровня эмоционального выгорания*


Этот тест создан на базе классической методики В.В. Бойко (1996), которая изначально разрабатывалась для оценки эмоционального выгорания у тех, кто работает с людьми.

Мы переписали её в живом, честном и понятном языке, ближе к тем, кому сейчас 27–35. Если ты чувствуешь усталость, апатию или просто не вывозишь — этот тест поможет понять, где ты находишься по шкале выгорания.:

 *Фазы выгорания:*

😰 **Напряжение** - Ты вроде держишься, но всё чаще ловишь себя на внутреннем напряге. Вроде ничего критичного, но внутри уже не спокойно. Раздражение, тревожность, недосказанная усталость — первые звоночки.

😤 **Резистенция** - Начинаешь закрываться. Всё и все начинают бесить. Притворяешься, что слушаешь, говоришь «окей» — и в мыслях выключаешься. Хочется просто доработать день и исчезнуть. Идеи, цели, смыслы — на паузе.

😵 **Истощение** - Всё. Пусто. Ни эмоций, ни сил. Утро начинается с вопроса: «Зачем всё это?». Ты просто существуешь на автомате. Энергии нет даже на удовольствие. Это не лень. Это ты выгорел.

Выбери подходящую для себя фазу или пройди полный тест:
"""
    keyboard = []
    for i, phase_data in enumerate(TEST_QUESTIONS):
        keyboard.append([InlineKeyboardButton(
            phase_data["phase"], 
            callback_data=f"phase_{i}"
        )])
    keyboard.append([InlineKeyboardButton("📊 Пройти полный тест", callback_data="full_test")])
    reply_markup = InlineKeyboardMarkup(keyboard)

    logger.info(f"Отправляем сообщение через: {send_func}")
    logger.info(f"Текст сообщения: {welcome_text[:100]}...")
    logger.info(f"Клавиатура: {keyboard}")
    
    try:
        await send_func(
            welcome_text,
            reply_markup=reply_markup,
            parse_mode='Markdown'
        )
        logger.info("Сообщение отправлено успешно")
    except BadRequest as e:
        logger.error(f"Ошибка BadRequest при отправке: {e}")
        if "Message is not modified" in str(e):
            # Игнорируем ошибку, если сообщение не изменилось
            logger.info("Игнорируем ошибку 'Message is not modified'")
            pass
        else:
            raise e
    except Exception as e:
        logger.error(f"Общая ошибка при отправке: {e}")
        raise e
    
    logger.info(f"Возвращаем состояние: {CHOOSING_PHASE}")
    return CHOOSING_PHASE

async def start_questions(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    """Начало вопросов выбранной фазы"""
    # Проверяем, есть ли callback_query (кнопка) или обычное сообщение
    if hasattr(update, 'callback_query') and update.callback_query:
        query = update.callback_query
        send_func = query.edit_message_text
    else:
        query = None
        send_func = update.message.reply_text
    
    user_id = update.effective_user.id
    
    phase_index = user_answers[user_id]["current_phase"]
    phase_data = TEST_QUESTIONS[phase_index]
    
    question_text = f"""
📝 *Тестирование фазы: {phase_data['phase']}*

Вопрос 1 из {len(phase_data['questions'])}:

{phase_data['questions'][0]}
"""
    
    keyboard = [
        [
            InlineKeyboardButton("✅ Согласен", callback_data="answer_1"),
            InlineKeyboardButton("❌ Не согласен", callback_data="answer_0")
        ]
    ]
    
    reply_markup = InlineKeyboardMarkup(keyboard)
    
    await send_func(
        text=question_text,
        reply_markup=reply_markup,
        parse_mode='Markdown'
    )
    
    return ANSWERING_QUESTIONS

async def handle_answer(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    """Обработка ответа на вопрос"""
    query = update.callback_query
    await query.answer()
    
    user_id = update.effective_user.id
    # Проверка формата callback_data
    if not query.data or not query.data.startswith("answer_"):
        await query.edit_message_text(
            text="⚠️ Произошла ошибка. Пожалуйста, начните тест заново с /start.",
            parse_mode='Markdown'
        )
        return ConversationHandler.END
    try:
        answer = int(query.data.split("_")[1])
    except (IndexError, ValueError):
        await query.edit_message_text(
            text="⚠️ Некорректный ответ. Пожалуйста, начните тест заново с /start.",
            parse_mode='Markdown'
        )
        return ConversationHandler.END
    
    # Сохраняем ответ
    phase_index = user_answers[user_id]["current_phase"]
    question_index = user_answers[user_id]["current_question"]
    
    if phase_index not in user_answers[user_id]["answers"]:
        user_answers[user_id]["answers"][phase_index] = {}
    
    user_answers[user_id]["answers"][phase_index][question_index] = answer
    
    # Переходим к следующему вопросу
    user_answers[user_id]["current_question"] += 1
    
    phase_data = TEST_QUESTIONS[phase_index]
    
    if user_answers[user_id]["current_question"] < len(phase_data['questions']):
        # Показываем следующий вопрос
        next_question = user_answers[user_id]["current_question"]
        question_text = f"""
📝 *Тестирование фазы: {phase_data['phase']}*

Вопрос {next_question + 1} из {len(phase_data['questions'])}:

{phase_data['questions'][next_question]}
"""
        
        keyboard = [
            [
                InlineKeyboardButton("✅ Согласен", callback_data="answer_1"),
                InlineKeyboardButton("❌ Не согласен", callback_data="answer_0")
            ]
        ]
        
        reply_markup = InlineKeyboardMarkup(keyboard)
        
        await query.edit_message_text(
            text=question_text,
            reply_markup=reply_markup,
            parse_mode='Markdown'
        )
        
        return ANSWERING_QUESTIONS
    else:
        # Завершили текущую фазу
        if user_answers[user_id]["full_test"] and phase_index < len(TEST_QUESTIONS) - 1:
            # Переходим к следующей фазе
            user_answers[user_id]["current_phase"] += 1
            user_answers[user_id]["current_question"] = 0
            return await start_questions(update, context)
        else:
            # Тест завершен, предлагаем подписаться на канал
            return await show_subscription_request(update, context)

async def show_results(update: Update, context: ContextTypes.DEFAULT_TYPE, generate_certificate_flag: bool = True) -> int:
    """Показ результатов тестирования"""
    # Определяем, откуда пришел запрос
    if hasattr(update, 'callback_query') and update.callback_query:
        query = update.callback_query
        user_id = update.effective_user.id
        edit_message = True
    else:
        # Прямой вызов (например, из handle_subscription_check)
        query = None
        user_id = update.effective_user.id
        edit_message = False
    
    results_text = "📊 *Результаты диагностики эмоционального выгорания*\n\n"
    
    total_score = 0
    phase_scores = {}
    completed_phases = 0
    
    # Подсчитываем баллы по фазам
    for phase_index, phase_data in enumerate(TEST_QUESTIONS):
        phase_name = phase_data["phase"]
        phase_answers = user_answers[user_id]["answers"].get(phase_index, {})
        
        score = 0
        questions_in_phase = len(phase_data["questions"])
        answered_questions = len(phase_answers)
        
        # Проверяем, пройдена ли фаза полностью
        if answered_questions == questions_in_phase:
            completed_phases += 1
            for question_index, answer in phase_answers.items():
                if answer == SCORING_KEYS[phase_name][question_index]:
                    score += 1
            
            phase_scores[phase_name] = score
            total_score += score
            
            # Определяем уровень для фазы
            if score <= THRESHOLDS[phase_name]["medium"]:
                level = "low"
            elif score <= THRESHOLDS[phase_name]["high"]:
                level = "medium"
            else:
                level = "high"
            
            results_text += f"🔸 *{phase_name}:* {score}/10 баллов\n"
            results_text += f"   {INTERPRETATION[phase_name][level]}\n\n"
        else:
            # Фаза не пройдена полностью
            results_text += f"🔸 *{phase_name}:* не пройдена\n\n"
    
    # Определяем тип тестирования
    is_full_test = user_answers[user_id].get("full_test", False)
    
    if is_full_test and completed_phases == 3:
        # Полный тест пройден
        results_text += f"📈 *Общий балл:* {total_score}/30\n\n"
        
        if total_score <= 15:
            results_text += "✅ *Общий результат:* Низкий уровень эмоционального выгорания"
        elif total_score <= 20:
            results_text += "⚠️ *Общий результат:* Средний уровень эмоционального выгорания"
        else:
            results_text += "🚨 *Общий результат:* Высокий уровень эмоционального выгорания"
    else:
        # Тестирование отдельных фаз
        if completed_phases == 1:
            # Пройдена только одна фаза
            phase_name = list(phase_scores.keys())[0]
            score = phase_scores[phase_name]
            results_text += f"📈 *Балл по фазе {phase_name}:* {score}/10\n\n"
            
            if score <= 3:
                results_text += f"✅ *Результат по фазе {phase_name}:* Низкий уровень"
            elif score <= 6:
                results_text += f"⚠️ *Результат по фазе {phase_name}:* Средний уровень"
            else:
                results_text += f"🚨 *Результат по фазе {phase_name}:* Высокий уровень"
        else:
            # Пройдено несколько фаз, но не все
            results_text += f"📈 *Общий балл по пройденным фазам:* {total_score}/{completed_phases * 10}\n\n"
            
            avg_score = total_score / completed_phases if completed_phases > 0 else 0
            if avg_score <= 3:
                results_text += "✅ *Средний результат:* Низкий уровень эмоционального выгорания"
            elif avg_score <= 6:
                results_text += "⚠️ *Средний результат:* Средний уровень эмоционального выгорания"
            else:
                results_text += "🚨 *Средний результат:* Высокий уровень эмоционального выгорания"
    
    results_text += "\n\n💡 *Рекомендации:*\n"
    
    # Определяем общий уровень для рекомендаций
    if is_full_test and completed_phases == 3:
        # Для полного теста используем общий балл
        recommendation_score = total_score
    else:
        # Для отдельных фаз используем средний балл
        recommendation_score = (total_score / completed_phases) * 3 if completed_phases > 0 else 0
    
    if recommendation_score > 20:
        results_text += "🚨 *Высокий уровень эмоционального выгорания:*\n"
        results_text += "Ты перегорел.\n"
        results_text += "Это уже не просто усталость. Выгорание влияет на тело, психику, интерес к жизни. Само не пройдёт. Нужно осознанно перезагружаться.\n\n"
        results_text += "Совет:\n"
        results_text += "Не дави на себя. Сейчас не время «взять себя в руки» — время поменять ритм и вложиться в восстановление. Новое знание, смена фокуса, простые переключения — всё это может стать спасением.\n\n"
        results_text += f"👉 В [{CHANNEL_NAME}]({CHANNEL_LINK}) я делюсь личным опытом, инструментами и мыслями, которые помогают выйти из этого состояния"
    elif recommendation_score > 15:
        results_text += "⚠️ *Средний уровень эмоционального выгорания:*\n"
        results_text += "Ты в зоне риска.\n"
        results_text += "Скорее всего, ты замечаешь раздражительность, усталость, прокрастинацию. Это не «просто лень» — это сигнал, что ты выдыхаешься.\n\n"
        results_text += "Совет:\n"
        results_text += "Остановись. Переключи внимание. Разгрузи голову — новыми темами, средой, впечатлениями. Иногда нужно не усилие, а выход из круга.\n\n"
        results_text += f"👉 В [{CHANNEL_NAME}]({CHANNEL_LINK}) я как раз об этом — как не потерять себя в выгорании, где брать энергию, как менять мышление. Залетай, это важно."
    else:
        results_text += "✅ *Низкий уровень эмоционального выгорания:*\n"
        results_text += "Ты держишься молодцом.\n"
        results_text += "Судя по результатам, ты пока не на грани — но не забывай: ресурс конечен. Даже если ты не выгораешь, усталость накапливается незаметно.\n\n"
        results_text += "Совет:\n"
        results_text += "Меняй контекст, пробуй новое, переключай внимание. Лучше отдыхать на опережение, чем потом собирать себя по кускам.\n\n"
        results_text += f"👉 Я пишу об этом в канале [{CHANNEL_NAME}]({CHANNEL_LINK}): как сохранять интерес, энергию и не закиснуть."
    
    # Добавляем предупреждение, если пройдены не все фазы
    if not is_full_test or completed_phases < 3:
        results_text += "\n\n⚠️ *Важно:*\n"
        results_text += "Ты прошёл только часть теста. Для более точной диагностики рекомендуется пройти полный тест из 30 вопросов.\n\n"
        results_text += "🔍 *Полный тест включает:*\n"
        results_text += "• 10 вопросов на фазу «Напряжение»\n"
        results_text += "• 10 вопросов на фазу «Резистенция»\n"
        results_text += "• 10 вопросов на фазу «Истощение»\n\n"
        results_text += "Это даст более точную картину твоего эмоционального состояния."
    
    keyboard = [
        [InlineKeyboardButton("🔄 Пройти тест заново", callback_data="restart")],
        [InlineKeyboardButton("ℹ️ О методике", callback_data="about")]
    ]
    
    reply_markup = InlineKeyboardMarkup(keyboard)
    
    if edit_message and query:
        await query.edit_message_text(
            text=results_text,
            reply_markup=reply_markup,
            parse_mode='Markdown'
        )
    else:
        # Отправляем новое сообщение
        await context.bot.send_message(
            chat_id=user_id,
            text=results_text,
            reply_markup=reply_markup,
            parse_mode='Markdown'
        )
    
    # Генерируем и отправляем грамоту только если это первый показ результатов
    if generate_certificate_flag:
        try:
            # Определяем уровень для грамоты
            if is_full_test and completed_phases == 3:
                if total_score <= 15:
                    level = "Маленький Пиздец"
                elif total_score <= 25:
                    level = "Средний Пиздец"
                else:
                    level = "Большой Пиздец"
            else:
                if completed_phases == 1:
                    score = list(phase_scores.values())[0]
                    if score <= 3:
                        level = "Маленький Пиздец"
                    elif score <= 6:
                        level = "Средний Пиздец"
                    else:
                        level = "Большой Пиздец"
                else:
                    avg_score = total_score / completed_phases if completed_phases > 0 else 0
                    if avg_score <= 3:
                        level = "Маленький Пиздец"
                    elif avg_score <= 6:
                        level = "Средний Пиздец"
                    else:
                        level = "Большой Пиздец"
            
            # Получаем имя пользователя из сохраненных данных или из профиля
            if 'full_name' in context.user_data:
                user_name = context.user_data['full_name']
            else:
                user_name = update.effective_user.first_name or "Пользователь"
                if update.effective_user.last_name:
                    user_name += f" {update.effective_user.last_name}"
            
            # Генерируем грамоту
            certificate_bytes = await generate_certificate(user_name, total_score, level, completed_phases)
            
            # Отправляем грамоту как изображение
            await context.bot.send_photo(
                chat_id=user_id,
                photo=certificate_bytes,
                caption="🏆 Ваша персональная грамота за прохождение теста! Сохрани её на память или поделись с друзьями."
            )
            
        except Exception as e:
            logger.error(f"Ошибка при генерации грамоты: {e}")
            # Если не удалось создать грамоту, просто продолжаем
    
    return SHOWING_RESULTS

async def restart_test(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    """Перезапуск тестирования"""
    query = update.callback_query
    await query.answer()
    
    user_id = update.effective_user.id
    
    # Очищаем предыдущие ответы и данные пользователя
    if user_id in user_answers:
        del user_answers[user_id]
    
    # Очищаем сохраненные данные пользователя
    if 'full_name' in context.user_data:
        del context.user_data['full_name']
    if 'selected_test' in context.user_data:
        del context.user_data['selected_test']
    
    welcome_text = """
🔬 *Диагностика уровня эмоционального выгорания*
*Автор: В.В. Бойко (1996)*

Этот тест поможет определить ваш уровень эмоционального выгорания по трем фазам:

 *Фазы выгорания:*

😰 **Напряжение** - Ты вроде держишься, но всё чаще ловишь себя на внутреннем напряге. Вроде ничего критичного, но внутри уже не спокойно. Раздражение, тревожность, недосказанная усталость — первые звоночки.

😤 **Резистенция** - Начинаешь закрываться. Всё и все начинают бесить. Притворяешься, что слушаешь, говоришь «окей» — и в мыслях выключаешься. Хочется просто доработать день и исчезнуть. Идеи, цели, смыслы — на паузе.

😵 **Истощение** - Всё. Пусто. Ни эмоций, ни сил. Утро начинается с вопроса: «Зачем всё это?». Ты просто существуешь на автомате. Энергии нет даже на удовольствие. Это не лень. Это ты выгорел.

Выберите фазу для тестирования:
"""
    
    keyboard = []
    for i, phase_data in enumerate(TEST_QUESTIONS):
        keyboard.append([InlineKeyboardButton(
            phase_data["phase"], 
            callback_data=f"phase_{i}"
        )])
    
    keyboard.append([InlineKeyboardButton("📊 Пройти полный тест", callback_data="full_test")])
    
    reply_markup = InlineKeyboardMarkup(keyboard)
    
    await query.edit_message_text(
        welcome_text,
        reply_markup=reply_markup,
        parse_mode='Markdown'
    )
    
    return CHOOSING_PHASE

async def about_method(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    """Информация о методике"""
    query = update.callback_query
    await query.answer()
    
    about_text = """
📚 *Об основе методики*

Этот тест создан на базе классической методики В.В. Бойко (1996), которая изначально разрабатывалась для оценки эмоционального выгорания у тех, кто работает с людьми.

Мы переписали её в живом, честном и понятном языке, ближе к тем, кому сейчас 27–35. Если ты чувствуешь усталость, апатию или просто не вывозишь — этот тест поможет понять, где ты находишься по шкале выгорания.

🧨 *Три фазы выгорания (переведено с научного на человеческий)*

1️⃣ **Напряжение** — ты постоянно на взводе, всё раздражает, даже мелочи. Внутри — тревога, усталость, чувство «я всё делаю не так».

2️⃣ **Резистенция** — начинается эмоциональный пофигизм. Люди бесят, общение утомляет, работа — как на автопилоте.

3️⃣ **Истощение** — просто пусто. Эмоции выжжены, хочется выключиться от всех. Даже простые вещи становятся неподъёмными.

📊 *Как читать результат:*

0–3 балла — фаза пока не ярко выражена

4–6 баллов — фаза формируется

7–10 баллов — фаза уже включена, пора принимать меры

*Источник:* В.В. Бойко, «Синдром эмоционального выгорания в профессиональном общении», 1996 (адаптировано под реальности 30-летних).
"""
    
    keyboard = [
        [InlineKeyboardButton("🔄 Пройти тест", callback_data="restart")],
        [InlineKeyboardButton("⬅️ Назад к результатам", callback_data="back_to_results")]
    ]
    
    reply_markup = InlineKeyboardMarkup(keyboard)
    
    await query.edit_message_text(
        text=about_text,
        reply_markup=reply_markup,
        parse_mode='Markdown'
    )
    
    return SHOWING_RESULTS

async def back_to_results(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    """Возврат к результатам"""
    query = update.callback_query
    await query.answer()
    
    return await show_results(update, context, generate_certificate_flag=False)

async def help_command(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    """Команда помощи"""
    help_text = """
🤖 *Команды бота:*

/start - Начать диагностику эмоционального выгорания
/help - Показать эту справку

📝 *Как использовать:*
1. Нажмите /start для начала тестирования
2. Выберите фазу или пройдите полный тест
3. Отвечайте на вопросы "Согласен" или "Не согласен"
4. Получите подробную интерпретацию результатов

💡 *Важно:* Отвечайте честно, как вы действительно себя чувствуете в последнее время.
"""
    
    await update.message.reply_text(help_text, parse_mode='Markdown')

# Глобальная переменная для хранения приложения
application = None





# Глобальный обработчик ошибок
async def error_handler(update, context):
    """Обработчик ошибок"""
    logger.error(f"Ошибка при обработке обновления {update}: {context.error}")
    
    if update and hasattr(update, 'message') and update.message:
        await update.message.reply_text("⚠️ Произошла непредвиденная ошибка. Попробуйте еще раз или начните с /start.")
    elif update and hasattr(update, 'callback_query') and update.callback_query:
        await update.callback_query.edit_message_text("⚠️ Произошла непредвиденная ошибка. Попробуйте еще раз или начните с /start.")

async def generate_certificate(user_name: str, total_score: int, level: str, completed_phases: int) -> bytes:
    """Генерация грамоты на основе PNG-шаблона"""
    from datetime import datetime
    import io
    from PIL import Image, ImageDraw, ImageFont

    # Открываем шаблон
    try:
        image = Image.open("certificate_template.png").convert("RGBA")
    except FileNotFoundError:
        logger.error("Файл certificate_template.png не найден!")
        raise FileNotFoundError("Файл certificate_template.png не найден в корне проекта")
    except Exception as e:
        logger.error(f"Ошибка при открытии файла сертификата: {e}")
        raise
    draw = ImageDraw.Draw(image)

    # Шрифты с приоритетом на Evolventa из папки проекта
    try:
        # Пробуем шрифт Evolventa из папки проекта
        font_nick = ImageFont.truetype("evolventa/ttf/Evolventa-Regular.ttf", 48)
        font_level = ImageFont.truetype("evolventa/ttf/Evolventa-Regular.ttf", 44)
        font_date = ImageFont.truetype("evolventa/ttf/Evolventa-Regular.ttf", 44)
        logger.info("Используется шрифт Evolventa из папки проекта")
    except:
        try:
            # Fallback на стандартные шрифты Linux (для сервера)
            font_nick = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 48)
            font_level = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 44)
            font_date = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 44)
            logger.info("Используется системный шрифт Linux")
        except:
            try:
                # Fallback на стандартные шрифты macOS
                font_nick = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 48)
                font_level = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 44)
                font_date = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 44)
                logger.info("Используется системный шрифт macOS")
            except:
                # Последний fallback - используем дефолтный шрифт
                font_nick = ImageFont.load_default()
                font_level = ImageFont.load_default()
                font_date = ImageFont.load_default()
                logger.warning("Используется дефолтный шрифт - Evolventa не найден")

    # Новые координаты для вставки текста
    nick_xy = (360, 610)         # Под надписью «Выдана»
    level_xy = (180, 1110)         # Под надписью «Уровень выгорания»
    date_xy = (300, 1270)          # Под надписью «Дата прохождения»

    # Формируем значения
    date_str = datetime.now().strftime('%d.%m.%Y')

    # Вставляем текст
    draw.text(nick_xy, user_name, font=font_nick, fill=(0,0,0))
    draw.text(level_xy, level, font=font_level, fill=(0,0,0))
    draw.text(date_xy, date_str, font=font_date, fill=(0,0,0))

    # Сохраняем в байты
    img_byte_arr = io.BytesIO()
    image.save(img_byte_arr, format='PNG')
    img_byte_arr.seek(0)
    return img_byte_arr.getvalue()

def main() -> None:
    """Запуск бота"""
    global application
    
    # Проверяем загрузку токена
    if not BOT_TOKEN or BOT_TOKEN == 'YOUR_BOT_TOKEN_HERE':
        logger.error("BOT_TOKEN не настроен! Проверьте переменные окружения.")
        return
    
    # Создаем приложение
    application = Application.builder().token(BOT_TOKEN).build()
    
    # Создаем обработчик разговора
    conv_handler = ConversationHandler(
        entry_points=[CommandHandler("start", start)],
        states={
            ASK_NAME: [MessageHandler(filters.TEXT & ~filters.COMMAND, ask_name)],
            CHOOSING_PHASE: [CallbackQueryHandler(start_phase_selection)],
            ANSWERING_QUESTIONS: [CallbackQueryHandler(handle_answer)],
            CHECKING_SUBSCRIPTION: [CallbackQueryHandler(handle_subscription_check)],
            SHOWING_RESULTS: [
                CallbackQueryHandler(restart_test, pattern="^restart$"),
                CallbackQueryHandler(about_method, pattern="^about$"),
                CallbackQueryHandler(back_to_results, pattern="^back_to_results$")
            ]
        },
        fallbacks=[CommandHandler("help", help_command)],
        per_chat=True,
        per_user=True,
        per_message=False
    )
    
    application.add_handler(conv_handler)
    application.add_handler(CommandHandler("help", help_command))
    application.add_error_handler(error_handler)
    
    # Запускаем бота
    print("🤖 Бот запущен! Нажмите Ctrl+C для остановки.")
    logger.info("Начинаем polling...")
    application.run_polling(drop_pending_updates=True)

if __name__ == '__main__':
    main() 