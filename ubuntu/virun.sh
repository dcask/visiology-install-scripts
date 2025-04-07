#!/bin/bash
# Help script for Visiology 2&3 https://github.com/dcask/visiology-install-scripts/ubuntu/virun.sh
# place it at /var/lib/visiology/scripts

#2.41&3.12
# Defaults
declare -a true_false=( "Включить" "Выключить" )
V2=v2
V3=v3
ALL=all
TRUE=true
FALSE=false
CHANGE_URL=${FALSE}

MAGENTA=$(tput setaf 5)
BLUE=$(tput setaf 4)
GREEN=$(tput setaf 3)
NORMAL=$(tput sgr0)

BACK="0. Назад ---------------------------------------"
EXIT="0. Выход ---------------------------------------"
PRESS_ANY_KEY="..Нажмите любую клавишу для возврата в меню ----------"
NEED_RESTART="При изменении требуется выполнить перезапуск (корневой пункт меню 1)"
NEED_RECONF="При изменении требуется выполнить переконфигурацию (корневой пункт меню 8)"

PROXY_SERVICE=reverse-proxy

execute_start_row=25
munu_start_position=8
config_start_col=80

# Platform settings
configEnvPath="./config.env"
configV3EnvPath="./v3/config.env"
configV2EnvPath="./v2/config.env"
defaultsV3EnvPath="./v3/defaults.env"
configsV3dirPath="./v3/configs/"
V3_EXTENDED_SERVICES_DIR="./v3/extended-services"
vdV3EnvPath="./v3/env-files/vd.env"
RELATIVE_PATH=/v3
CERTS_DIR="../certs/"
UTILS_DIR="./v3/utils"
V3_DIR="./v3/"
CHECKSUM_FILE=".distrib-checksum"
FORCE_CHANGE_URL_FILE=./v3/.changeurlflag

################################ clear buffer
function clear_buffer {
  while read -t 0.1 -rn1 _; do
    :
  done
}
function logo {
  local area_text=()

  area_text+=("____   ____.__       .__       .__                       ")
  area_text+=("\   \ /   /|__| _____|__| ____ |  |   ____   ____ ___.__.")
  area_text+=(" \   Y   / |  |/  ___/  |/  _ \|  |  /  _ \ / ___<   |  |")
  area_text+=("  \     /  |  |\___ \|  (  <_> )  |_(  <_> ) /_/  >___  |")
  area_text+=("   \___/   |__/____  >__|\____/|____/\____/\___  // ____|")
  area_text+=("                   \/                     /_____/ \/     ")

  row=${1:-1}

  for line in "${area_text[@]}"; do
    tput cup "${row}" "${2:-1}"
    printf "${line}"
    ((++row))
  done
}
function make_check_sum {
  find -type f \( -name '*.yml' -or -name '*.sh' -or -name '*.ym_' \) \
     \( -not -name ".*checksum*" \) \
     \( -not -path "./extended-services/*" \) \
     \( -not -path "./v3/extended-services/*" \) \
      -exec md5sum '{}' \; > ${CHECKSUM_FILE}
}
################################ Show menu part
function select_option {
  local left_shift=5
  local last_row
  local start_row
  local selected
  options=("$@")
  IFS=$'\n' opt_sorted=($(sort <<<"${options[*]}"));unset IFS


  cursor_norm()      { tput cnorm; }
  cursor_invisible() { tput civis; }
  cursor_to()        { tput cup "${1:-0}" "${2:-0}"; }
  print_option()     { printf "   $1 "; }
  print_selected()   { tput smso; printf "   $1 "; tput rmso; }
  get_cursor_row()   { IFS=';' read -rsdR -p $'\E[6n' ROW COL; echo ${ROW#*[}; }
  key_input()        { read -rsn1 key
                       case "$key" in
                         $'\x1b')
                           read -rsn2 -t 0.1 tmp
                           case "$tmp" in
                               "[A") echo up;;
                               "[B") echo down;;
                           esac
                           clear_buffer
                           ;;
                         "") echo enter
                           ;;
                       esac
                     }

  for options; do printf "\n"; done

  while true; do
    last_row=$(get_cursor_row)

    if [[ "${last_row}" =~ ^[0-9]+$ ]]; then break; fi

  done

  start_row=$((last_row - ${#options[@]}))
  selected=0
  stty -echo
  cursor_invisible
  trap "cursor_norm; stty echo; printf '\n'; exit" 2

  while true; do
    local idx=0

    for ind in "${!opt_sorted[@]}"; do
      cursor_to $(( start_row + idx)) ${left_shift}

      if [[ ${idx} -eq ${selected} ]]; then
        print_selected "${opt_sorted[${ind}]}"
      else
        print_option "${opt_sorted[${ind}]}"
      fi

      ((idx++))
    done

    case $(key_input) in
      enter) break;;
      up) ((selected--)); if [[ ${selected} -lt 0 ]]; then selected=$(($# - 1)); fi;;
      down) ((selected++)); if [[ ${selected} -ge $# ]]; then selected=0; fi;;
    esac
  done

  cursor_to "${last_row}" 0
  printf "\n"
  cursor_norm
  stty echo

  idx=0

  for options; do
    if [[ "${opt_sorted[${selected}]}" == "${options}" ]]; then
      return ${idx}
    fi
    (( idx++))
  done

  return 255
}

#Sub function to return selected menu
function select_opt {
  select_option "$@" 1>&2
  local result=$?
  echo ${result}
  return ${result}
}
#Esc menu
function esc_menu {
  tput cup ${execute_start_row} 0; tput cud1

  set -o emacs
  bind '"\C-w": kill-whole-line'
  bind '"\e": "\C-w\C-d"'
  bind '"\e\e": "\C-w\C-d"'
  IFS= read -rep "(Esc оставить без изменения) $1" || {
    printf '\nБез изменений\n'
    read -st 1 -n 1000000
    return 1
  }
  echo $REPLY
}
function true_false_menu {
  local false_true_selected_opt
  false_true_selected_opt=$(select_opt "${true_false[@]}")
  opt_type=${FALSE}

  if [[ "${false_true_selected_opt}" == "0" ]]; then
    opt_type=${TRUE}
  fi

  echo ${opt_type}
}

function env_read_and_set {
  [[ -z "$4" ]] || tput cup ${execute_start_row} 0
  tput cud1
  local result=0
  read -rp "$1" tmp

  local until_mark='.*$'

  if [[ -n "$4" ]]; then
    until_mark="$4"
  fi

  if [[ -n "${tmp}" ]]; then
    sed -i -E "s/^$2=${until_mark}/$2=${tmp}/" $3
    result=1
  fi

  return ${result}
}


function xml_read_and_set {
  [[ -z "$4" ]] || tput cup ${execute_start_row} 0
  tput cud1
  local result=0
  read -rp "$1" tmp

  if [[ -n "${tmp}" ]]; then
    sed -i -E "s/\<$2\>.*\</\<$2\>${tmp}\</" $3
    result=1
  fi

  return ${result}
}

################################ Show platform settings
function print_config_env {
  source ${configEnvPath}
  version="${V2_TAG} & ${V3_TAG}"

  case ${START_VERSION} in
    "${V2}")
      version=${V2_TAG};
      ;;
    "${V3}")
      version=${V3_TAG}
      ;;
  esac

  proxy_container_id=$(docker ps -f status=running | grep ${PROXY_SERVICE} |  awk '{ print $1 }');

  area_text=()

  if [[ -n "${proxy_container_id}" ]]; then
    area_text+=("\xb2 Платформа ${GREEN}запущена${NORMAL}")
  fi

  area_text+=("\xb2 Адрес платформы: ${PLATFORM_IP}")
  area_text+=("\xb2 SSL: ${HTTPS}")
  area_text+=("\xb2 Версии для запуска: ${version}")
  area_text+=("\xb2 Порт для нешифрованного соединения: ${PLATFORM_HTTP_PORT}")
  area_text+=("\xb2 Порт для шифрованного соединения: ${PLATFORM_HTTPS_PORT}")

  if [[ "${SAMEORIGIN}" == "${TRUE}" ]]; then
    area_text+=("\xb2 Запретить встраивать iframe на сторонние сайты: ${SAMEORIGIN}")
  fi

  area_text+=("\xb2 Имя файла пароля сертификата: ${CERT_PASS_FILENAME:-без пароля}")
  area_text+=("\xb2 Имя файла сертификата: ${CERT_CRT_FILENAME}")
  area_text+=("\xb2 Имя файла приватного ключа: ${CERT_KEY_FILENAME}")

  if [[ "${START_VERSION}" == "${V3}" || "${START_VERSION}" != "${V2}" ]]; then
    source ${configV3EnvPath}
    source ${defaultsV3EnvPath}

    #area_text+=("\xb2 ${BLUE}Опции памяти для JDBC bridge${NORMAL}: ${JDBC_BRIDGE_MEM_OPTIONS}")
    area_text+=("\xb2 ${BLUE}Внутренний мониторинг ${V3_TAG}${NORMAL}: ${INTERNAL_MONITORING}")
    #area_text+=("\xb2 ${BLUE}Опции памяти для Keycloak${NORMAL}: ${KEYCLOAK_MEM_OPTIONS}")

    if [[ "${FSTEC}" == "${TRUE}" ]]; then
      area_text+=("\xb2 ${BLUE}Защита админки Keycloak${NORMAL}: ${FSTEC}")
    fi

    if [[ ${LOKI_IS_TIME_UNLIMITED} == "${FALSE}" ]]; then
      area_text+=("\xb2 ${BLUE}Время ротации логов Loki${NORMAL}: ${LOKI_RETENTION_TIME}")
    else
      area_text+=("\xb2 ${BLUE}Не ротировать логи Loki${NORMAL}: ${LOKI_IS_TIME_UNLIMITED}")
    fi

    if [[ ${EXT_AUTH} == "${TRUE}" ]]; then
      area_text+=("\xb2 ${BLUE}Внешний Keycloak${NORMAL}: ${EXT_AUTH}")
    fi

    area_text+=("\xb2 ${BLUE}Подпапка запуска ${V3_TAG}${NORMAL}: ${RELATIVE_PATH}")

    if [[ "${CLICKHOUSE_MEMORY_LIMIT}" != "0" ]]; then
      area_text+=("\xb2 ${BLUE}Ограничение памяти Clickhouse${NORMAL}: ${CLICKHOUSE_MEMORY_LIMIT} bytes")
    else
      area_text+=("\xb2 ${BLUE}Коэффициент ограничение памяти Clickhouse${NORMAL}: $CLICKHOUSE_MEMORY_LIMIT_RATIO")
    fi
  fi

  if [[ "${START_VERSION}" == "${V2}" || "${START_VERSION}" != "${V3}" ]]; then
    source ${configV2EnvPath}
    area_text+=("\xb2 ${MAGENTA}Рабочая папка ${V2_TAG}${NORMAL}: ${DOCKER_VOLUME_FOLDER}")

    if [[ ${WITH_SEQ} == "${TRUE}" ]]; then
      area_text+=("\xb2 ${MAGENTA}SEQ активен${NORMAL}: ${WITH_SEQ}")
    fi

    if [[ ${WITH_VITALK} == "${TRUE}" ]]; then
      area_text+=("\xb2 ${MAGENTA}ViTalk активен${NORMAL}: ${WITH_VITALK}")
    fi

    if [[ ${POLICY} != "off" ]]; then
      area_text+=("\xb2 ${MAGENTA}Режим повышенной безопасности активен${NORMAL}: ${POLICY}")
    fi

    if [[ ${REMOTE_VIQUBE} == "${TRUE}" ]]; then
      area_text+=("\xb2 ${MAGENTA}Удалённый ViQube активен${NORMAL}: ${REMOTE_VIQUBE}")
    fi

    if [[ ${REMOTE_SF} == "${TRUE}" ]]; then
      area_text+=("\xb2 ${MAGENTA}Удалённый Smart-Forms активен${NORMAL}: ${REMOTE_SF}")
    fi
  fi

  row=${1:-1}

  for line in "${area_text[@]}"; do
    tput cup "${row}" "${2:-1}"
    printf "${line}"
    ((++row))
  done
}

##################### menu declaration ######################### begin
declare -A menu3
declare -A menu4
declare -A menu5
declare -A menu6
declare -A menu

menu[menu0]="1. Запустить/Перезапустить платформу"
menu[menu1]="2. Остановить платформу"
menu[menu2]="3. Ввести лицензионный ключ v3"
menu[menu3]="4. Изменить параметры запуска .."
menu[menu4]="5. Изменить настройки платформы .."
menu[menu5]="6. Диагностика .."
menu[menu6]="7. Бэкап/восстановление .."
menu[menu7]="8. Подготовить конфигурацию стенда"
menu[menu9]="9. Выпустить самоподписанный сертификат"
menu[menu8]="${EXIT}"

menu3[menu31]="1. Изменить порт"
menu3[menu32]="2. Изменить адрес"
menu3[menu33]="3. Включить/выключить SSL"
menu3[menu34]="${BACK}"
menu3[menu35]="4. Версии для запуска"
menu3[menu36]="5. Подпапка для запуска V3"

menu4[menu416]="01. Включить адрес в docker dns"
menu4[menu402]="02. Установить SSL сертификаты"
menu4[menu403]="03. Создать кластер Clickhouse"
menu4[menu406]="04. Запретить/Разрешить встраивать iframe на сторонние сайты"
menu4[menu407]="05. Отключение/Включение мониторинга"
menu4[menu408]="06. Отключение/Включение защиты Keycloak"
menu4[menu409]="0${BACK}"
menu4[menu410]="07. Отключение/Включение внешнего Keycloak"
menu4[menu411]="08. Ускорение запросов к Clickhouse"
menu4[menu412]="09. Изменение времени ротации логов Loki"
menu4[menu413]="10. Изменении предельного размера таблицы для удаления в Clickhouse"
menu4[menu414]="11. Изменение таймаута Http запроса для Clickhouse"
menu4[menu415]="12. Изменение временной зоны Clickhouse"
menu4[menu417]="13. Добавить драйвер БД"
menu4[menu418]="14. Настройка почты"
menu4[menu419]="15. Настройка сетевой папки"

menu5[menu53]="1. Сбор логов"
menu5[menu51]="${BACK}"
menu5[menu52]="2. Запущенные сервисы"
menu5[menu54]="3. Системная информация"
menu5[menu55]="4. Docker stats"
menu5[menu56]="5. Docker info (просмотр less. 'q' - Выход)"
menu5[menu57]="6. Сеть"
menu5[menu58]="7. Проверка целостности (просмотр less. 'q' - Выход)"

menu6[menu62]="1. Бэкап"
menu6[menu61]="2. Восстановление"
menu6[menu63]="${BACK}"

############################################################### end

######################### menu action ########################## begin

# Platform stop
function menu1 {
  /bin/bash run.sh --stop

  if [[ $? -eq 0 ]]; then
    return 1
  fi
}
# Platform restart
function menu0 {
  if [[ "${CHANGE_URL}" == "${TRUE}" ]]; then
    /bin/bash run.sh --restart -c
    CHANGE_URL=${FALSE}
  else
    /bin/bash run.sh --restart
  fi

  if [[ $? -eq 0 ]]; then
    return 1
  fi
}
# Licence
function menu2 {
  tput cup ${execute_start_row} 0; tput cud1
  read -rp "Укажите ключ ( пусто - без изменений):" licence_key

  if [[ -n "${licence_key}" ]]; then
    /bin/bash ./${V3}/prepare-config.sh -l "${licence_key}"
  fi
  
  echo "${NEED_RESTART}"
}
########### menu3
# Get port
function menu31 {
  while true; do
    tput cup ${execute_start_row} 0; tput cud1
    printf "После указания нового значения порта автоматически последует перезапуск платформы\n"
    read -rp "Порт запуска (0 оставить без изменения): " port

    if [[ ${port} -lt 0 || ${port} -gt 65535 ]]; then
      echo "Wrong port number: ${port}"
    else
      break
    fi
  done

  if [[ ${port} -ne 0 ]]; then
    /bin/bash run.sh --restart -c --port ${port}
  fi

  if [[ $? -eq 0 ]]; then
    return 1
  fi
}
# Get address
function menu32 {
  env_read_and_set "Корневой адрес запуска платформы ( пусто - без изменений): " "PLATFORM_IP" ${configEnvPath} "[^:]*"
  local result=$?

  if [[ $result -eq 1 ]]; then
    CHANGE_URL=${TRUE}
  fi
  
  echo "${NEED_RESTART}"
}
# Enable/disable SSL
function menu33 {
  opt_http=$(true_false_menu)
  source ${configEnvPath}

  sed -i -E "s/^HTTPS=.*$/HTTPS=${opt_http}/" ${configEnvPath}

  if [[ "${HTTPS}" == "${TRUE}" && "${opt_http}" == "${FALSE}" ]] || [[ "${HTTPS}" == "${FALSE}" && "${opt_http}" == "${TRUE}" ]]; then
    CHANGE_URL=${TRUE}
  fi
  
  echo "${NEED_RESTART}"
}
# Switch versions
function menu35 {
  tput cup ${execute_start_row} 0; tput cud1
  source ${configEnvPath}
  versions=("${V2_TAG}" "${V3_TAG}" "${V2_TAG} & ${V3_TAG}")
  version_selected_opt=$(select_opt "${versions[@]}")
  start_version=${ALL}

  case "${version_selected_opt}" in
    "0")
      start_version=${V2}
      ;;
    "1")
      start_version=${V3}
      ;;
  esac

  sed -i -E "s/^START_VERSION=.*$/START_VERSION=${start_version}/" ${configEnvPath}
  echo "${NEED_RESTART}"
}
# Subfolder
function menu36 {
  source ${configEnvPath}
  tput cup ${execute_start_row} 0; tput cud1
  printf "После указания нового значения подпапки автоматически последует перезапуск платформы\n"

  set -o emacs
  bind '"\C-w": kill-whole-line'
  bind '"\e": "\C-w\C-d"'
  bind '"\e\e": "\C-w\C-d"'
  IFS= read -rep "(Esc оставить без изменения) ${PLATFORM_IP}/" || {
    printf '\nБез изменений\n'
    read -st 1 -n 1000000
    return 1
  }

  /bin/bash run.sh --restart -s $REPLY
}
########### menu4

# Get certs
function menu402 {
  tput cup ${execute_start_row} 0; tput cud1
  read -rp "Путь до файла сертификата (пусто - без изменений): " crt_path
  tput cud1
  read -rp "Путь до файла приватного ключа (пусто - без изменений): " key_path
  tput cud1
  read -rp "Путь до файла пароля (пусто - без пароля): " pas_path

  if [[ -n "${crt_path}" ]]; then
    cp "${crt_path}" ${CERTS_DIR}
    crt_name=$(basename "${crt_path}")
    sed -i -E "s/^CERT_CRT_FILENAME=.*$/CERT_CRT_FILENAME=${crt_name}/" ${configEnvPath}
  fi

  if [[ -n "${key_path}" ]]; then
    cp "${key_path}" ${CERTS_DIR}
    key_name=$(basename "${key_path}")
    sed -i -E "s/^CERT_KEY_FILENAME=.*$/CERT_KEY_FILENAME=${key_name}/" ${configEnvPath}
  fi

  if [[ -n "${pas_path}" ]]; then
    cp "${pas_path}" ${CERTS_DIR}
    pass_name=$(basename "${key_path}")
    sed -i -E "s/^CERT_PASS_FILENAME=.*$/CERT_PASS_FILENAME=${pass_name}/" ${configEnvPath}
  fi
  
  echo "${NEED_RESTART}"
}
# Loki type
function menu401 {
  opt_type=$(true_false_menu)
  /bin/bash ${V3_DIR}prepare-config.sh --is-loki-time-unlimite ${opt_type}
  echo "${NEED_RESTART}"
}
# Docker dns
function menu416 {
  source ${configEnvPath}
  tput cup ${execute_start_row} 0; tput cud1
  echo $(cat "${V3_EXTENDED_SERVICES_DIR}/35-extrahosts.yml" | grep '\- \"' )
  read -rp "IP для ${PLATFORM_IP} (пусто - без изменений): " ip

  if [[ -n "${ip}" ]]; then
    if [[ -f "${V3_EXTENDED_SERVICES_DIR}/35-extrahosts.ym_" ]]; then
      mv "${V3_EXTENDED_SERVICES_DIR}/35-extrahosts.ym_" "${V3_EXTENDED_SERVICES_DIR}/35-extrahosts.yml"
    fi

    if [[ -f "${V3_EXTENDED_SERVICES_DIR}/35-extrahosts.yml" ]]; then
      sed -i -E "s/-\s+\".+:.+\"$/- \"${PLATFORM_IP}:${ip}\"/" "${V3_EXTENDED_SERVICES_DIR}/35-extrahosts.yml"
    else
      printf "\nФайл с extrahost не найден"
    fi
  fi
  
  echo "${NEED_RESTART}"
}
# Clickhouse cluster
function menu403 {
  /bin/bash ${UTILS_DIR}/make_ch_fast_loading.sh
  /bin/bash ${UTILS_DIR}/make_ch_cluster.sh
  echo "${NEED_RESTART}"
}
# sameorigin
function menu406 {
  source ${configEnvPath}
  printf "SAMEORIGIN=%s\n" ${SAMEORIGIN}
  opt_type=$(true_false_menu)
  sed -i -E "s/^SAMEORIGIN=.*$/SAMEORIGIN=${opt_type}/" ${configEnvPath}
  echo "${NEED_RESTART}"
}
# Monitoring
function menu407 {
  source ${configV3EnvPath}
  printf "INTERNAL_MONITORING=%s\n" ${INTERNAL_MONITORING}
  opt_type=$(true_false_menu)
  /bin/bash ${V3_DIR}prepare-config.sh --monitoring ${opt_type}
  echo "${NEED_RESTART}"
}
# Fstec
function menu408 {
  source ${configV3EnvPath}
  printf "FSTEC=%s\n" ${FSTEC}
  opt_type=$(true_false_menu)
  /bin/bash ${V3_DIR}prepare-config.sh --fstec ${opt_type}
  echo "${NEED_RESTART}"
}
# Ext keycloak
function menu410 {
  source ${configV3EnvPath}
  printf "EXT_AUTH=%s\n" ${EXT_AUTH}
  opt_type=$(true_false_menu)
  /bin/bash ${V3_DIR}prepare-config.sh --ext-auth ${opt_type}
  echo "${NEED_RESTART}"
}
# Fast loading
function menu411 {
  /bin/bash ${UTILS_DIR}/make_ch_fast_loading.sh
  echo "${NEED_RESTART}"
}
# Loki time
function menu412 {
  source ${defaultsV3EnvPath}
  printf "LOKI_RETENTION_TIME=%s" ${LOKI_RETENTION_TIME}
  env_read_and_set "Время ротации логов ( пусто - без изменений): " "LOKI_RETENTION_TIME" ${defaultsV3EnvPath}
  echo "${NEED_RESTART}"
}
# drop limit
function menu413 {
  xml_path=${configsV3dirPath}clickhouse-disable-drop-limits.xml
  echo $(cat "${xml_path}" | grep 'max_table_size_to_drop' )
  echo $(cat "${xml_path}" | grep 'max_partition_size_to_drop' )
  xml_read_and_set "max_table_size_to_drop ( пусто - без изменений): " "max_table_size_to_drop" ${xml_path}
  xml_read_and_set "max_partition_size_to_drop ( пусто - без изменений): " "max_partition_size_to_drop" ${xml_path}
  echo "${NEED_RECONF}"
}
# timeout
function menu414 {
  xml_path=${configsV3dirPath}clickhouse-http-receive-timeout.xml
  echo $(cat "${xml_path}" | grep 'http_max_field_value_size' )
  echo $(cat "${xml_path}" | grep 'http_receive_timeout' )
  xml_read_and_set "http_max_field_value_size ( пусто - без изменений): " "http_max_field_value_size" ${xml_path}
  xml_read_and_set "http_receive_timeout ( пусто - без изменений): " "http_receive_timeout" ${xml_path}
  echo "${NEED_RECONF}"
}
# time zone
function menu415 {
  xml_path=${configsV3dirPath}clickhouse-timezone.xml
  echo $(cat "${xml_path}" | grep 'timezone' )
  xml_read_and_set "timezone ( пусто - без изменений): " "timezone" ${xml_path}
  echo "${NEED_RECONF}"
}
# Driver
function menu417 {
  driver_file=${V3_EXTENDED_SERVICES_DIR}/01-drivers.yml
  tput cup ${execute_start_row} 0; tput cud1
  read -rp "Путь к файлу драйвера: " file_path

  if [[ -n "${file_path}" ]]; then
    file_name=$(basename ${driver_file})

    if [[ ! -f "${driver_file}" ]]; then
      echo 'version: "3.8"' > ${driver_file}
      echo "services:" >> ${driver_file}
      echo "  jdbc-bridge-1:" >> ${driver_file}
      echo "    volumes:" >> ${driver_file}
      echo "      - ${driver_file}:/app/drivers/${file_name}" >> ${driver_file}
    else
      echo "      - ${driver_file}:/app/drivers/${file_name}" >> ${driver_file}
    fi
  fi
  
  echo "${NEED_RESTART}"
}
# Mail server
function menu418 {
  tput cup ${execute_start_row} 0; tput cud1
  proxy_container_id=$(docker ps -f status=running | grep ${PROXY_SERVICE} |  awk '{ print $1 }');

  if [[ -n "${proxy_container_id}" ]]; then
    echo "Для продолжения необходимо остановить платформу. Продолжить?"
    yes_no=("Да" "Нет")
    false_true_selected_opt=$(select_opt "${yes_no[@]}")
    opt_type=${FALSE}

    if [[ "${false_true_selected_opt}" == "1" ]]; then
      return 1
    fi

    /bin/bash run.sh --stop
  fi

  source ${vdV3EnvPath}
  source ${configV3EnvPath}

  DS_EMAIL_SECRETS_LABEL=${PROJECT}_ds_email

  printf "_____________Текущие параметры___________\n"
  printf "Адрес почтового сервера: ${MAGENTA}%s${NORMAL}\n" ${DS_EMAIL_HOST}
  printf "Порт почтового сервера: ${MAGENTA}%s${NORMAL}\n" ${Mail__Port}
  printf "Email: ${MAGENTA}%s${NORMAL}\n" ${DS_EMAIL_EMAIL}
  printf "Количество повторов отправлений: ${MAGENTA}%s${NORMAL}\n" ${Mail__RetrySendCount}
  printf "Тип безопасного соединения: ${MAGENTA}%s${NORMAL}\n" ${Mail__ConnectionSecurity}
  printf "________________________________________\n"

  env_read_and_set "Адрес почтового сервера ( пусто - без изменений): " "DS_EMAIL_HOST" ${vdV3EnvPath}
  env_read_and_set "Email ( пусто - без изменений): " "DS_EMAIL_EMAIL" ${vdV3EnvPath}

  if [[ -z "${Mail__Port}" ]]; then
    echo "Mail__Port=465" >> ${vdV3EnvPath}
  fi

  if [[ -z "${Mail__RetrySendCount}" ]]; then
    echo "Mail__RetrySendCount=3" >> ${vdV3EnvPath}
  fi

  if [[ -z "${Mail__ConnectionSecurity}" ]]; then
    echo "Mail__ConnectionSecurity=SslOnConnect" >> ${vdV3EnvPath}
  fi



  env_read_and_set "Порт почтового сервера ( пусто - без изменений): " "Mail__Port" ${vdV3EnvPath}
  env_read_and_set "Количество повторов отправлений ( пусто - без изменений): " "Mail__RetrySendCount" ${vdV3EnvPath}
  env_read_and_set "Тип безопасного соединения ( пусто - без изменений): " "Mail__ConnectionSecurity" ${vdV3EnvPath}

  tput cud1
  read -rp "Логин (пусто - без изменений): " ds_email_login

  if [[ -n "${ds_email_login}" ]]; then
    docker secret rm DS_EMAIL_LOGIN && \
    echo -n "${ds_email_login}" | docker secret create -l ${DS_EMAIL_SECRETS_LABEL}=login DS_EMAIL_LOGIN -
  fi

  tput cud1
  read -rp "Пароль (пусто - без изменений): " ds_email_password

  if [[ -n "${ds_email_password}" ]]; then
    docker secret rm DS_EMAIL_PASSWORD && \
    echo -n "${ds_email_password}" | docker secret create -l ${DS_EMAIL_SECRETS_LABEL}=password DS_EMAIL_PASSWORD -
  fi
  
  echo "${NEED_RESTART}"
}
# Net folder
function menu419 {
  tput cup ${execute_start_row} 0; tput cud1
  read -rp "Путь к папке. (Например //192.168.23.127/BusinessData): " folder_path
  tput cud1
  read -rp "Имя пользователя, который имеет доступ к этой папке: " username
  tput cud1
  read -rp "Пароль пользователя, который имеет доступ к этой папке: " password

  if [[ -z $(docker volume ls | grep cif-volume) ]]; then
    docker volume create --driver local --opt type=cifs --opt device="${folder_path}" \
    --opt "o=username=${username},password=${password},file_mode=0777,dir_mode=0777" --name cif-volume
  fi

  if [[ ! -f "${V3_EXTENDED_SERVICES_DIR}/01-net-folder.ym_" ]]; then
    mv ${V3_EXTENDED_SERVICES_DIR}/01-net-folder.ym_ ${V3_EXTENDED_SERVICES_DIR}/01-net-folder.yml
    echo "${NEED_RESTART}"
  fi
}
########### menu5
# Services
function menu52 {
  printf "Replicas\tName\n"
  docker service ls --format '{{ $v := split .Replicas "/" }}{{ slice $v 0 1 }}\t{{ .Name }}'
}
# Logs
function menu53 {
  source ${configEnvPath}

  case "${START_VERSION}" in
    "${V2}"|"${ALL}")
      /bin/bash ${UTILS_DIR}/get_logs.sh -critzj -s 60m -v v2
      ;;
    "${V3}"|"${ALL}")
      /bin/bash ${UTILS_DIR}/get_logs.sh -critzj -s 60m -v v3
      ;;
  esac
}
# Sys info
function menu54 {
  echo "########### OS"
  cat /etc/*-release
  echo -e "\n########### Memory"
  free -h
  echo -e "\n########### Disk"
  df -h -x overlay -x tmpfs
  echo -e "\n########### Docker"
  docker --version
  docker compose version
}
# Docker stats
function menu55 {
  echo -e "HEADER: Name\t\tCPU\t\tMemory\t\tNetIO\t\tBlockIO\t\tMemory(%)"
  docker stats -a --no-stream --no-trunc --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}\t{{.MemPerc}}" | grep visiology3
}
# Docker info
function menu56 {
  docker info | less
  return 1
}
# Network
function menu57 {
  ip -f inet addr show | grep 'eth' | awk '{print $2}' | cut -d'/' -f1

  if [[ $(which curl) ]]; then
    echo "External IP: $(curl -s ifconfig.me)"
  fi
}
# integrity
function menu58 {
  if [[ -f "${CHECKSUM_FILE}" ]]; then
    md5sum -c ${CHECKSUM_FILE} | less
  else
    printf "Файл контрольных сумм не найден"
  fi

  if [[ $? -eq 0 ]]; then
    return 1
  fi
}
########## menu 6
# Restore
function menu61 {
  /bin/bash ./v3/restore.sh
  /bin/bash ${UTILS_DIR}/load_secrets.sh

  if [[ $? -eq 0 ]]; then
    return 1
  fi
}
# Backup
function menu62 {
  /bin/bash ${UTILS_DIR}/store_secrets.sh
  /bin/bash ./v3/backup.sh

  if [[ $? -eq 0 ]]; then
    return 1
  fi
}
########## menu 7
# prepare
function menu7 {
  source ${configEnvPath}

  proxy_container_id=$(docker ps -f status=running | grep ${PROXY_SERVICE} |  awk '{ print $1 }');

  if [[ -z "${proxy_container_id}" ]]; then
    case "${START_VERSION}" in
      "${V2}")
        /bin/bash ./v2/prepare-config.sh
        /bin/bash ./v2/prepare-folders.sh
        ;;
      "${V3}")
        /bin/bash ./v3/prepare-config.sh -f
        ;;
      "${ALL}")
        /bin/bash ./v2/prepare-config.sh
        /bin/bash ./v2/prepare-folders.sh
        /bin/bash ./v3/prepare-config.sh -f
        ;;
    esac
  else
    printf "\nПлатформу необходимо предварительно остановить"
    return 0
  fi

  if [[ $? -eq 0 ]]; then
    return 1
  fi
}
########## menu 9
# make ssl certs
function menu9 {
  tput cup ${execute_start_row} 0; tput cud1
  read -rp "Адрес платформы: " cn
  cn_type=DNS
  opt_nodes=
  pass_phrase=

  sed -i -E "s/^PLATFORM_IP=[^:]*/PLATFORM_IP=${cn}/" ${configEnvPath}

  if [[ "$cn" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
    cn_type=IP
  fi

  echo "Использовать пароль для сертификата?"
  yes_no=("Да" "Нет")
  false_true_selected_opt=$(select_opt "${yes_no[@]}")
  opt_type=${FALSE}

  if [[ "${false_true_selected_opt}" == "1" ]]; then
    opt_nodes="-nodes"
  else
    read -rp "Пароль ключа: " pass_phrase
    echo ${pass_phrase} > ${CERTS_DIR}password.pass
    pass_phrase="-passout file:${CERTS_DIR}password.pass"
  fi

  san=${cn_type}:${cn}
  openssl req -new ${opt_nodes} -x509 -sha256 -newkey rsa:2048 ${pass_phrase} -keyout ${CERTS_DIR}privatekey.key -out ${CERTS_DIR}certificate.crt -days 365 \
    -config <(echo "
    [req]
    distinguished_name=req_distinguished_name
    x509_extensions=v3_req
    prompt=no
    [req_distinguished_name]
    CN = ${cn}
    [v3_req]
    subjectKeyIdentifier=hash
    authorityKeyIdentifier=keyid:always,issuer
    basicConstraints=CA:true
    subjectAltName=${san}")
  #openssl pkcs12 -export -out ${CERTS_DIR}proxy.pfx -inkey ${CERTS_DIR}privatekey.key -in ${CERTS_DIR}certificate.crt

  if [[ -z "${opt_nodes}" ]]; then
    sed -i -E "s/^CERT_PASS_FILENAME=.*$/CERT_PASS_FILENAME=password.pass/" ${configEnvPath}
  fi

  sed -i -E "s/^CERT_CRT_FILENAME=.*$/CERT_CRT_FILENAME=certificate.crt/" ${configEnvPath}
  sed -i -E "s/^CERT_KEY_FILENAME=.*$/CERT_KEY_FILENAME=privatekey.key/" ${configEnvPath}
  echo "${NEED_RESTART}"

}
################################################################ end

if [[ ! -f "${CHECKSUM_FILE}" ]]; then
  make_check_sum
fi

declare -n current_menu="menu"
### save screen
tput smcup

#################### main loop #####################################
while true; do
  clear
  stty -echo
  tput home
  logo 1 0
  printf "\nMenu:"
  print_config_env 5 ${config_start_col}

  tput cup ${execute_start_row} 0
  echo -e "🠗🠗🠗🠗🠗🠗🠗🠗🠗🠗"
  tput cup 7 0
  selected_opt=$(select_opt "${current_menu[@]}")
  i=0

  for key in "${!current_menu[@]}"; do
    if [[ ${selected_opt} -eq $i ]]; then
      break
    fi

    (( i ++ ))
  done

  menu_link="${current_menu[${key}]}"

  case "${menu_link}" in
    *"${EXIT}"*)
      #restore screen
      clear
      stty echo
      tput rmcup;

      if [[ "${CHANGE_URL}" == "${TRUE}" ]]; then
        >"${FORCE_CHANGE_URL_FILE}"
      fi

      exit 0
      ;;
    *"${BACK}"*)
      declare -n current_menu="menu"
      ;;
    *".."*)
      declare -n current_menu="${key}"
      ;;
    *)
      tput cup ${execute_start_row} 0; tput cud1
      stty echo
      $key
      execution_result=$?
      if [[ "${execution_result}" -eq 0 ]]; then
        printf "\n\n%s" "${MAGENTA}${PRESS_ANY_KEY}${NORMAL}"
        read -rn1
        clear_buffer
      fi
      ;;
  esac
done
