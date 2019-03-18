#!/bin/bash
docker ps
systemctl stop ecs || echo "ECS already stopped"
rm -f /var/lib/ecs/data/ecs_agent_data.json
echo ECS_CLUSTER=${cluster_name} >> /etc/ecs/ecs.config

if [ "${enable_appdynamics}" == "true" ];
then
    cat << EOF > /tmp/docker_daemon.py
import os.path
import json
config = {}
daemon_config = '/etc/docker/daemon.json'
if os.path.isfile(daemon_config):
    with open(daemon_config, 'r') as f:
       config = json.loads(f.read())

if 'hosts' not in config:
    config['hosts'] = []

config['hosts'].append('unix:///var/run/docker.sock')
config['hosts'].append('tcp://127.0.0.1:2375')

with open(daemon_config, 'w') as f:
    json.dump(config, f)
EOF
    mkdir /etc/docker
    python /tmp/docker_daemon.py
fi

systemctl restart docker
systemctl restart ecs

if [ "${enable_appdynamics}" == "true" ];
then
    ENCRYPTED_AGENT_ACCESS_KEY=${appdynamics_agent_access_key_encrypted} ENCRYPTED_API_USER_KEY=${appdynamics_api_user_key_encrypted} APPLICATION_NAME=${cluster_name} /usr/bin/nohup  /appdynamics/startappdynamics.sh &
fi





