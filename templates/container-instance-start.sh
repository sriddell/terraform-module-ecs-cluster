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


docker ps #workaround for issue https://github.com/aws/amazon-ecs-agent/issues/389
service docker restart && start ecs





