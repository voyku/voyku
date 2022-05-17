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
region_length=0
image_length=0
size_length=0

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
    token=$(cat ~/.do/config | jq .token | tr -d '"')
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

 # -------------------------------如果config中region为空，则此处输入region-------------------------------- 

    elif [[ $1 == "region" ]]; then	  
    doctl compute region list --access-token $token --output json > ~/.do/region.json   
      jq -c '.[]' ~/.do/region.json | while read i; do  
        slug=$(echo $i | jq .slug | tr -d '"') 
        name=$(echo $i | jq .name | tr -d '"')
        echo -e "$slug " >> ~/.do/region.list
        ((region_length=region_length+1))
        echo -e "$region_length.$name"
      done  
    region_text=$(cat ~/.do/region.list)
    region_array=(${region_text})
    read -p "$(print_ok "(请选择region)"):" region_number
    region_selected=`echo ${region_array[$region_number - 1]}`    
    sed '3d' ~/.do/config | sed '2a "region": "'$region_selected'",' | sed '3s/^/ &/g' > ~/.do/region_config
    cp_config region_config	
    rm -rf ~/.do/region.json
	
 # -------------------------------如果config中image为空，则此处输入image-------------------------------- 

    elif [[ $1 == "image" ]]; then    
   doctl compute image list-distribution --access-token $token --output json > ~/.do/image.json	
    jq -c '.[].slug' ~/.do/image.json | tr -d '"' | while read i; do   
        echo -e "$i " >> ~/.do/image.list
        ((image_length=image_length+1))
        echo -e "$image_length.$i"
      done  
    image_text=$(cat ~/.do/image.list)
    image_array=(${image_text})
    read -p "$(print_ok "(请选择image)"):" image_number
    image_selected=`echo ${image_array[$image_number - 1]}`
    sed '4d' ~/.do/config | sed '3a "image": "'$image_selected'",' | sed '4s/^/ &/g' > ~/.do/image_config
    cp_config image_config
    rm -rf ~/.do/image.json	

 # -------------------------------如果config中size为空，则此处输入size--------------------------------
 	   
    elif [[ $1 == "size" ]]; then   
    doctl compute size list --access-token $token --output json > ~/.do/size.json
    jq -c '.[].slug' ~/.do/size.json | tr -d '"' | while read i; do   
        echo -e "$i " >> ~/.do/size.list
        ((size_length=size_length+1))
        echo -e "$size_length.$i"
      done  
    size_text=$(cat ~/.do/size.list)
    size_array=(${size_text})
    read -p "$(print_ok "(请选择size)"):" size_number
    size_selected=`echo ${size_array[$size_number - 1]} | tr -d '"'`
    sed '5d' ~/.do/config | sed '4a "size": "'$size_selected'",' | sed '5s/^/ &/g' > ~/.do/size_config
    cp_config size_config
    rm -rf ~/.do/size.json  

    else
	print_ok "参数有误"
    fi

  else
  	if [[ $1 == "token" ]]; then	
	token=$(cat ~/.do/config | jq .token | tr -d '"')
    elif [[ $1 == "region" ]]; then	
    region_selected=$(cat ~/.do/config | jq .region | tr -d '"')
    elif [[ $1 == "image" ]]; then	
    image_selected=$(cat ~/.do/config | jq .image | tr -d '"')
    elif [[ $1 == "size" ]]; then
    size_selected=$(cat ~/.do/config | jq .size | tr -d '"')
    else
	print_ok "参数有误"
    fi 	

  fi
}

cp_config () {  
  rm -rf config && cp ${1} config && rm -rf ${1}
}

set_instances() {
instances_number=$(cat ~/.do/config | jq .bootNum | tr -d '"')
if [[ $instances_number -eq 1 ]]; then
    inname=`echo $region_selected-$RANDOM`
	exec_launch $inname ;
elif [[ $instances_number -gt 1 ]]; then
    bootNum=$(cat ~/.do/config | jq .bootNum | tr -d '"')	
	for ((i = 1; i <= $bootNum; i++)); do	 
    echo -e "第$i台$region_selected-$i" 
    exec_launch $region_selected-$i ;
done
else
	print_ok "参数有误"
fi
}

exec_launch () {
  doctl compute droplet create --region $region_selected --image $image_selected --size $size_selected --ssh-keys $sshkey_id $1 --access-token $token &>/dev/null;
}

get_ip () {  
  token=$(cat ~/.do/config | jq .token | tr -d '"')
   doctl compute droplet list --access-token $token --output json > ~/.do/droplet.json
   jq -c '.[]' ~/.do/droplet.json | while read i; do   
   date=$(echo $i | jq .networks.v4 ) 
   echo $date > ~/.do/networks.json
     jq -c '.[]' ~/.do/networks.json | while read i; do
     type=$(echo $i | jq .type | tr -d '"' )
     if [[ $type == "public" ]]; then
     ip=$(echo $i | jq .ip_address | tr -d '"')
     print_ok "$ip"
     fi
     done
   done  
   rm -rf ~/.do/networks.json
   rm -rf ~/.do/droplet.json
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
   token=$(cat ~/.do/config | jq .token | tr -d '"')
   doctl compute droplet list --access-token $token --output json > ~/.do/droplet.json
   jq -c '.[]' ~/.do/droplet.json | while read i; do   
   id=$(echo $i | jq .id ) 
   doctl compute droplet delete $id -f --access-token $token ;
   name=$(echo $i | jq .name | tr -d '"')
   print_ok "删除$name"
   done  
   rm -rf ~/.do/droplet.json
}

lmain () {
check_env; 
exec_pre;
set_instances;
get_ip
}

[ "$1" == "destroy" ] && exec_destroy || lmain;
