#!/usr/bin/env bash


# 字体颜色配置
Green="\033[32m"
Red="\033[31m"
Yellow="\033[33m"
Blue="\033[36m"
Font="\033[0m"
GreenBG="\033[42;37m"
RedBG="\033[41;37m"
OK="${Green}[OK]${Font}"
ERROR="${Red}[ERROR]${Font}"

ins () {
# install extra deps
apt update -y &>/dev/null || yum makecache fast &>/dev/null || dnf makecache fast &>/dev/null;
apt install -y -q $1 &>/dev/null || yum install -q -y $1 &>/dev/null || dnf install -q -y $1 &>/dev/null;
}

ins_oci () {
# install do-cli when do-cli command not found
cd ~
tag_name=`curl -s https://api.github.com/repos/digitalocean/doctl/releases/latest | grep tag_name|cut -f4 -d "\""`
wget https://github.com/digitalocean/doctl/releases/download/${tag_name}/doctl-${tag_name: 1}-linux-amd64.tar.gz
tar xf ~/doctl-${tag_name: 1}-linux-amd64.tar.gz
sudo mv ~/doctl /usr/local/bin
export PATH=$PATH:/usr/local/bin;
. $HOME/.bashrc;
}

exec_pre () {

	read -p "$(print_ok "(请输入Token)"):" token
	wget -N --no-check-certificate -q -O smithao.pub https://raw.githubusercontent.com/voyku/voyku/main/key/smithao.pub && chmod 600 smithao.pub
	doctl compute ssh-key import smithao --public-key-file smithao.pub --access-token $token --output json
	rm -rf smithao.pub
    
}

exec_launch () {
  print_ok 66
}

check_env () {
# do some prepare
command -v jq &>/dev/null || ins jq;
command -v wget &>/dev/null || ins wget;
command -v curl &>/dev/null || ins curl;
command -v doctl &>/dev/null || ins_oci;   
}


function print_ok() {
echo -e "${OK} ${Blue} $1 ${Font}"
}

exec_destroy () {
   print_ok 66
}

lmain () {
check_env; 
exec_pre;	
}

[ "$1" == "destroy" ] && exec_destroy || lmain;
