#!/bin/bash
read -p "请输入要重启服务的节点名称（多个请用空格隔开）" $NODE_NAME
for num in `$NODE_NAME`
do
	echo "正在重启 $num 上的服务"
	ssh -t root@$num "systemctl restart flanneld.service kubelet.service kube-proxy.service"
done
