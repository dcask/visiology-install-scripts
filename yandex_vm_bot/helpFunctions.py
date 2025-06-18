import secrets

import paramiko

import constants


def connect_and_change_password(hostname: str, username: str) -> str:
    """ ssh connect to vm """
    password = secrets.token_urlsafe(12)
    # pkey = paramiko.RSAKey.from_private_key_file()
    client = paramiko.SSHClient()
    policy = paramiko.AutoAddPolicy()
    client.set_missing_host_key_policy(policy)
    client.connect(hostname, username=constants.DEFAULT_ADMIN_USERNAME, key_filename="id_ed25519")
    client.exec_command("sudo useradd -m -s /bin/bash -g 0 visio")
    client.exec_command(f'echo -e "{password}\\n{password}" | sudo passwd "{username}"')
    client.exec_command(
        'sudo sed -i -E "s#PasswordAuthentication no#PasswordAuthentication yes#g" /etc/ssh/sshd_config')
    _stdin, stdout, _stderr = client.exec_command(
        'sudo sed -i -E "s#PasswordAuthentication no#PasswordAuthentication yes#g" /etc/ssh/sshd_config.d/*.conf')
    client.exec_command(f'sudo systemctl restart ssh')
    client.close()
    return password
