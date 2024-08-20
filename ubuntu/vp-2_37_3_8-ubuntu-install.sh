#!/bin/bash
#2.37&3.8Ubuntu

distr_filename=distrib_2.37+3.8
platform_version=2.37_3.8

function prepare_v2(){
	/var/lib/visiology/scripts/v2/prepare-folders.sh
	/var/lib/visiology/scripts/v2/prepare-config.sh
}

function prepare_v3(){
	/var/lib/visiology/scripts/v3/prepare-config.sh
	echo "Запросите ключ у вендора"
	read -p "Введите ключ для версии 3:" licence_key3
	/var/lib/visiology/scripts/v3/prepare-config.sh -l ${licence_key3}
}

echo -e "\e[31mУстановка платформы Visiology ${platform_version}\e[0m"
echo -e "Укажите версию, которые требуется развернуть\e[0m"
deploy_versions=("v2" "v3" "all")
select opt in "${deploy_versions[@]}"
do 
	case $opt in
        "v2")
			deploy_version=v2
		;;
		"v3")
			deploy_version=v3
		;;
		"all")
			deploy_version=all
		;;
		*) echo "invalid option";;
done

#----------------------------------Проверка установки из snap--------------------------------------------------

snap list | grep docker
if [ $? -eq 0 ]; then
    echo -e "\e[31mУстановлен docker из snap. Удалите и запустите скрипт заново\e[0m"
	read -p "Удалить из системы? (Y/N)" answer
	case ${answer:0:1} in
		y|Y )
			snap remove docker
			sed -i 's.ListenStream=/run/docker\.sock.ListenStream=/var\/run\/docker\.sock.g' /lib/systemd/system/docker.socket
			systemctl daemon-reload
			;;
		* )
			echo -e "\e[31mУдалите (snap remove docker) и запустите скрипт заново\e[0m"
			exit 1
			;;
	esac
fi

#----------------------------------Установка docker+composer--------------------------------------------

apt-get update
apt-get upgrade -y
if docker -v docker &> /dev/null
then
    echo -e "\e[42mDocker установлени\e[0m"
else
	echo -e "\e[42mУстановка Docker+Compose\e[0m"
	apt-get update
	apt-get install ca-certificates curl
	install -m 0755 -d /etc/apt/keyrings
	curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
	chmod a+r /etc/apt/keyrings/docker.asc

	# Add the repository to Apt sources:
	echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
	apt-get update
	apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y
	groupadd docker
	usermod -aG docker $USER
	systemctl start docker
fi


#----------------------Установка платформы-----------------------------

mkdir -p /var/lib/visiology/scripts /var/lib/visiology/certs /var/lib/visiology/v3/dashboard-viewer/customjs && sudo chown -R "$(id -u):$(id -g)" /var/lib/visiology

echo -e "\e[36mВведите IP адрес платформы или DNS имя:\e[0m"
read -p "> " platform_url
echo -e "\e[36mТип установки\e[0m"
distr=("Установка через образы" "Установка через Yandex Container Registry")
select opt in "${distr[@]}"
do
    case $opt in
		# -------------------------------------- Установка через образы ------------------------------------------
        "Установка через образы")
			#------------Общая часть -----------------------
            echo -e "\e[36mУкажите путь до папки с дистрибутивом:\e[0m"
			read -p "> " distr_path
			case ${answer:0:1} in
				y|Y )
					wget "https://storage.yandexcloud.net/distributions/${distr_filename}.tar"
					;;
				* )
					echo "Поиск дистрибутива.."
					;;
			esac
			if test -f "${distr_path}/${distr_filename}.tar"; then
						echo "Файл с дистрибутивом найден"
					else
						echo -e "\e[31mОтсутствует файл с дистрибутивом\e[0m"
						exit 1
					fi
			tar -xvf ${distr_filename}.tar
			cd ${distr_filename}
			docker load < images/platform-deployment.tar.gz
			docker run -it --rm -u "$(id -u):$(id -g)" -v /etc/passwd:/etc/passwd:ro -v /var/lib/visiology:/mnt/volume cr.yandex/crpe1mi33uplrq7coc9d/visiology/release/platform-deployment:${platform_version}
			/var/lib/visiology/scripts/load_images.sh --version ${deploy_version} -i ${distr_path}/images
			if [[ ${deploy_version} == "v2" || ${deploy_version} == "all"]]; then
				prepare_v2()
			fi
			if [[ ${deploy_version} == "v3" || ${deploy_version} == "all"]]; then
				prepare_v3()
			fi
			# ------------------v2-------------------
			/var/lib/visiology/scripts/v2/prepare-folders.sh
			/var/lib/visiology/scripts/v2/prepare-config.sh
			# ------------------v3--------------------
			/var/lib/visiology/scripts/v3/prepare-config.sh
			echo "Запросите ключ у вендора"
			read -p "Введите ключ для версии 3:" licence_key3
			/var/lib/visiology/scripts/v3/prepare-config.sh -l ${licence_key3}
			
			# --- старт ---------
			./run.sh -p $platform_url --start ${deploy_version}
			exit 0
            ;;
		# ------------------------------------------	Установка через Yandex Container Registry ------------------
        "Установка через Yandex Container Registry")
            echo "Запросите токен у поддержки"
			read -p "Введите токен:" token
			docker login --username oauth --password $token cr.yandex
			docker pull cr.yandex/crpe1mi33uplrq7coc9d/visiology/release/platform-deployment:$platform_version
			docker run -it --rm -u $(id -u):$(id -g) -v "$(pwd)":/mnt/volume -v /var/lib/visiology/certs:/mnt/visiology cr.yandex/crpe1mi33uplrq7coc9d/visiology/release/platform-deployment:$platform_version
			/var/lib/visiology/scripts/load_from_release_dockerhub.sh --version ${deploy_version}
			
			if [[ ${deploy_version} == "v2" || ${deploy_version} == "all"]]; then
				prepare_v2()
			fi
			if [[ ${deploy_version} == "v3" || ${deploy_version} == "all"]]; then
				prepare_v3()
			fi
			
			# --- старт ---------
			./run.sh -p $platform_url --start ${deploy_version}
			exit 0
            ;;
        *) echo "invalid option";;
    esac
done