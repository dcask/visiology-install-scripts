#!/bin/bash -e

deadcontainers= $(docker ps -a | grep -P '^(?=.*cr.yandex)(?=.*Exited)' | awk '{print $1}')
if [[ -n ${deadcontainers} ]]; then
   docker container rm ${deadcontainers}
fi

killvolumes=$(docker volume ls --format "{{.Name}}" | grep visiology)
if [[ -n ${killvolumes} ]];  then
  docker volume rm ${killvolumes} -f
fi

killsecrets=$(docker secret ls --format "{{.Name}}" -q)
if [[ -n ${killsecrets} ]]; then
  docker secret rm ${killsecrets}
fi

killconfigs=$(docker config ls --format "{{.Name}}" -q)
if [[ -n ${killconfigs} ]]; then
  docker config rm ${killconfigs}
fi
killimages=$(docker images --filter=reference='cr.yandex/crpe1mi33uplrq7coc9d/visiology/release/*' --format "{{ .Repository }}:{{ .Tag }}")
if [[ -n ${killimages} ]]; then
  docker rmi ${killimages}
fi

if [ -d /docker-volume ]; then
  rm -r /docker-volume
fi

if [ -d /var/lib/visiology ]; then
  rm -r /var/lib/visiology
fi
