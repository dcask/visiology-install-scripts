import json
import logging
import time
from datetime import datetime

import jwt
import requests
import yandexcloud

from yandex.cloud.iam.v1.iam_token_service_pb2 import (CreateIamTokenRequest)
from yandex.cloud.iam.v1.iam_token_service_pb2_grpc import IamTokenServiceStub

import constants

logger = logging.getLogger(__name__)


class YandexCloud:
    service_account_id = None
    private_key = None
    key_id = None
    sa_key = None
    token = None

    def __init__(self, token: str, cloud_id: str):
        """ init """
        YandexCloud.token = token
        self.cloud_id = cloud_id
        self.folders_list = []

    @staticmethod
    def read_key(key_path: str):
        """ read service account key file """
        with open(key_path, 'r') as f:
            obj = f.read()
            obj = json.loads(obj)
            YandexCloud.private_key = obj['private_key']
            YandexCloud.key_id = obj['id']
            YandexCloud.service_account_id = obj['service_account_id']

        YandexCloud.sa_key = {
            "id": YandexCloud.key_id,
            "service_account_id": YandexCloud.service_account_id,
            "private_key": YandexCloud.private_key
        }

    @staticmethod
    def create_jwt(sec: int):
        """ make jwt token """
        now = int(time.time())
        payload = {
            'aud': constants.TOKEN_AUD,
            'iss': YandexCloud.service_account_id,
            'iat': now,
            'exp': now + sec
        }

        # Формирование JWT.
        encoded_token = jwt.encode(
            payload,
            YandexCloud.private_key,
            algorithm='PS256',
            headers={'kid': YandexCloud.key_id}
        )

        return encoded_token

    @staticmethod
    def create_iam_token(sec: int):
        """ convert jwt token to iam token """
        jwt = YandexCloud.create_jwt(sec)

        sdk = yandexcloud.SDK(service_account_key=YandexCloud.sa_key)
        iam_service = sdk.client(IamTokenServiceStub)
        iam_token = iam_service.Create(
            CreateIamTokenRequest(jwt=jwt)
        )

        YandexCloud.token = iam_token.iam_token

    def get_finished_vms(self) -> (str, list):
        """ find expired vm """
        return_string = ''
        vm_list = []
        now_date = datetime.today().date()

        if not self.folders_list:
            self.get_folders()

        for folder in self.folders_list:
            uri = f'{constants.INSTANCES_API_ENDPOINT}?folderId={folder['id']}'
            response = self.send_command("GET", uri)

            if response['statusCode'] == 200:
                instances = response['body'].get('instances', [])

                for instance in instances:
                    labels = instance.get('labels', {})
                    vm_id = instance.get('id')
                    end_date_label = labels.get('end-date')
                    owner_name = labels.get('owner-name')

                    if end_date_label:

                        logger.info(labels)
                        end_date = now_date

                        try:
                            end_date = datetime.strptime(end_date_label, '%Y-%m-%d').date()
                        except ValueError:
                            logger.error(f"Can't parse the date at {vm_id}")

                        if end_date < now_date:
                            description = instance.get('description')
                            if labels.get('chat-id'):
                                vm_list.append(
                                    {
                                        "chat-id": labels.get('chat-id'),
                                        "name": instance.get('name'),
                                        "description": description
                                    }
                                )
                            return_string += f'💥 `{vm_id}`, владелец {owner_name}\n'
                            logger.info(f'⚠ Истёк срок для VM {vm_id}, владелец {owner_name}\n')
                            if description:
                                return_string += f'Описание: {description}\n'
                            logger.info(return_string)
            else:
                logger.error(f"Can't get instances for {folder['id']}. {response['body']}")
        return f'{constants.ALARM_HEADER} {return_string}' if return_string else '', vm_list

    def set_end_date_mark(self, yandex_vm_id: str, end_date_mark: str) -> (bool, str):
        """ patch vm with new date mark """
        uri = f"{constants.INSTANCES_API_ENDPOINT}/{yandex_vm_id}"

        response = self.send_command('GET', uri)

        if response['statusCode'] == 200:
            labels = response['body'].get('labels', {})
            labels['end-date'] = end_date_mark
            body = {
                "updateMask": "labels",
                "labels": labels,
            }
            response = self.send_command('patch', uri, body)

            if response['statusCode'] != 200:
                logger.error(f"Can't set end date mark for {yandex_vm_id} Error: {response['body']}")
                return False, response['body']

            return True, ''

        logger.error(f"Can't set end date mark for {yandex_vm_id} Error: {response['body']}")
        return False

    def send_command(self, method: str, request_uri: str, body=None) -> dict:
        """ api request """
        if body is None:
            body = {}

        timeout_value = 10
        req_headers = {'Authorization': f'Bearer {YandexCloud.token}', "Content-Type": "application/json"}

        response = requests.request(method, request_uri, json=body,
                                    headers=req_headers,
                                    timeout=timeout_value)
        return {'statusCode': response.status_code, 'body': json.loads(response.text)}

    def get_folders(self):
        """ read folders list """
        uri = f'{constants.FOLDERS_API_ENDPOINT}?cloudId={self.cloud_id}'
        response = self.send_command('GET', uri)

        if response['statusCode'] == 200:
            self.folders_list = response['body']['folders']
        else:
            logger.error(f"Can't get folders for {self.cloud_id}. {response['body']}")

    def create_vm(self, param_list: dict[str, str]) -> (bool, str):
        """ make new vm """
        logger.info(f'Param: {param_list}')
        vm = {
            "metadata": {
                "user-data": param_list['userdata']
            },
            "resourcesSpec": {
                "memory": str(int(param_list['ram']) * 1024 * 1024 * 1024),
                "cores": param_list['cores'],
                "coreFraction": param_list['coreFraction'],
            },
            "metadataOptions": {
                "gceHttpEndpoint": "ENABLED",
                "awsV1HttpEndpoint": "ENABLED",
                "gceHttpToken": "ENABLED",
                "awsV1HttpToken": "DISABLED"
            },
            "bootDiskSpec": {
                "autoDelete": True,
                "diskSpec": {
                    "imageId": param_list['os'],
                    "typeId": param_list['disk-type'],
                    "size": str(int(param_list['disk-size']) * 1024 * 1024 * 1024),
                }
            },
            "networkInterfaceSpecs": [{
                "primaryV4AddressSpec": {
                    "oneToOneNatSpec": {
                        "ipVersion": "IPV4"
                    },
                },
                "subnetId": "fl81m930i3f7d6g9o36k"
            }
            ],
            "serialPortSettings": {
                "sshAuthorization": "OS_LOGIN"
            },
            "gpuSettings": {},
            "schedulingPolicy": {
                "preemptible": param_list['preemptible'],
            },

            "networkSettings": {
                "type": "STANDARD"
            },
            "placementPolicy": {},
            "hardwareGeneration": {
                "legacyFeatures": {
                    "pciTopology": "PCI_TOPOLOGY_V1"
                }
            },
            "folderId": param_list['folderId'],
            "name": param_list['name'],
            "labels": {"end-date": param_list['end-date'], "owner-name": param_list['owner'],
                       "chat-id": param_list['chat-id']},
            "description": param_list['description'],
            "zoneId": "ru-central1-d",
            "platformId": "standard-v3",
        }
        uri = f"{constants.INSTANCES_API_ENDPOINT}"

        response = self.send_command('POST', uri, vm)

        if response['statusCode'] == 200:
            instance_id = response['body']['metadata']['instanceId']

            while True:
                response = self.send_command('GET', f"{uri}/{instance_id}")
                if response['statusCode'] == 200:
                    if response['body']['status'] == 'RUNNING':
                        break
                else:
                    return False, response['body']

            return True, response['body']["networkInterfaces"][0]["primaryV4Address"]["oneToOneNat"]["address"]

        else:
            logger.error(f"Failed to create vm. {response['body']}")

        return False, response['body']

# if __name__ == '__main__':
#     yandex_cloud = YandexCloud('', 'b1g3pabmir8kr1grc3or')
#     yandex_cloud.read_key("key.json")
#     yandex_cloud.create_iam_token(3600)
#     param_list = {}
#     param_list['cores']="2"
#     param_list['ram']="2"
#     param_list['coreFraction']="20"
#     param_list['os']="fd80j21lmqard15ciskf"
#     param_list['disk-type']="network-hdd"
#     param_list['disk-size']="20"
#     param_list['preemptible']=True
#     param_list['end-date']="2025-10-10"
#     param_list['owner']="kurinskiy"
#     param_list['chat-id']="596959268"
#     param_list['description']="Тест"
#     param_list['folderId']="b1gr18v94jkia73gmmd3"
#     param_list['name']="test-vm"
#     param_list['userdata']="#cloud-config\nusers:\n- name: visio-admin\n  sudo: ALL=(ALL) NOPASSWD:ALL\n  shell: /bin/bash\n  ssh-authorized-keys:\n  - ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIK5E3vIxpbDFg9fPuIPGtWw8q98A2OGfii6FayNudfBx admin@visiology-2025"
#     ok, txt = yandex_cloud.create_vm(param_list)
#     # password = helpFunctions.connect_and_change_password(txt, constants.DEFAULT_USERNAME)
#     print(txt)
