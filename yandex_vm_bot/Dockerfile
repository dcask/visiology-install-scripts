###
###  docker build -t cr.yandex/crpe1mi33uplrq7coc9d/visiology/dev/stuff/git-archivator:v1 .
###

FROM python:3.12.4-slim-bullseye

WORKDIR /app

COPY requirements.txt /app/requirements.txt

RUN apt-get update && \
    pip install --upgrade pip && \
    pip install -r /app/requirements.txt

COPY . /app

ENTRYPOINT ["python", "/app/main.py"]
