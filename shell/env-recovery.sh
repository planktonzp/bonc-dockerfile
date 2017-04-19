#!/bin/bash

echo bcm平台及kubernetes集群还原脚本启动中....

ssh -t root@192.168.0.24 "pcs cluster setup --start --name high-availability-kubernetes centos-master24 centos-master25 --force"

ssh -t root@192.168.0.24 "pcs resource update virtual-ip IPaddr2 ip=192.168.0.20 --group master"

ssh -t root@192.168.0.20 "pcs resource update apiserver systemcd:kube-apiserver --group master"

ssh -t root@192.168.0.20 "pcs resource update scheduler systemcd:kube-scheduler --group master"

ssh -t root@192.168.0.20 "pcs resource update controller systemcd:kube-controller-manager --group master"

echo 主节点kubernetes服务状态

ssh -t root@192.168.0.20 "pcs status | grep Started | awk '{print $1 $3 $4}' "

echo 负载均衡启动情况

ssh -t root@192.168.0.20 "pcs status | grep ': Online' "

echo 未在线子节点列表，为空时即全部节点正常在线

ssh -t root@192.168.0.20 "systemctl daemon-reload"

ssh -t root@192.168.0.20 "systemctl restart kube-apiserver.service kube-scheduler.service kube-controller-manager.service"

ssh -t root@192.168.0.20 "kubectl get nodes | grep NotReady | awk '{print $1 \"is\" $2}'"

echo 如果存在子节点不在线请请首先确定节点机器是否启动，然后手动连接至节点并重启docker.service,flanneld.service,kubelet.service和kube-proxy.service服务

ssh -t root@192.168.0.29 "mount -t ceph 192.168.0.21:6789:/ /mnt/k8s -o name=admin,secretfile=admin.secret"

echo 启动jenkins服务

ssh -t root@192.168.0.30 "nohup /data01/tomcat/bin/startup.sh &"

echo 启动paas平台

ssh -t root@192.168.0.90 "nohup /home/paas/paas/apache-tomcat-8.0.32/bin/startup.sh &"

ssh -t root@192.168.20.2 "systemctl restart k8sNginxEX.service nginx.service"

ssh -t root@192.168.20.3 "systemctl restart k8sNginxEX.service nginx.service"
