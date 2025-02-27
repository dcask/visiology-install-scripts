#!/bin/bash
# you can make softlink ln -s /var/lib/visiology/scripts/v3/utils/get_logs.sh /usr/bin/vilogs

# Exit codes:
EXIT_OK=0
UNKNOWN_KEY=127
INVALID_VERSION=100

UNDEFINED=255

TRUE=true
FALSE=false

SINCE=10m
V3=visiology3
V2=visiology2
COMMON=visiology_common

VERSION_FILTER=${V3}
option_flag_version=${UNDEFINED}
option_flag_path=${UNDEFINED}
option_flag_report=${UNDEFINED}
option_flag_zip=${UNDEFINED}
option_flag_clear=${UNDEFINED}
option_flag_stats=${UNDEFINED}
option_flag_info=${UNDEFINED}
option_flag_jobs=${UNDEFINED}

EXITED_RELATIVE_PATH=exited
RUNNING_RELATIVE_PATH=running
PLATFORM_CONFIG=/var/lib/visiology/scripts/v3/dynamic.env
ZIP_PATH=/var/lib/visiology/logs

ZIP_NAME=vilogs
REPORT_FILE=report.log
SYSTEM_FILE=system-info.txt
STATS_FILE=docker-stats.txt
COMPONENTS_FILE=${VERSION_FILTER}-components.txt

FOLDER_PATH=${ZIP_PATH}/services-${VERSION_FILTER}

function print_help() {
  echo
  echo "Usage: ./get_logs.sh [OPTIONS]"
  echo "   -? | -h | --help                       Display this help message."
  echo "   -s | --since <period>                  Optional. Logs period. Default 10m."
  echo "   -p | --path <folder>                   Optional. Logs folder path"
  echo "   -d | --debug                           Optional. Debug"
  echo "   -c | --clear                           Optional. Remove previous logs"
  echo "   -r | --report                          Optional. Make general log file"
  echo "   -i | --info                            Optional. Make system info file"
  echo "   -t | --stats                           Optional. Make stats file"
  echo "   -z | --zip                             Optional. Make tar.gz file"
  echo "   -j | --jobs                            Optional. Get hangfire jobs"
  echo "   -v | --version <v2|v3|common>          Optional. Platform version. Default v3"
  echo
}

function find_errors() {
  awk '
    /^.*\[[0-9]+:[0-9]+:[0-9]+ Error\]/ {
        print
        flag = 1
        next
    }
    /^.*\[[0-9]+:[0-9]+:[0-9]+ [A-Za-z]+\]/ {
        flag = 0
    }
    flag {
        print
    }
    ' "$1"
}

function split_options() {
  options_array=()

  for param in "$@"; do
    if [[ $param == -* && $param != --* ]]; then
      options="${param:1}"

      for ((i = 0; i < ${#options}; i++)); do
        options_array+=("-${options:i:1}")
      done
    else
      options_array+=("$param")
    fi
  done

  IFS=' '
  echo "${options_array[*]}"
}

function rotate_logs() {
  for f in $1/$2*.tar.gz; do
    basefile=$(basename ${f})
    filename=${basefile//.tar.gz/}
    number=${filename//$2/}
    index=0
    if [[ -n ${number} ]]; then
      ((index = number + 1))
    fi

    mv ${f} $1/$2${index}.tar.gz
  done
}

set -- $(split_options "$@")

# Parse command line arguments
while [[ "$1" != "" ]]; do
  case "$1" in
  "-?" | "-h" | "--help")
    print_help
    exit ${EXIT_OK}
    ;;
  "-s" | "--since")
    shift
    SINCE="$1"
    ;;
  "-p" | "--path")
    shift
    option_flag_path="$1"
    ;;
  "-c" | "--clear")
    option_flag_clear=${TRUE}
    ;;
  "-d" | "--debug")
    set -x
    ;;
  "-z" | "--zip")
    option_flag_zip=${TRUE}
    ;;
  "-v" | "--version")
    shift
    option_flag_version="$1"
    ;;
  "-t" | "--stats")
    option_flag_stats=${TRUE}
    ;;
  "-i" | "--info")
    option_flag_info=${TRUE}
    ;;
  "-r" | "--report")
    option_flag_report=${TRUE}
    ;;
  "-j" | "--jobs")
    option_flag_jobs=${TRUE}
    ;;
  *)
    echo "Unknown key: $1"
    print_help
    exit ${UNKNOWN_KEY}
    ;;
  esac
  shift
done

if [[ "${option_flag_version}" != "${UNDEFINED}" ]]; then
  case ${option_flag_version} in
  "v2")
    VERSION_FILTER=${V2}
    ;;
  "v3")
    VERSION_FILTER=${V3}
    ;;
  "common")
    VERSION_FILTER=${COMMON}
    ;;
  *)
    echo "Invalid option --version. See help: $0 -h"
    exit "${INVALID_VERSION}"
    ;;
  esac

  if [[ "${option_flag_path}" != "${UNDEFINED}" ]]; then
    ZIP_PATH=${option_flag_path}
    FOLDER_PATH=${ZIP_PATH}/services-${VERSION_FILTER}
  fi
fi
##### Clear previous
if [[ "${option_flag_clear}" == "${TRUE}" ]]; then
  rm -rf ${FOLDER_PATH}
fi

mkdir -p ${FOLDER_PATH}/${RUNNING_RELATIVE_PATH}
mkdir -p ${FOLDER_PATH}/${EXITED_RELATIVE_PATH}

containers_exited=$(docker ps -a -q --filter status=exited --filter label="visiology_version=${VERSION_FILTER}" 2>/dev/null)
containers_running=$(docker ps -a -q --filter status=running --filter label="visiology_version=${VERSION_FILTER}" 2>/dev/null)

services=()

##### Running containers logs
for container_id in ${containers_running[@]}; do
  started_at=$(docker inspect ${container_id} --format="{{.State.StartedAt}}" 2>/dev/null)
  service_name=$(docker inspect ${container_id} --format='{{(index .Config.Labels "com.docker.swarm.service.name")}}' 2>/dev/null)
  file_name=${service_name}.${started_at}
  docker logs ${container_id} -t --since ${SINCE} >${FOLDER_PATH}/${RUNNING_RELATIVE_PATH}/${file_name} 2>&1
  services+=(${service_name})
  errors=$(find_errors ${FOLDER_PATH}/${RUNNING_RELATIVE_PATH}/${file_name})

  if [[ -n "${errors}" ]]; then
    echo -e "${errors}" >${FOLDER_PATH}/${RUNNING_RELATIVE_PATH}/${file_name}_errors 2>&1
  fi
done

##### Exited containers logs
for container_id in ${containers_exited[@]}; do
  started_at=$(docker inspect ${container_id} --format="{{.State.StartedAt}}" 2>/dev/null)
  service_name=$(docker inspect ${container_id} --format='{{(index .Config.Labels "com.docker.swarm.service.name")}}' 2>/dev/null)
  file_name=${service_name}.${started_at}

  if [[ $(echo "${services[*]}" | grep -w -c ${service_name} 2>/dev/null) == 0 ]]; then
    docker logs ${container_id} -t --since ${SINCE} >${FOLDER_PATH}/${EXITED_RELATIVE_PATH}/${file_name} 2>&1
    errors=$(find_errors ${FOLDER_PATH}/${EXITED_RELATIVE_PATH}/${file_name})

    if [[ -n ${errors} ]]; then
      echo -e "${errors}" >${FOLDER_PATH}/${EXITED_RELATIVE_PATH}/${file_name}_errors 2>&1
    fi
  fi
done

##### Merge logs
if [[ "${option_flag_report}" == "${TRUE}" ]]; then
  sub=("formula-engine" "workspace-service" "smart-forms" "data-management-service" "dashboard-service" "dashboard-viewer")

  >${ZIP_PATH}/tmpreportfile
  >${ZIP_PATH}/${REPORT_FILE}

  for file in ${FOLDER_PATH}/${RUNNING_RELATIVE_PATH}/*; do
    if [[ -f "$file" ]]; then
      for s in "${sub[@]}"; do
        if [[ "$file" == *"$s"* && "$file" != *"error"* ]]; then
          awk -v sub_name="${s}" '/^.*\[[0-9]+:[0-9]+:[0-9]+ [A-Za-z]+\]/ {print "[" $1 " " $3 " " sub_name " : " $4 " " $5 " " $6 ".."}' "$file" >>${ZIP_PATH}/tmpreportfile
        fi
      done
    fi
  done

  for file in ${FOLDER_PATH}/${EXITED_RELATIVE_PATH}/*; do
    if [[ -f "$file" ]]; then
      for s in "${sub[@]}"; do
        if [[ "$file" == *"$s"* && "$file" != *"error"* ]]; then
          awk -v sub_name="${s}" '/^.*\[[0-9]+:[0-9]+:[0-9]+ [A-Za-z]+\]/ {print "[" $1 " " $3 " " sub_name " : " $4 " " $5 " " $6 ".."}' "$file" >>${ZIP_PATH}/tmpreportfile
        fi
      done
    fi
  done

  sort -o ${ZIP_PATH}/${REPORT_FILE} ${ZIP_PATH}/tmpreportfile && rm ${ZIP_PATH}/tmpreportfile
fi

##### Add stats
if [[ "${option_flag_stats}" == "${TRUE}" ]]; then
  echo -e "HEADER: Name\t\tCPU\t\tMemory\t\tNetIO\t\tBlockIO\t\tMemory(%)" >${ZIP_PATH}/${STATS_FILE}

  docker stats -a --no-stream --no-trunc --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}\t{{.MemPerc}}" | grep visiology3 >>${ZIP_PATH}/${STATS_FILE}
fi

##### Get sys info file
if [[ "${option_flag_info}" == "${TRUE}" ]]; then
  echo "########### OS" >${ZIP_PATH}/${SYSTEM_FILE}
  cat /etc/*-release >>${ZIP_PATH}/${SYSTEM_FILE}
  echo -e "\n########### Memory" >>${ZIP_PATH}/${SYSTEM_FILE}
  free -h >>${ZIP_PATH}/${SYSTEM_FILE}
  echo -e "\n########### Swap" >>${ZIP_PATH}/${SYSTEM_FILE}
  swapon -s >>${ZIP_PATH}/${SYSTEM_FILE}
  echo -e "\n########### Disk" >>${ZIP_PATH}/${SYSTEM_FILE}
  df -h -x overlay -x tmpfs >>${ZIP_PATH}/${SYSTEM_FILE}
fi

##### Components version
if [[ "${VERSION_FILTER}" == "${V3}" ]]; then
  source ${PLATFORM_CONFIG}
  wget --no-check-certificate -O ${ZIP_PATH}/${COMPONENTS_FILE} ${PLATFORM_URL}/version 2>/dev/null
fi

##### Get hangfire jobs
if [[ "${option_flag_jobs}" == "${TRUE}" ]]; then
  INTERVAL=${SINCE/m/ minutes}
  INTERVAL=${INTERVAL/h/ hours}
  INTERVAL=${INTERVAL/d/ days}
  pg_container_id=$(docker ps -q --filter label=component=v3-postgres-visiology)
  pg_user=$(docker exec ${pg_container_id} cat /run/secrets/POSTGRES_VISIOLOGY_ROOT_USER)
  pg_password=$(docker exec ${pg_container_id} cat /run/secrets/POSTGRES_VISIOLOGY_ROOT_PASSWORD)

  hangfire=( "dm_hangfire" "fe_hangfire" "ds_hangfire" "ws_hangfire" )

  for scheme in "${hangfire[@]}"; do
    pg_command="select to_char(j.createdat, 'YYYY-MM-DD HH:MI:SS'), j.statename, s.data from ${scheme}.state s left join ${scheme}.job j on j.id=s.jobid where j.createdat> NOW() - INTERVAL '${INTERVAL} minutes';"
    docker exec ${pg_container_id} bash -c "PGPASSWORD=${pg_password} psql -t --csv -U ${pg_user} -d visiology -c \"${pg_command}\"" > ${ZIP_PATH}/${scheme}.csv
  done
fi

##### Archive option
if [[ "${option_flag_zip}" == "${TRUE}" ]]; then
  if [[ ${CLEAR_FLAG} == "${TRUE}" ]]; then
    rm -f ${ZIP_PATH}/${ZIP_NAME}*.tar.gz 2>/dev/null
  fi

  if [[ -e "${ZIP_PATH}/${ZIP_NAME}.tar.gz" ]]; then
    rotate_logs ${ZIP_PATH} ${ZIP_NAME}
  fi

  tar -zcf ${ZIP_PATH}/${ZIP_NAME}.tar.gz --exclude=*.tar.gz -C ${ZIP_PATH}/ . 2>/dev/null

  echo "${ZIP_PATH}/${ZIP_NAME}.tar.gz created"
fi
