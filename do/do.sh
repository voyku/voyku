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
    cd ~ && rm -rf .do&& mkdir .do && chmod 600 .do && cd .do && rm -rf config
    wget https://raw.githubusercontent.com/voyku/voyku/main/do/config && chmod 600 config
    wget https://raw.githubusercontent.com/voyku/voyku/main/key/smithao.pub && chmod 600 smithao.pub  
    set_config token ;
    set_config region ;
    set_config image ;
    set_config size ;
	doctl compute ssh-key import smithao --public-key-file smithao.pub --access-token $token --output json
	rm -rf smithao.pub
    
}

set_config () {
  text=$(cat ~/.do/config | jq .$1 | tr -d '"')
  if [[ $text == "" ]]
    then
    if [[ $1 == "token" ]]; then	
	read -p "$(print_ok "(请输入Token)"):" token
	sed '2d' ~/.do/config | sed '1a "token": "'$token'",' | sed '2s/^/ &/g' > ~/.do/token_config
	cp_config token_config
    elif [[ $1 == "region" ]]; then	
    read -p "$(print_ok "(请选择region)"):" region
    sed '3d' ~/.do/config | sed '2a "region": "'$region'",' | sed '3s/^/ &/g' > ~/.do/region_config
    cp_config region_config
    elif [[ $1 == "image" ]]; then	
    read -p "$(print_ok "(请选择image)"):" image
    sed '4d' ~/.do/config | sed '3a "image": "'$image'",' | sed '4s/^/ &/g' > ~/.do/image_config
    cp_config image_config
    elif [[ $1 == "size" ]]; then
    read -p "$(print_ok "(请选择size)"):" size
    sed '5d' ~/.do/config | sed '4a "size": "'$size'"' | sed '5s/^/ &/g' > ~/.do/size_config
    cp_config size_config
    else
	break 
    fi
  else
  	$1=$text
  fi
}

cp_config () {  
  rm -rf config && cp ${1} config && rm -rf ${1}
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
