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
    cd ~ 
    FOLDER=~/.do
    FILE=~/.do/config
    if [ -d "$FOLDER" ]; then       
       if test -f "$FILE"; then
        cd .do ;
        set_config
       else
         cd .do && wget https://raw.githubusercontent.com/voyku/voyku/main/do/config && chmod 600 config
         set_config
       fi
    else
      mkdir .do && chmod 600 .do && cd .do && wget https://raw.githubusercontent.com/voyku/voyku/main/do/config && chmod 600 config
      set_config
    fi
    doctl compute ssh-key list --access-token $token --output json > ~/.do/keylist.json
    date=$(cat ~/.do/keylist.json)
    if [[ $token == "[]" ]]
    then
    wget https://raw.githubusercontent.com/voyku/voyku/main/key/smithao.pub && chmod 600 smithao.pub  
    doctl compute ssh-key import smithao --public-key-file smithao.pub --access-token $token --output json > ~/.do/sshkey.json
    sshkey_id=$(cat ~/.do/sshkey.json | jq .id )
    rm -rf smithao.pub && rm -rf ~/.do/sshkey.json
    else 
    sshkey_id=$(cat ~/.do/keylist.json | jq .[0].id )
    rm -rf ~/.do/keylist.json
    fi    
}

set_config () {  
    read_config token  ;
    read_config region ;
    read_config image ;
    read_config size ;
}

read_config () {
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
  	if [[ $1 == "token" ]]; then	
	token=$(cat ~/.do/config | jq .token | tr -d '"')
    elif [[ $1 == "region" ]]; then	
    region=$(cat ~/.do/config | jq .region | tr -d '"')
    elif [[ $1 == "image" ]]; then	
    image=$(cat ~/.do/config | jq .image | tr -d '"')
    elif [[ $1 == "size" ]]; then
    size=$(cat ~/.do/config | jq .size | tr -d '"')
    else
	break 
    fi 	
  fi
}

cp_config () {  
  rm -rf config && cp ${1} config && rm -rf ${1}
}

exec_launch () {
  doctl compute droplet create --region $region --image $image --size $size --ssh-keys $sshkey_id one --access-token $token
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
exec_launch	
}

[ "$1" == "destroy" ] && exec_destroy || lmain;
