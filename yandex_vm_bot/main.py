import configparser
import json
import logging

from telegram import Update
from telegram.ext import Application, CommandHandler, filters

import botHandlers
import constants

config = configparser.ConfigParser()
config.read("settings.ini")

# Данные из ini
BOT_TOKEN = config["TELEGRAM"]["botToken"]
botHandlers.YANDEX_USERDATA = config["YANDEX"]["userdata"]

# Загружаем пользователей
with open(constants.USER_LIST_FILE, "r", encoding="utf-8") as f:
    botHandlers.USER_CHAT_ID_DICT = json.load(f)

# Логгер
logging.basicConfig(
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    level=logging.INFO
)
logger = logging.getLogger(__name__)


def main() -> None:
    """Run the bot"""
    application = Application.builder().token(BOT_TOKEN).build()

    # Команды
    application.add_handler(CommandHandler("start", botHandlers.start, filters=~filters.ChatType.GROUP))
    application.add_handler(CommandHandler("add", botHandlers.add, filters=~filters.ChatType.GROUP))
    application.add_handler(CommandHandler("delete", botHandlers.delete, filters=~filters.ChatType.GROUP))
    application.add_handler(CommandHandler("set", botHandlers.set_date, filters=~filters.ChatType.GROUP))

    application.add_handler(botHandlers.creation_conv_handler)

    # Цикл
    application.run_polling(allowed_updates=Update.ALL_TYPES)


if __name__ == '__main__':
    main()
