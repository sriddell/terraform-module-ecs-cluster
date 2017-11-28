#!/bin/bash
stop ecs || echo "ECS already stopped"
rm /var/lib/ecs/data/ecs_agent_data.json
echo ECS_CLUSTER=${cluster_name} >> /etc/ecs/ecs.config
if [ "${workspace_endpoint}" != "" ];
then
    yum update
    yum -y install nfs-utils
    DIR_SRC=${workspace_endpoint}
    DIR_TGT=/mnt/efs/workspaces
    mkdir -p $DIR_TGT
    mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2 $DIR_SRC:/ $DIR_TGT
    cp -p /etc/fstab /etc/fstab.back-$(date +%F)
    echo -e "$DIR_SRC:/ \t\t $DIR_TGT \t\t nfs \t\t defaults \t\t 0 \t\t 0" | tee -a /etc/fstab
fi

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

docker ps #workaround for issue https://github.com/aws/amazon-ecs-agent/issues/389
service docker restart && start ecs

if [ "${enable_appdynamics}" == "true" ];
then
    ENCRYPTED_AGENT_ACCESS_KEY=${appdynamics_agent_access_key_encrypted} ENCRYPTED_API_USER_KEY=${appdynamics_api_user_key_encrypted} APPLICATION_NAME=${cluster_name} /usr/bin/nohup  /appdynamics/startappdynamics.sh &
fi





