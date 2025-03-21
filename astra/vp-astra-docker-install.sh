#!/usr/bin/env bash

#Задаём необходимые версии пакетов докера
CONTAINERD_VER=containerd.io_1.6.9-1_amd64.deb
DOCKER_CE_VER=docker-ce_23.0.1-1~debian.10~buster_amd64.deb
DOCKER_CE_CLI_VER=docker-ce-cli_23.0.1-1~debian.10~buster_amd64.deb
DOCKER_BUILDX_VER=docker-buildx-plugin_0.10.2-1~debian.10~buster_amd64.deb
DOCKER_COMPOSE_VER=docker-compose-plugin_2.16.0-1~debian.10~buster_amd64.deb
CURR_DIR=$( pwd)
USER=$( echo $USER)


#Устанавливаем необходимые компоненты
apt-get update && sudo apt-get upgrade -y
apt-get install ca-certificates curl gnupg lsb-release wget -y

#Выкачиваем нужные пакеты для докера
wget -vc https://download.docker.com/linux/debian/dists/buster/pool/stable/amd64/$CONTAINERD_VER
wget -vc https://download.docker.com/linux/debian/dists/buster/pool/stable/amd64/$DOCKER_CE_CLI_VER
wget -vc https://download.docker.com/linux/debian/dists/buster/pool/stable/amd64/$DOCKER_CE_VER
wget -vc https://download.docker.com/linux/debian/dists/buster/pool/stable/amd64/$DOCKER_COMPOSE_VER
wget -vc https://download.docker.com/linux/debian/dists/buster/pool/stable/amd64/$DOCKER_BUILDX_VER

#Устанавливаем докер
dpkg -i $CONTAINERD_VER $DOCKER_CE_VER $DOCKER_CE_CLI_VER $DOCKER_BUILDX_VER $DOCKER_COMPOSE_VER

#включаем
systemctl start docker
systemctl enable docker

#groupadd docker $$ usermod -aG docker $USER
usermod -aG docker $USER