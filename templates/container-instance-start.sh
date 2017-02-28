#!/bin/bash

stop ecs || echo "ECS already stopped"

rm /var/lib/ecs/data/ecs_agent_data.json

echo ECS_CLUSTER=${cluster_name} >> /etc/ecs/ecs.config

cat << EOF > /etc/sysconfig/docker
# The max number of open files for the daemon itself, and all
# running containers.  The default value of 1048576 mirrors the value
# used by the systemd service unit.
DAEMON_MAXFILES=1048576

# Additional startup options for the Docker daemon, for example:
# OPTIONS="--ip-forward=true --iptables=true"
# By default we limit the number of open files per container
OPTIONS="--log-driver=json-file --log-opt max-size=1m --log-opt max-file=20 --default-ulimit nofile=1024:4096"
EOF


##Install sumo.  This all should probably go into ansible for a prebake
cd /tmp
curl -o sumo.sh https://collectors.sumologic.com/rest/download/linux/64
chmod 744 sumo.sh

instance_id=$(curl http://169.254.169.254/latest/meta-data/instance-id)

mkdir -p /opt/SumoCollector/config
cat << EOF > /opt/SumoCollector/config/sources.json
{
    "api.version": "v1",
    "sources": [
        {
            "sourceType": "LocalFile",
            "name": "Docker Container Logs",
            "pathExpression": "/var/lib/docker/containers/*/*.log",
            "category": "ecs/local/${cluster_name}",
            "hostName": "$instance_id",
            "useAutolineMatching": false,
            "multilineProcessingEnabled": false,
            "timeZone": "UTC",
            "automaticDateParsing": true,
            "forceTimeZone": false,
            "defaultDateFormat": "dd/MMM/yyyy HH:mm:ss"
        }
    ]
}
EOF


./sumo.sh -q -vskipRegistration=true -Vemphemeral=true -Vcollector.name="ecs-${cluster_name}-$instance_id" -Vsources=/opt/SumoCollector/config/sources.json -Vsumo.accessid=suYSVkpXr6QFNd -Vsumo.accesskey=pNpzXqopkBYfAMHcxyJp2jxJhADznMkHUbc7e8Mpnue7WcQSW7s8hgl0bO9e3DqX
cd /etc/init.d/

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


docker ps #workaround for issue https://github.com/aws/amazon-ecs-agent/issues/389
service docker restart && start ecs



