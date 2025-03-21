#!/bin/bash
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
	# Add Docker's official GPG key:
	apt-get update
	apt-get install ca-certificates curl gnupg -y
	install -m 0755 -d /etc/apt/keyrings
	curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
	chmod a+r /etc/apt/keyrings/docker.gpg
	
	# Add the repository to Apt sources:
	echo \
	  "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
	  "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
	  tee /etc/apt/sources.list.d/docker.list > /dev/null
	apt-get update
	apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y
	groupadd docker
	usermod -aG docker $USER
	systemctl start docker
fi
