#!/bin/bash
#2.38&3.9Ubuntu

DISTR_FILENAME=2.38_3.9
PLATFORM_VERSION=2.38_3.9

function prepare(){
    if [[ $1 == "v2" || $1 == "all" ]]; then
        /var/lib/visiology/scripts/v2/prepare-folders.sh
        /var/lib/visiology/scripts/v2/prepare-config.sh
    fi
    if [[ $1 == "v3" || $1 == "all" ]]; then
        /var/lib/visiology/scripts/v3/prepare-config.sh
        echo -e "\e[36Запросите лицензионный ключ у вендора\e[0m"
		echo -e "\e[34Введите лицензионный ключ для версии 3\e[0m"
        read -p "> " licence_key3
        /var/lib/visiology/scripts/v3/prepare-config.sh -l $licence_key3
    fi
}

echo -e "\e[36mУстановка платформы Visiology ${PLATFORM_VERSION}\e[0m"
echo -e "\e[34Укажите версии, которые требуется развернуть\e[0m"
DEPLOY_VERSIONS=("v2" "v3" "v2+v3" "Выход")
deploy_version=none
select opt in "${DEPLOY_VERSIONS[@]}"
do
    case $opt in
        "v2")
            deploy_version=v2; break;;
        "v3")
            deploy_version=v3; break;;
        "v2+v3")
            deploy_version=all; break;;
        "Выход")
            echo -e "\e[31mУстановка прервана\e[0m";exit 0;;
        *)
            echo -e "\e[31mНекорректная опция\e[0m";continue;;
    esac
done

echo -e "\e[36mУстановка версии ${deploy_version}\e[0m"

#----------------------------------Проверка установки из snap--------------------------------------------------

if snap info vlc &> /dev/null; then
	snap list | grep docker
	if [ $? -eq 0 ]; then
		echo -e "\e[36mУстановлен docker из snap. Удалите и запустите скрипт заново\e[0m"
		echo -e "\e[34Удалить из системы? (Y/N)\e[0m"
		read -p "> " answer
		case ${answer:0:1} in
					y|Y|Д|д )
							snap remove docker
							sed -i 's.ListenStream=/run/docker\.sock.ListenStream=/var\/run\/docker\.sock.g' /lib/systemd/system/docker.socket
							systemctl daemon-reload
							echo -e "\e[42mDocker удалён\e[0m"
							;;
					* )
							echo -e "\e[31mУдалите (snap remove docker) и запустите скрипт заново\e[0m"
							exit 1
							;;
		esac
	fi
fi
#----------------------------------Установка docker+composer--------------------------------------------

if docker -v &> /dev/null; then
    echo -e "\e[42mDocker установлен\e[0m"
else
        echo -e "\e[36mУстановка Docker+Compose\e[0m"
        apt-get update
        apt-get install ca-certificates curl -y
        install -m 0755 -d /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
        chmod a+r /etc/apt/keyrings/docker.asc
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
        apt-get update
        apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y
        groupadd docker
        usermod -aG docker $USER
        systemctl start docker
fi
#----------------------Установка платформы-----------------------------

#необходимые папки для запуска версии 3
mkdir -p /var/lib/visiology/scripts /var/lib/visiology/certs /var/lib/visiology/v3/dashboard-viewer/customjs && sudo chown -R "$(id -u):$(id -g)" /var/lib/visiology

echo -e "\e[34mЗапустить платформу после установки? (Y/N)\e[0m"
read -p "> " answer
case ${answer:0:1} in
	y|Y|Д|д )
		echo -e "\e[34mВведите IP адрес платформы или DNS имя для запуска:\e[0m"
		read -p "> " platform_url
		echo -e "\e[42mДля в платформу входа после установки введите в браузере \e[4;32mhttp://${platform_url}\e[0m"
		;;
	* )
		platform_url=none
		;;
esac

echo -e "\e[34mТип установки\e[0m"
distr=("Установка через образы" "Установка через Yandex Container Registry" "Выход")
select opt in "${distr[@]}"
do
    case $opt in
                # -------------------------------------- Установка через образы ------------------------------------------
        "Установка через образы")
                        echo -e "\e[34mУкажите путь до папки с дистрибутивом ( '.' - текущая ):\e[0m"
                        read -p "> " distr_path
                        if test -f "${distr_path}/${DISTR_FILENAME}.tar"; then
                                                echo -e "\e[42mУФайл с дистрибутивом найден\e[0m"
                                        else
                                                echo -e "\e[31mОтсутствует файл с дистрибутивом\e[0m"
                                                exit 1
                                        fi
                        tar -xvf $DISTR_FILENAME.tar
                        docker load < $DISTR_FILENAME/images/platform-deployment.tar.gz
                        docker run -it --rm -u "$(id -u):$(id -g)" -v /etc/passwd:/etc/passwd:ro -v /var/lib/visiology:/mnt/volume cr.yandex/crpe1mi33uplrq7coc9d/visiology/release/platform-deployment:$PLATFORM_VERSION
                        /var/lib/visiology/scripts/load_images.sh --version $deploy_version -i $distr_path/images
                        prepare $deploy_version
                        # --- старт ---------
                        if [ "${platform_url}" != "none" ]; then 
							/var/lib/visiology/scripts/run.sh -p $platform_url --start $deploy_version
						fi
                        exit 0
            ;;
                # ------------------------------------------    Установка через Yandex Container Registry ------------------
        "Установка через Yandex Container Registry")
                        echo -e "\e[36mЗапросите токен для доступа в реестр у поддержки\e[0m"
						echo -e "\e[34mВведите токен для доступа в реестр\e[0m"
                        read -p "> " token
                        docker login --username oauth --password $token cr.yandex
                        docker pull cr.yandex/crpe1mi33uplrq7coc9d/visiology/release/platform-deployment:$PLATFORM_VERSION
                        docker run -it --rm -u "$(id -u):$(id -g)" -v /etc/passwd:/etc/passwd:ro -v /var/lib/visiology:/mnt/volume cr.yandex/crpe1mi33uplrq7coc9d/visiology/release/platform-deployment:$PLATFORM_VERSION
                        /var/lib/visiology/scripts/load_from_release_dockerhub.sh --version $deploy_version
                        prepare $deploy_version
                        # --- старт ---------
                        if [ "${platform_url}" != "none" ]; then 
							/var/lib/visiology/scripts/run.sh -p $platform_url --start $deploy_version
						fi
                        exit 0
            ;;
		"Выход")
            echo -e "\e[31mУстановка прервана\e[0m";exit 0;;
        *) 
			echo -e "\e[31mНекорректная опция\e[0m";continue;;
    esac
done
