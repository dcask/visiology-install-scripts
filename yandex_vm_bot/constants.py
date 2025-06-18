# api
FOLDERS_API_ENDPOINT = 'https://resource-manager.api.cloud.yandex.net/resource-manager/v1/folders'
INSTANCES_API_ENDPOINT = 'https://compute.api.cloud.yandex.net/compute/v1/instances'
TOKEN_AUD = 'https://iam.api.cloud.yandex.net/iam/v1/tokens'
# Период для прохода по облаку
DUE=300
# Файл с пользователями
USER_LIST_FILE = "users.json"
# Сообщения
ALARM_HEADER = '⚠ Истёк срок для следующих VM:\n'
USER_HAS_BEEN_DELETED = "✅ Пользователь удалён"
USER_NOT_IN_ACCESS_LIST = "⛔ Пользователя нет в списке"
USAGE_DELETE = "⛔ Использование: delete user-chat-id"
USAGE_CREATE = "⛔ Использование (укажите дату удаления): create name YYYY-MM-DD"
USAGE_SET = "⛔ Использование: set yandexVmId YYYY-MM-DD"
USAGE_ADD = "⛔ Использование: add user-chat-id name"
USER_EXISTS = "⛔ Пользователя уже добавлен"
USER_WARNING = "❗ Истёк срок для ВМ "
USER_HAS_BEEN_ADDED = "✅ Новый пользователь добавлен"
DATE_HAS_NOT_BEEN_SET = '⛔ Новая дата удаления не установлена. Причина: '
DATE_HAS_BEEN_ADDED = "✅ Новая дата удаления установлена"
VM_HAS_BEEN_CREATED = "✅ ВМ Создана : ip "
VM_HAS_NOT_BEEN_CREATED = "⛔ ВМ не былаСоздана по причине: "
VM_START_CREATING = "⏳ Создаю ВМ по указанным параметрам"
ACCESS_GRANTED = "✅ Доступ разрешён"
ADMIN_ONLY = "⛔ Амдинистративная функция"
ACCESS_DENIED = "⛔ Доступ запрещен! Ваш ID: "
CHOOSE_FOLDER = "Укажите папку, где создаётся ВМ"
#тип диска, размер диска, количество ядер, рам, доля цпу, oc
YANDEX_DISK_TYPE = [{"name":"HDD","id":"network-hdd"},{"name":"SSD","id":"network-ssd"}]
YANDEX_DISK_SIZE = ['50','100','200']
YANDEX_CORE_QUANTITY = ['2','4','8','16']
YANDEX_RAM_SIZE = ['4','8','16','32']
YANDEX_CPU_RATE = ['20','50','100']
YANDEX_OS_TYPE = [
    {"name":"Ubuntu24.4","id":"fd80j21lmqard15ciskf"},
    {"name":"RedOS7.3","id":"fd8av5nmo34m8d82fcpo"},
    {"name":"AstraLinux1.7 Воронеж","id":"fd8jiam0hiat341ef0fn"}]
YANDEX_PREEMTIBLE = [ 'Да', 'Нет']

DEFAULT_USERNAME="visio"
DEFAULT_ADMIN_USERNAME="visio-admin"