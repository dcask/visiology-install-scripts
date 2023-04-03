#!/usr/bin/env bash

#вкл\выкл дебаг
#set -x

#объявляем переменные
DATE=$(date '+%H.%M.%S_%d.%m.%y')
WORKDIR=$(pwd)
LOGDIR=$(mktemp -d /tmp/visiology_logs.XXXXXX)
DOCKERSERVICES=$(docker service ls --format "{{.Name}}")

#переходим в рабочую папку, куда сложатся логи
cd "$LOGDIR"

#собираем логи с сервисов
while read -r line; do
    docker service logs -t --raw "$line" &> "$line".log
done <<< "$DOCKERSERVICES"

#архивируем логи в домашний каталог пользователя
tar -zcvf /"$WORKDIR"/visiology_log_"$DATE".tar.gz "$LOGDIR"