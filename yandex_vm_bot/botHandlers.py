import json
import logging
import threading
from datetime import datetime

from telegram import InlineKeyboardButton, InlineKeyboardMarkup
from telegram import Update
from telegram.ext import CommandHandler, MessageHandler, filters
from telegram.ext import ContextTypes, ConversationHandler, CallbackQueryHandler

import constants
import helpFunctions
from yandexClass import YandexCloud

logger = logging.getLogger(__name__)

yandex_cloud = YandexCloud('', 'b1g3pabmir8kr1grc3or')
yandex_cloud.read_key("key.json")
yandex_cloud.create_iam_token(3600)
yandex_cloud.get_folders()

timer = threading.Timer(3550, yandex_cloud.create_iam_token(3600))

USER_CHAT_ID_DICT = {}
USERS_VM_CONFIG_STORAGE = {}
YANDEX_USERDATA = ''

NOT_CANCEL_PATTERN = "^(?!Отмена$).*"
# Константы состояний беседы
(FOLDER_STEP, OS_TYPE_STEP, DISK_TYPE_STEP, DISK_SIZE_STEP, CORE_QUANTITY_STEP,
 CPU_RATE_STEP, RAM_SIZE_STEP, PREEMTIBLE_STEP, DESC_STEP) = range(9)

###################################### Кнопки ###################################################
reply_keyboard = {}
markup = {}
# -----------------------------------Folder------------------------------------------------------
reply_keyboard[FOLDER_STEP] = [
    [InlineKeyboardButton(folder.get('name'), callback_data=folder.get('id'))] for folder in yandex_cloud.folders_list
]
# -----------------------------------OS------------------------------------------------------
reply_keyboard[OS_TYPE_STEP] = [
    [InlineKeyboardButton(os.get('name'), callback_data=os.get('id'))] for os in constants.YANDEX_OS_TYPE
]
# -----------------------------------disk type------------------------------------------------------
reply_keyboard[DISK_TYPE_STEP] = [
    [InlineKeyboardButton(dtype.get('name'), callback_data=dtype.get('id'))] for dtype in constants.YANDEX_DISK_TYPE
]
# -----------------------------------disk size------------------------------------------------------
reply_keyboard[DISK_SIZE_STEP] = [
    [InlineKeyboardButton(dsize, callback_data=dsize)] for dsize in constants.YANDEX_DISK_SIZE
]
# -----------------------------------Cores------------------------------------------------------
reply_keyboard[CORE_QUANTITY_STEP] = [
    [InlineKeyboardButton(quant, callback_data=quant)] for quant in constants.YANDEX_CORE_QUANTITY
]
# -----------------------------------CPU rate------------------------------------------------------
reply_keyboard[CPU_RATE_STEP] = [
    [InlineKeyboardButton(rate, callback_data=rate)] for rate in constants.YANDEX_CPU_RATE
]
# -----------------------------------RAM------------------------------------------------------
reply_keyboard[RAM_SIZE_STEP] = [
    [InlineKeyboardButton(rsize, callback_data=rsize)] for rsize in constants.YANDEX_RAM_SIZE
]
# -----------------------------------Preemtible------------------------------------------------------
reply_keyboard[PREEMTIBLE_STEP] = [
    [InlineKeyboardButton(yn, callback_data=yn)] for yn in constants.YANDEX_PREEMTIBLE
]

for r in reply_keyboard:
    reply_keyboard[r].append([InlineKeyboardButton("Отмена", callback_data='Отмена')])
    markup[r] = InlineKeyboardMarkup(reply_keyboard[r])


################################################################################################
# Bool функции
def is_user_admin(user_id: int) -> bool:
    return USER_CHAT_ID_DICT.get(str(user_id)) and USER_CHAT_ID_DICT[str(user_id)]['rights'] == 'admin'


def is_user_allowed(user_id: int) -> bool:
    return USER_CHAT_ID_DICT.get(str(user_id)) or is_user_admin(user_id)


# Декоратор доступа
def restrict(func):
    async def wrapper(update: Update, context: ContextTypes.DEFAULT_TYPE):
        chat_id = update.effective_user.id
        if not is_user_allowed(chat_id):
            await update.message.reply_text(constants.ACCESS_DENIED + str(chat_id))
            return
        return await func(update, context)

    return wrapper


# Декоратор админа
def admin_only(func):
    async def wrapper(update: Update, context: ContextTypes.DEFAULT_TYPE):
        chat_id = update.effective_user.id
        if not is_user_admin(chat_id):
            await update.message.reply_text(constants.ADMIN_ONLY)
            return
        return await func(update, context)

    return wrapper


# ****************************** Start **********************************
@restrict
async def start(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    """Start the bot"""
    chat_id = update.effective_message.chat_id
    logger.info(f"{chat_id} started the bot")
    await update.message.reply_text(constants.ACCESS_GRANTED)
    if is_user_admin(chat_id):
        context.job_queue.run_once(alarm, 1, chat_id=chat_id, name=str(chat_id), data=1)


# ****************************** alarm **********************************
async def alarm(context: ContextTypes.DEFAULT_TYPE) -> None:
    """Send the alarm message."""
    chat_id = context.job.chat_id
    current_jobs = context.job_queue.get_jobs_by_name(str(chat_id))

    if current_jobs:
        for job in current_jobs:
            job.schedule_removal()

    context.job_queue.run_once(alarm, constants.DUE, chat_id=chat_id, name=str(chat_id), data=constants.DUE)

    text, vm_list = yandex_cloud.get_finished_vms()

    for user in vm_list:
        warning = f'{constants.USER_WARNING} {user["name"]} {user["description"]}'
        await context.bot.send_message(chat_id=int(user['chat-id']), text=warning, parse_mode='MarkdownV2')

    if text:
        await context.bot.send_message(chat_id=chat_id, text=text, parse_mode='MarkdownV2')


# ****************************** Set **********************************
@admin_only
async def set_date(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    """Set new VM expire date """
    try:
        yandex_vm_id = context.args[0]
        end_date = datetime.strptime(context.args[1], '%Y-%m-%d').date()
    except ValueError:
        await update.message.reply_text(constants.USAGE_SET)
    except IndexError:
        await update.message.reply_text(constants.USAGE_SET)
    else:
        ok, txt = yandex_cloud.set_end_date_mark(yandex_vm_id, str(end_date))
        if ok:
            await update.message.reply_text(constants.DATE_HAS_BEEN_ADDED)
        else:
            await update.message.reply_text(f"{constants.DATE_HAS_NOT_BEEN_SET}:{txt}")


# ****************************** Add **********************************
@admin_only
async def add(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    """Add user to the access list"""
    try:
        new_user_id = context.args[0]
        new_user_name = context.args[1]
    except IndexError:
        await update.message.reply_text(constants.USAGE_ADD)
    else:
        USER_CHAT_ID_DICT[new_user_id] = {"name": new_user_name, "rights": "user"}
        with open(constants.USER_LIST_FILE, "w", encoding="utf-8") as f:
            json.dump(USER_CHAT_ID_DICT, f, indent=4, ensure_ascii=False)
        await update.message.reply_text(constants.USER_HAS_BEEN_ADDED)


# ****************************** Delete **********************************
@admin_only
async def delete(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    """Delete user from the access list"""
    try:
        del_user_id = context.args[0]
    except IndexError:
        await update.message.reply_text(constants.USAGE_DELETE)
    else:
        if USER_CHAT_ID_DICT.get(del_user_id):
            USER_CHAT_ID_DICT.pop(del_user_id)
            with open(constants.USER_LIST_FILE, "w", encoding="utf-8") as f:
                json.dump(USER_CHAT_ID_DICT, f, indent=4, ensure_ascii=False)
            await update.message.reply_text(constants.USER_HAS_BEEN_DELETED)
        else:
            await update.message.reply_text(constants.USER_NOT_IN_ACCESS_LIST)


# ****************************** Cancel **********************************
@restrict
async def cancel(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    """Cancels and ends the conversation."""
    query = update.callback_query
    await query.answer()
    await query.edit_message_text(
        "Создание ВМ прервано"
    )

    return ConversationHandler.END


# ****************************** Create **********************************
@restrict
async def create(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    """Create VM"""
    try:
        vm_name = context.args[0]
        end_date = datetime.strptime(context.args[1], '%Y-%m-%d').date()
    except ValueError:
        await update.message.reply_text(constants.USAGE_CREATE)
    except IndexError:
        await update.message.reply_text(constants.USAGE_CREATE)
    else:
        chat_id = update.effective_message.chat_id
        logger.info(f"{chat_id} suppose to create a VM")
        await update.message.reply_text(
            constants.CHOOSE_FOLDER,
            reply_markup=markup[FOLDER_STEP]
        )

        USERS_VM_CONFIG_STORAGE[str(chat_id)] = {
            'chat-id': str(chat_id),
            'owner': USER_CHAT_ID_DICT[str(chat_id)]["name"],
            'end-date': context.args[1],
            'name': vm_name,
            'userdata': YANDEX_USERDATA
        }

        return FOLDER_STEP
    return ConversationHandler.END


# ****************************** ASK FOLDER **********************************
async def ask_folder(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    """Ask for vm folder"""
    query = update.callback_query
    await query.answer()
    chat_id = update.effective_message.chat_id
    folder = query.data  # update.message.text
    USERS_VM_CONFIG_STORAGE[str(chat_id)]['folderId'] = folder
    await query.edit_message_text("Выберите ОС", reply_markup=markup[OS_TYPE_STEP])
    return OS_TYPE_STEP


# ****************************** ASK OS **********************************
async def ask_os(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    """Ask for vm OS"""
    chat_id = update.effective_message.chat_id
    query = update.callback_query
    await query.answer()
    os = query.data
    USERS_VM_CONFIG_STORAGE[str(chat_id)]['os'] = os
    await query.edit_message_text(f"Выберите тип диска", reply_markup=markup[DISK_TYPE_STEP])
    return DISK_TYPE_STEP


# ****************************** ASK DISK TYPE **********************************
async def ask_disk_type(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    """Ask for vm disk type"""
    chat_id = update.effective_message.chat_id
    query = update.callback_query
    await query.answer()
    disk_type = query.data
    USERS_VM_CONFIG_STORAGE[str(chat_id)]['disk-type'] = disk_type
    await query.edit_message_text(f"Выберите размер диска", reply_markup=markup[DISK_SIZE_STEP])
    return DISK_SIZE_STEP


# ****************************** ASK DISK SIZE **********************************
async def ask_disk_size(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    """Ask for vm disk size"""
    chat_id = update.effective_message.chat_id
    query = update.callback_query
    await query.answer()
    disk_size = query.data
    USERS_VM_CONFIG_STORAGE[str(chat_id)]['disk-size'] = disk_size
    await query.edit_message_text(f"Выберите количество ядер", reply_markup=markup[CORE_QUANTITY_STEP])
    return CORE_QUANTITY_STEP


# ****************************** ASK CORE QUANTITY **********************************
async def ask_cores(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    """Ask for vm cores"""
    chat_id = update.effective_message.chat_id
    query = update.callback_query
    await query.answer()
    cores = query.data
    USERS_VM_CONFIG_STORAGE[str(chat_id)]['cores'] = cores
    await query.edit_message_text(f"Выберите долю CPU", reply_markup=markup[CPU_RATE_STEP])
    return CPU_RATE_STEP


# ****************************** ASK CPU RATE **********************************
async def ask_cpu_rate(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    """Ask for vm cpu fraction"""
    chat_id = update.effective_message.chat_id
    query = update.callback_query
    await query.answer()
    core_fraction = query.data
    USERS_VM_CONFIG_STORAGE[str(chat_id)]['coreFraction'] = core_fraction
    await query.edit_message_text(f"Выберите объем RAM", reply_markup=markup[RAM_SIZE_STEP])
    return RAM_SIZE_STEP


# ****************************** ASK RAM SIZE **********************************
async def ask_ram(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    """Ask for vm ram"""
    chat_id = update.effective_message.chat_id
    query = update.callback_query
    await query.answer()
    ram = query.data
    USERS_VM_CONFIG_STORAGE[str(chat_id)]['ram'] = ram
    await query.edit_message_text(f"Прерываемая?", reply_markup=markup[PREEMTIBLE_STEP])
    return PREEMTIBLE_STEP


# ****************************** ASK PREEMTIBLE **********************************
async def ask_preemptible(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    """Ask for vm preemptible"""
    chat_id = update.effective_message.chat_id
    query = update.callback_query
    await query.answer()
    preemptible = query.data
    USERS_VM_CONFIG_STORAGE[str(chat_id)]['preemptible'] = True if preemptible == 'Да' else False
    await query.edit_message_text(f"Введите описание")
    return DESC_STEP


# ****************************** ASK DESCRIPTION **********************************
async def ask_description(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    """Ask for vm description"""
    chat_id = update.effective_message.chat_id
    text = update.message.text
    USERS_VM_CONFIG_STORAGE[str(chat_id)]['description'] = text
    await update.message.reply_text(f'{constants.VM_START_CREATING}')
    ok, ip = yandex_cloud.create_vm(USERS_VM_CONFIG_STORAGE[str(chat_id)])

    if ok:
        password = helpFunctions.connect_and_change_password(ip, constants.DEFAULT_USERNAME)
        await update.message.reply_text(
            f'{constants.VM_HAS_BEEN_CREATED} {ip} Username: {constants.DEFAULT_USERNAME} Password: {password}')

        for user in USER_CHAT_ID_DICT:
            if USER_CHAT_ID_DICT[user]['rights'] == 'admin' and user != str(chat_id):
                await update.get_bot().send_message(chat_id=user,
                                                    text=f'{USER_CHAT_ID_DICT[str(chat_id)]["name"]} создал новую VM {USERS_VM_CONFIG_STORAGE[str(chat_id)]['name']}')
    else:
        await update.message.reply_text(f'{constants.VM_HAS_NOT_BEEN_CREATED} {ip}')

        logger.error('VM creation error : %s', ip)
    return ConversationHandler.END


########################################################################## Ручка для беседы при создании ВМ
creation_conv_handler = ConversationHandler(
    entry_points=[CommandHandler("create", create)],
    states={
        FOLDER_STEP: [
            CallbackQueryHandler(ask_folder, NOT_CANCEL_PATTERN)
        ],
        OS_TYPE_STEP: [
            CallbackQueryHandler(ask_os, NOT_CANCEL_PATTERN)
        ],
        DISK_TYPE_STEP: [
            CallbackQueryHandler(ask_disk_type, NOT_CANCEL_PATTERN)
        ],
        DISK_SIZE_STEP: [
            CallbackQueryHandler(ask_disk_size, NOT_CANCEL_PATTERN)
        ],
        CORE_QUANTITY_STEP: [
            CallbackQueryHandler(ask_cores, NOT_CANCEL_PATTERN)
        ],
        CPU_RATE_STEP: [
            CallbackQueryHandler(ask_cpu_rate, NOT_CANCEL_PATTERN)
        ],
        RAM_SIZE_STEP: [
            CallbackQueryHandler(ask_ram, NOT_CANCEL_PATTERN)
        ],
        PREEMTIBLE_STEP: [
            CallbackQueryHandler(ask_preemptible, NOT_CANCEL_PATTERN)
        ],
        DESC_STEP: [
            MessageHandler(
                filters.TEXT & ~(filters.COMMAND | filters.Regex("^Отмена$")),
                ask_description,
            )
        ]
    },
    fallbacks=[CallbackQueryHandler(cancel, pattern='Отмена')],
)
