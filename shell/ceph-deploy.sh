#!/bin/bash

#############################################Functions#############################################
function color_echo() {
  if [ $1 == "green" ]
  then
      echo -e "\033[32;40m$2\033[0m"
  elif [ $1 == "red" ]
  then
      echo -e "\033[31;40m$2\033[0m"
  fi
}
function os_version() {
  local OS_V=$(cat /etc/os-release | grep "\<ID\>" | cut -d '=' -f 2)
  if [ $OS_V == \"centos\" -o $OS_V == "CentOS" ]
  then
      echo "CentOS"
  elif [ $OS_V == arch ]
  then
      echo "Arch"
  fi
}
function local_env_check() {
### selinux 检查
  color_echo green "开始检查selinux状态"
  SELINUX_STATUS=sudo getenforce
  if [[ $SELINUX_STATUS == Disabled ]]
  then
    color_echo green " selinux关闭"
  elif [[ $SELINUX_STATUS == Enforcing ]]
  then
    color_echo red " selinux未关闭，已为您永久关闭，重启前为临时关闭"
    sudo setenforce 0 > /dev/null
    sudo sed -i 's/^[^#]SELINUX=.*/SELINUX=disabled/g' /etc/selinux/config
  else
    color_echo red " selinux为临时关闭，已为您永久关闭，重启后生效"
    sudo sed -i 's/^[^#]SELINUX=.*/SELINUX=disabled/g' /etc/selinux/config
  fi
### firewalld 检查
  color_echo green "开始检查防火墙状态"
  if $(sudo rpm -qa | grep firewalld >/dev/null)
  then
    if [[ $(sudo systemctl list-unit-file | grep firewalld | awk {'print $2'}) == enable ]]
    then
      systemctl stop $(sudo systemctl list-unit-file | grep firewalld | awk {'print $1'}) > /dev/null
      systemctl disable $(sudo systemctl list-unit-file | grep firewalld | awk {'print $1'}) > /dev/null
      color_echo red "防火墙开机启动，已为您关闭"
    else
      color_echo green "防火墙已关闭"
    fi
  else
    color_echo green "未安装防火墙"
  fi
}
function arch_install_deps() {
  if $(sudo pacman -S expect ntp wget --noconfirm | grep "Updating the info directory file" > /dev/null 2>&1 )
  then
    color_echo green "依赖安装完成"
  else
    color_echo red "依赖安装出现问题，请检查网络状况"
    exit 1
  fi
  sudo systemctl enable ntpd ntpdate.service
  sudo systemctl restart ntpd.service
}
function centos_install_deps() {
  if $(sudo yum install expect yum-plugin-priorities wget ntp ntpdate ntp-doc epel-release.noarch -y | grep "Complete" >/dev/null )
  then
    color_echo green "依赖安装完成"
  else
    color_echo red "依赖安装出现问题，请检查网络状况"
    exit 1
  fi
  sudo systemctl enable ntpd ntpdate.service
  sudo systemctl restart ntpdate.service
  sudo systemctl restart ntpd.service
}
function check_ssh_auth() {
    if $(grep "Permission denied" $EXP_TMP_FILE >/dev/null); then
        color_echo red " $IP SSH 认证失败! 密码错误."
        exit 1
    elif $(ssh $INFO 'echo yes >/dev/null'); then
        color_echo green " $IP SSH 认证成功."
    fi
    rm $EXP_TMP_FILE >/dev/null
}
function generate_keypair() {
  if [ ! -e ~/.ssh/id_rsa.pub ]
  then
      color_echo green "公/私密钥对未找到，初始化中..."
      expect -c "
          spawn ssh-keygen
          expect {
              \"ssh/id_rsa):\" {send \"\r\";exp_continue}
              \"passphrase):\" {send \"\r\";exp_continue}
              \"again:\" {send \"\r\";exp_continue}
          }
      " >/dev/null 2>&1
      if [ -e ~/.ssh/id_rsa.pub ]
      then
          color_echo green "成功创建公/私密钥对"
      else
          color_echo red "公/私密钥对创建失败"
          exit 1
      fi
  fi
}
function set_nickname() {
  read -p "请为此节点设置一个简单的名称:" NICKNAME
  NICKNAME_CHK=$(cat ~/.ssh/config | grep $NICKNAME | awk {'print $2'}|uniq)
  color_echo green "原配置已备份为config.bak"
  cp ~/.ssh/config ~/.ssh/config.bak
  if [[ $NICKNAME_CHK == $NICKNAME ]]
  then
    color_echo red "此别名已被占用"
    set_nickname
  else
    color_echo green " 别名创建成功 "
    echo "Host $NICKNAME" >> ~/.ssh/config
    echo "   Hostname $IP" >> ~/.ssh/config
    echo "   User $USER" >> ~/.ssh/config
    color_echo green " 文件已更新为： "
    cat $HOME/.ssh/config
  fi
}
function ssh_copy_id_keypair() {
  if [[ $1 =~ ^[a-z]+@[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}@.* ]]
  then
      generate_keypair
      for i in $@
      do
          USER=$(echo $i|cut -d@ -f1)
          IP=$(echo $i|cut -d@ -f2)
          PASS=$(echo $i|cut -d@ -f3)
          INFO=$USER@$IP
          expect -c "
              spawn ssh-copy-id $INFO
              expect {
                  \"(yes/no)?\" {send \"yes\r\";exp_continue}
                  \"password:\" {send \"$PASS\r\";exp_continue}
              }
          " > $EXP_TMP_FILE  #各种日志会记录在这个文件内
          check_ssh_auth
          set_nickname
          echo "$IP    $NICKNAME" >> /etc/hosts
          color_echo green "$IP    $NICKNAME"
      done
      color_echo red "建议在进行下一步之前将该文本复制并记录下来方便后面操作填写"
  elif [[ $1 =~ ^[a-z]+@[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}-[0-9]{1,3}@.* ]]
  then
      generate_keypair
      START_IP_NUM=$(echo $1|sed -r 's/.*\.(.*)-(.*)@.*/\1/')
      END_IP_NUM=$(echo $1|sed -r 's/.*\.(.*)-(.*)@.*/\2/')
      for ((i=$START_IP_NUM;i<=$END_IP_NUM;i++))
      do
          USER=$(echo $1|cut -d@ -f1)
          PASS=$(echo $1|cut -d@ -f3)
          IP_RANGE=$(echo $1|sed -r 's/.*@(.*\.).*/\1/')
          IP=$IP_RANGE$i
          INFO=$USER@$IP_RANGE$i
          expect -c "
              spawn ssh-copy-id $INFO
              expect {
                  \"(yes/no)?\" {send \"yes\r\";exp_continue}
                  \"password:\" {send \"$PASS\r\";exp_continue}
              }
          " > $EXP_TMP_FILE
          check_ssh_auth
          set_nickname
          echo "$IP    $NICKNAME" >> /etc/hosts
          color_echo green "$IP    $NICKNAME"
      done
      color_echo red "建议在进行下一步之前将该文本复制并记录下来方便后面操作填写"
  elif [[ $1 =~ ^[a-z]+@[a-zA-Z0-9\_\-]+@.* ]]
  then
      generate_keypair
      for i in $@
      do
          USER=$(echo $i|cut -d@ -f1)
          IP=$(echo $i|cut -d@ -f2)
          PASS=$(echo $i|cut -d@ -f3)
          INFO=$USER@$IP
          expect -c "
              spawn ssh-copy-id $INFO
              expect {
                  \"(yes/no)?\" {send \"yes\r\";exp_continue}
                  \"password:\" {send \"$PASS\r\";exp_continue}
              }
          " > $EXP_TMP_FILE
          check_ssh_auth
          set_nickname
      done
  else
    color_echo red "您的输入有误，请参考示例填写"
    exit 1
  fi
}
function scp_repo(){
  for A in $1
  do
    scp /etc/yum.repos.d/ceph.repo $A:/etc/yum.repos.d/ceph.repo
  done
}
function ssh_install_deps() {
  for AA in $1
  do
    ssh -t $AA "sudo yum install expect yum-plugin-priorities wget ntp ntpdate ntp-doc epel-release.noarch -y" > /dev/null 2>&1
    ssh -t $AA "sudo yum install -y ceph ceph-radosgw" > /dev/null 2>&1
    echo "$AA 节点已安装完成"
  done
}
function add_ceph_osd() {
  read -p "请输入作为osd的节点别名(多个时请用空格分开)：" CEPH_OSD_NODE
  echo "用作OSD的目录或磁盘将被清理，请悉知"
  read -p "您打算将磁盘还是目录用于OSD守护进程？(DISK/DIR)" DORD
  if [[ $DORD == DISK ]]
  then
    for AAA in $CEPH_OSD_NODE
    do
      read -p "请输入$AAA 节点用于OSD进程的磁盘分区，并确保该分区可用" OSD_DISK
      ssh -t $AAA "sudo umount $OSD_DISK && sudo sed -i \"s/$OSD_DISK/# &\" /etc/fstab"
      ceph-deploy disk zap $AAA:$OSD_DICK > /dev/null 2>&1
      ceph-deploy osd prepare $AAA:$OSD_DICK
      ceph-deploy osd activate $AAA:$OSD_DICK
    done
  elif [[ $DORD == DIR ]]
  then
    for AAA in $CEPH_OSD_NODE
    do
      read -p "请为$AAA 节点创建用于OSD的目录，并确保该目录存在并为空目录" OSD_DIR
      ssh -t $AAA "mkdir -p $OSD_DIR && chmod -R 777 $OSD_DIR" > /dev/null 2>&1
      ceph-deploy osd prepare $AAA:$OSD_DIR
      ceph-deploy osd activate $AAA:$OSD_DIR
    done
  else
    color_echo red "您的输入有误，请重试"
    add_ceph_osd
  fi
}
function add_ceph_rgw() {
  read -p "请输入您想作为对象网关的节点别名(多个请用空格隔开)：" CEPH_RGW_NODE
  for AAAAAA in $CEPH_RGW_NODE
  do
    ceph-deploy --overwrite-conf rgw create $AAAAAA
  done
}
function add_ceph_mds() {
  read -p "请输入您想作为元数据服务器的节点别名(多个时请用空格隔开)：" CEPH_MDS_NODE
  for AAAA in $CEPH_MDS_NODE
  do
    ceph-deploy --overwrite-conf mds create $AAAA
    ssh -t $AAAA "ceph osd pool create metadata 64 64 && ceph osd pool create data 64 64 && ceph fs new cephfs metadata data && systemctl restart ceph-mds@$AAAA"
  done
}
function add_ceph_mon() {
  read -p "请输入您想作为MON的节点别名(多个请用空格隔开)：" CEPH_MON_NODE
  read -p "请输入节点子网(含掩码)：" SUBNET_ADDRESS
  sed -i "\$a\public_network = $SUBNET_ADDRESS" ceph.conf
  for AAAAA in $CEPH_MDS_NODE
  do
    read -p "请输入该节点ip(很重要)：" CEPH_MON_IP
    sed -i "s/mon_initial_members = /&$AAAAA,/" ceph.conf
    sed -i "s/mon_host = /&$CEPH_MON_IP,/"ceph.sonf
    ceph-deploy --overwrite-conf mon add $AAAAA
  done
}
function install() {
  color_echo green " 即将开始安装 "
  color_echo green " loading.... "
  mkdir -p /opt/ceph-rzp/my-cluster && cd /opt/ceph-rzp/my-cluster
  color_echo green " 更新yum源中... "
  sudo echo -e "[Ceph] \n
name=Ceph packages for $basearch \n
baseurl=http://mirrors.aliyun.com/ceph/rpm-jewel/el7/$basearch \n
enabled=1 \n
gpgcheck=0 \n
priority=1 \n
 \n
[Ceph-noarch] \n
name=Ceph noarch packages \n
baseurl=http://mirrors.aliyun.com/ceph/rpm-jewel/el7/noarch \n
enabled=1 \n
gpgcheck=0 \n
priority=1 \n
 \n
[ceph-source] \n
name=Ceph source packages \n
baseurl=http://download.ceph.com/rpm-jewel/el7/SRPMS \n
enabled=0 \n
priority=1 \n
gpgcheck=1 \n
type=rpm-md \n
gpgkey=https://download.ceph.com/keys/release.asc " > /etc/yum.repos.d/ceph.repo
  sudo yum update && sudo yum install ceph-deploy -y > /dev/null 2>&1
  color_echo green " 当前目录为$PWD"
  read -p "请输入您要作为管理节点的设备别名：" ADMIN_NODE
  ceph-deploy new $ADMIN_NODE
  read -p "请输入需要安装ceph的节点别名(用空格隔开)：" CEPH_NODE
  scp_repo $CEPH_NODE > /dev/null 2>&1
  color_echo green "正在为各节点安装依赖的包，请耐心等候"
  ssh_install_deps $CEPH_NODE > /dev/null 2>&1
  color_echo green "正在为各节点安装ceph，请耐心等候"
  ceph-deploy install $CEPH_NODE
  color_echo green "正在收集密钥"
  ceph-deploy mon create-initial
  color_echo green "开始进行创建与激活osd"
  add_ceph_osd
  add_ceph_mon
  add_ceph_mds
}
function uninstall() {
  color_echo green " 即将开始卸载 "
  color_echo green " loading.... "
}
function reset() {
  color_echo green " 即将开始重置 "
  color_echo green " loading.... "
}

###########################################Functions_END###########################################

###ENV Check & Generating Public/Private RSA Key Pair
EXP_TMP_FILE=/tmp/expect_ssh.tmp
color_echo red " 请确保您知道自己在做什么，并确认您所在集群的防火墙已关闭 "
color_echo red " 作者: Dipper Roy  Gmail: ruizhipeng001@gmail.com "
color_echo green " 检查本地环境"
local_env_check
color_echo red "Example1: <root@192.168.1.10-15@password>"
color_echo red "Example2: <root@192.168.1.10@password>"
color_echo red "Example3: [root@192.168.1.10@password root@192.168.1.11@password root@192.168.1.12@password ...]"
read -p "即将进行集群内设备免密登陆认证，请参考示例填写信息：" SSH_MSG
ssh_copy_id_keypair $SSH_MSG

###Check system OS
read -p "您的系统为$(os_version)，请确认您是以root用户执行，否则将请求询问sudo密码，以下将进行脚本依赖检测及安装，是否继续？ (Y/n)" ANS

if [[ $ANS == N || $ANS == n ]]
then
  color_echo red "安装已取消"
else
  if [[ $(os_version) == "Centos" ]]
  then
    centos_install_deps
  elif [[ $(os_version) == Arch ]]
  then
    arch_install_deps
  else
    color_echo red "对不起，暂不支持您的系统"
  fi
fi

###Install Ceph
set timeout 300
read -p " 请输入要执行的操作( Install/Uninstall/Reset ) " CMD

if [[ $CMD == Install ]]
then
  install
elif [[ $CMD == Uninstall ]]
then
  uninstall
elif [[ $CMD == Reset ]]
then
  reset
else
  color_echo red " 您的输入是 $CMD "
  color_echo red " 似乎有错误，请检查确认."
fi
