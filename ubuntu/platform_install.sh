#!/bin/bash
#2.40&3.11_Ubuntu

PLATFORM_VERSION=2.40_3.11
DISTR_FILENAME=2.40_3.11

PROJECT_V3=visiology3

DOCKER_REPO_PREFIX="cr.yandex/crpe1mi33uplrq7coc9d/visiology/"
DOCKER_RELEASE_TYPE="release"
TAG_V3=${V3_TAG}

VISIOLOGY_PATH=/var/lib/visiology
VISIOLOGY_SCRIPT_PATH=${VISIOLOGY_PATH}/scripts/
OS_RELEASE_PATH="/etc/*-release"

EXIT_INVALID=21
EXIT_DISTR_NOT_FOUND=22
EXIT_OK=0

UBUNTU=Ubuntu
V2=v2
V3=v3
ALL="${V2}+${V3}"
LEAVE=Выход
UNDEFINED=255
TYPE_IMAGES="Установка через образы"
TYPE_REGISTRY="Установка через Yandex Container Registry"

LICENSE_SERVER_IMAGE=${DOCKER_REPO_PREFIX}${DOCKER_RELEASE_TYPE}/license-server:${TAG_V3}
LICENSE_VOLUME_NAME=${PROJECT_V3}_license

MESSAGE_ASK_LICENCE="\e[36mЗапросите лицензионный ключ у вендора\e[0m"
MESSAGE_ENTER_LICENCE="\e[34mВведите лицензионный ключ для версии 3\e[0m"
MESSAGE_INVALID_LICENCE="\e[31mНевалидный лицензионный ключ\e[0m"
MESSAGE_UNSUPPORTED_OS="\e[31mНе поддерживаемая OS\e[0m"
MESSAGE_DOCKER_EXISTS="\e[42mDocker уже установлен\e[0m"
MESSAGE_UBUNTU_DETECTED="\e[36mОбнаружена Ubuntu OS\e[0m"
MESSAGE_START_INSTALLING="\e[36mУстановка версии \e[0m "
MESSAGE_INSTALLING_INTERUPTED="\e[31mУстановка прервана\e[0m"
MESSAGE_INVALID_OPTION="\e[31mНекорректная опция\e[0m"
MESSAGE_DOCKER_INSTALLING="\e[36mУстановка Docker+Compose\e[0m"
MESSAGE_SNAP_DETECTED="\e[31mОбнаружен snap docker\e[0m"
MESSAGE_ASK_DELETE_SNAP="\e[34mУдалить из системы? (Y/N)\e[0m"
MESSAGE_DOCKER_REMOVED="\e[42mDocker удален\e[0m"
MESSAGE_INFO_REMOVE_DOCKER="\e[31mУдалите (snap remove docker) и запустите скрипт заново\e[0m"
MESSAGE_PLATFORM_INSTALLING="\e[36mУстановка платформы Visiology \e[0m"
MESSAGE_ASK_VERSION="\e[34mУкажите версии, которые требуется развернуть\e[0m"
MESSAGE_ASK_IP="\e[34mВведите IP адрес платформы или DNS имя для запуска:\e[0m"
MESSAGE_INSTALL_TYPE="\e[34mТип установки\e[0m"
MESSAGE_ASK_DISTR_PATH="\e[34mУкажите путь до папки с дистрибутивом ( . - текущая ):\e[0m"
MESSAGE_DISTR_NOT_FOUND="\e[31mОтсутствует файл с дистрибутивом\e[0m"
MESSAGE_ASK_TOKEN="\e[36mЗапросите токен для доступа в реестр у поддержки\e[0m"
MESSAGE_ENTER_TOKEN="\e[34mВведите токен для доступа в реестр\e[0m"
MESSAGE_ASK_START="\e[34mЗапустить платформу? (Y/N)\e[0m"
MESSAGE_READY_TO_START="\e[36mПлатформа готова к запуску\e[0m"

function get_hardware_id() {
  if [[ $1 == "v3" || $1 == "all" ]]; then
    docker volume create --name ${LICENSE_VOLUME_NAME} 2>/dev/null
    docker run -it --rm --read-only -v ${LICENSE_VOLUME_NAME}:/mnt/volume/license v "${LICENSE_SERVER_IMAGE}"
  fi
}
function prepare() {
  if [[ "$1" == "v2" || "$1" == "all" ]]; then
    /bin/bash ${VISIOLOGY_SCRIPT_PATH}v2/prepare-folders.sh
    /bin/bash ${VISIOLOGY_SCRIPT_PATH}v2/prepare-config.sh
  fi

  if [[ "$1" == "v3" || "$1" == "all" ]]; then
    /bin/bash ${VISIOLOGY_SCRIPT_PATH}v3/prepare-config.sh

    echo -e "${MESSAGE_ASK_LICENCE}"
    echo -e "${MESSAGE_ENTER_LICENCE}"
    read -p "> " licence_key3

    /bin/bash ${VISIOLOGY_SCRIPT_PATH}v3/prepare-config.sh -l "$licence_key3"
  fi

}

function install_docker_ubuntu() {
  echo -e "${MESSAGE_DOCKER_INSTALLING}"
  apt-get update
  apt-get install ca-certificates curl -y
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  chmod a+r /etc/apt/keyrings/docker.asc
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
  apt-get update
  apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y
  groupadd docker
  usermod -aG docker $USER
  systemctl start docker
}

function check_snap_docker() {
  if snap list | grep -q docker; then
    echo -e "${MESSAGE_SNAP_DETECTED}"
    echo -e "${MESSAGE_ASK_DELETE_SNAP}"
    read -p "> " answer
    case ${answer:0:1} in
    y | Y | Д | д)
      snap remove docker
      sed -i 's.ListenStream=/run/docker\.sock.ListenStream=/var\/run\/docker\.sock.g' /lib/systemd/system/docker.socket
      systemctl daemon-reload
      echo -e "${MESSAGE_DOCKER_REMOVED}"
      ;;
    *)
      echo -e "${MESSAGE_INFO_REMOVE_DOCKER}"
      exit 1
      ;;
    esac
  fi
}

function deploy_platform() {
  echo -e "${MESSAGE_INSTALL_TYPE}"

  distr=("${TYPE_IMAGES}" "${TYPE_REGISTRY}" "${LEAVE}")

  select opt in "${distr[@]}"; do
    case $opt in
    "${TYPE_IMAGES}")
      echo -e "${MESSAGE_ASK_DISTR_PATH}"
      read -p "> " distr_path

      if [[ -f "${distr_path}/${DISTR_FILENAME}.tar" ]]; then
        echo -e "${MESSAGE_DISTR_NOT_FOUND}"
        exit ${EXIT_DISTR_NOT_FOUND}
      fi

      tar -xvf "${distr_path}/${DISTR_FILENAME}.tar" -C "${distr_path}"

      docker load <$DISTR_FILENAME/images/platform-deployment.tar.gz
      docker run -it --rm -u "$(id -u):$(id -g)" -v /etc/passwd:/etc/passwd:ro -v ${VISIOLOGY_PATH}:/mnt/volume ${DOCKER_REPO_PREFIX}${DOCKER_RELEASE_TYPE}/platform-deployment:$PLATFORM_VERSION

      /bin/bash ${VISIOLOGY_SCRIPT_PATH}load_images.sh --version ${deploy_version} -i ${distr_path}/images

      prepare ${deploy_version}
      ;;
    "${TYPE_REGISTRY}")
      echo -e "${MESSAGE_ASK_TOKEN}"
      echo -e "${MESSAGE_ENTER_TOKEN}"
      read -p "> " token

      docker login --username iam --password "${token}" cr.yandex
      docker pull ${DOCKER_REPO_PREFIX}${DOCKER_RELEASE_TYPE}/platform-deployment:${PLATFORM_VERSION}
      docker run -it --rm -u "$(id -u):$(id -g)" -v /etc/passwd:/etc/passwd:ro -v /var/lib/visiology:/mnt/volume cr.yandex/crpe1mi33uplrq7coc9d/visiology/release/platform-deployment:$PLATFORM_VERSION

      /bin/bash ${VISIOLOGY_SCRIPT_PATH}load_from_release_dockerhub.sh --version ${deploy_version}

      prepare ${deploy_version}
      ;;
    ${LEAVE})
      echo -e ${MESSAGE_INSTALLING_INTERUPTED}
      exit 0
      ;;
    *)
      echo -e ${MESSAGE_INVALID_OPTION}
      continue
      ;;
    esac
  done

  mkdir -p ${VISIOLOGY_PATH}/certs ${VISIOLOGY_PATH}/v3/dashboard-viewer/customjs && sudo chown -R "$(id -u):$(id -g)" ${VISIOLOGY_PATH}
}

############################### main ###############################

echo -e ${MESSAGE_PLATFORM_INSTALLING}${PLATFORM_VERSION}
echo -e ${MESSAGE_ASK_VERSION}

DEPLOY_VERSIONS=(${V2} ${V3} ${ALL} ${LEAVE})
deploy_version=

select opt in "${DEPLOY_VERSIONS[@]}"; do
  case $opt in
  ${V2})
    deploy_version=v2
    break
    ;;
  ${V3})
    deploy_version=v3
    break
    ;;
  ${ALL})
    deploy_version=all
    break
    ;;
  ${LEAVE})
    echo -e ${MESSAGE_INSTALLING_INTERUPTED}
    exit 0
    ;;
  *)
    echo -e ${MESSAGE_INVALID_OPTION}
    continue
    ;;
  esac
done

echo -e ${MESSAGE_START_INSTALLING}${deploy_version}

## Check snap docker
check_snap_docker

## Check OS version and install docker
if [[ $(cat ${OS_RELEASE_PATH}) == *${UBUNTU}* ]]; then
  echo -e ${MESSAGE_UBUNTU_DETECTED}
  if [[ ! $(docker -v &>/dev/null) ]]; then
    install_docker_ubuntu
  else
    echo -e ${MESSAGE_DOCKER_EXISTS}
  fi
else
  echo -e ${MESSAGE_UNSUPPORTED_OS}
  exit 1
fi

## Get hardware id
if [[ -z $(docker volume ls -f name=${LICENSE_VOLUME_NAME} -q) ]] && [[ $(docker -v &>/dev/null) ]]; then
  get_hardware_id ${deploy_version}

  echo -e ${MESSAGE_ASK_LICENCE}

  exit ${EXIT_OK}
else
  echo -e ${MESSAGE_ENTER_LICENCE}
  read -p "> " licence_key3

  ${VISIOLOGY_SCRIPT_PATH}v3/prepare-config.sh -l ${licence_key3}

  if [[ "$?" == "${EXIT_INVALID}" ]]; then
    get_hardware_id ${deploy_version}
    echo -e ${MESSAGE_INVALID_LICENCE}
    exit ${EXIT_INVALID}
  fi
fi

## Deploy platform
if [[ ! -e "${VISIOLOGY_SCRIPT_PATH}" ]]; then
  deploy_platform
fi

## Start platform
platform_url=${UNDEFINED}
if [[ -e "${VISIOLOGY_SCRIPT_PATH}" ]]; then
  echo -e "${MESSAGE_READY_TO_START}"
  echo -e "${MESSAGE_ASK_START}"
  read -p "> " answer
  case ${answer:0:1} in
	  y|Y|Д|д )
		  echo -e "${MESSAGE_ASK_IP}"
      read -p "> " platform_url
      if [ "${platform_url}" != "${UNDEFINED}" ]; then
        /bin/bash ${VISIOLOGY_SCRIPT_PATH}run.sh -p ${platform_url} --start ${deploy_version}
      fi
		  ;;
	  * )
		  platform_url=none
		  ;;
  esac
fi

exit ${EXIT_OK}
