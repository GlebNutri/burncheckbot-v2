#!/usr/bin/env python3
"""
Скрипт для проверки доступности шрифтов
"""

import os
from PIL import ImageFont

def check_fonts():
    """Проверяет доступность различных шрифтов"""
    
    fonts_to_check = [
        ("evolventa/ttf/Evolventa-Regular.ttf", "Evolventa из папки проекта"),
        ("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", "Системный Linux"),
        ("/System/Library/Fonts/Helvetica.ttc", "Системный macOS"),
    ]
    
    print("🔤 Проверка доступности шрифтов:")
    print("=" * 50)
    
    available_fonts = []
    
    for font_path, description in fonts_to_check:
        try:
            # Проверяем существование файла
            if os.path.exists(font_path):
                # Пробуем загрузить шрифт
                font = ImageFont.truetype(font_path, 12)
                print(f"✅ {description}: {font_path}")
                available_fonts.append((font_path, description))
            else:
                print(f"❌ {description}: файл не найден")
        except Exception as e:
            print(f"❌ {description}: ошибка загрузки - {e}")
    
    print("\n" + "=" * 50)
    
    if available_fonts:
        print(f"🎉 Найдено доступных шрифтов: {len(available_fonts)}")
        print(f"📝 Первый доступный: {available_fonts[0][1]}")
    else:
        print("⚠️ Доступных шрифтов не найдено, будет использован дефолтный")
    
    return available_fonts

if __name__ == "__main__":
    check_fonts() 