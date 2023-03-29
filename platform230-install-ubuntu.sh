#!/bin/bash
#2.30Ubuntu

distr_filename=distrib_2.30+3.1
platform_version=2.30_3.1
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
apt-get update
apt-get upgrade -y
if docker -v docker &> /dev/null
then
    echo -e "\e[42mDocker установлени\e[0m"
else
	echo -e "\e[42mУстановка Docker+Compose\e[0m"
	apt-get install ca-certificates curl gnupg lsb-release -ydocker 
	mkdir -p /etc/apt/keyrings
	curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
	echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
	apt-get update
	apt-get install docker-ce docker-ce-cli containerd.io docker-compose-plugin -y
	groupadd docker
	usermod -aG docker $USER
	systemctl start docker
fi
echo -e "\e[36mURL платформы:\e[0m"
read -p "> " platform_url
echo -e "\e[36mТип установки\e[0m"
distr=("Установка через образы" "Установка через Yandex Container Registry")
select opt in "${distr[@]}"
do
    case $opt in
        "Установка через образы")
            read -p "Скачать дистрибутив $platform_version? (Y/N)" answer
			case ${answer:0:1} in
				y|Y )
					wget "https://storage.yandexcloud.net/distributions/${distr_filename}.tar.xz"
					;;
				* )
					echo "Поиск дистрибутива.."
					;;
			esac
			if test -f ./"${distr_filename}.tar.xz"; then
						echo "Файл с дистрибутивом найден"
					else
						echo -e "\e[31mОтсутствует файл с дистрибутивом\e[0m"
						exit 1
					fi
			tar -xvf ${distr_filename}.tar.xz
			cd ${distr_filename}
			docker load < images/platform-deployment.tar.gz
			docker run -it --rm -u $(id -u):$(id -g) -v "$(pwd)":/mnt/volume -v /var/lib/visiology/certs:/mnt/visiology cr.yandex/crpe1mi33uplrq7coc9d/visiology/release/platform-deployment:$platform_version
			./load_images.sh
			cd v2 && FALSE=false ./prepare-folders.sh && cd ..
			v2/prepare-config.sh
			./run.sh -p $platform_url --start v2
			exit 0
            ;;
        "Установка через Yandex Container Registry")
            echo "Запросите токен для по ссылке https://oauth.yandex.ru/authorize?response_type=token&client_id=1a6990aa636648e9b2ef855fa7bec2fb"
			read -p "Введите токен:" token
			docker login --username oauth --password $token cr.yandex
			docker pull cr.yandex/crpe1mi33uplrq7coc9d/visiology/release/platform-deployment:$platform_version
			docker run -it --rm -u $(id -u):$(id -g) -v "$(pwd)":/mnt/volume -v /var/lib/visiology/certs:/mnt/visiology cr.yandex/crpe1mi33uplrq7coc9d/visiology/release/platform-deployment:$platform_version
			./load_from_release_dockerhub.sh -v v2
			cd v2 && FALSE=false ./prepare-folders.sh && cd ..
			v2/prepare-config.sh
			./run.sh -p $platform_url --start v2
			exit 0
            ;;
        *) echo "invalid option";;
    esac
done