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
D="debian"
C="centos"
U="ubuntu"
gcp_cfg="$HOME/.gcp/config";
config="$HOME/.gcp/config";
url="https://raw.githubusercontent.com/voyku/voyku/main/script/cmd.sh";

ins () {
# install extra deps
apt update -y &>/dev/null || yum makecache fast &>/dev/null || dnf makecache fast &>/dev/null;
apt install -y -q $1 &>/dev/null || yum install -q -y $1 &>/dev/null || dnf install -q -y $1 &>/dev/null;
}

ins_oci () {
# install gcp-cli when gcp-cli command not found
a=`uname  -a`
uname=$(echo $a | tr [A-Z] [a-z])
if [[ $uname =~ $D ]] || [[ $uname =~ $U ]] ;then
  sudo apt-get install apt-transport-https ca-certificates gnupg
  echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | sudo tee -a /etc/apt/sources.list.d/google-cloud-sdk.list
  curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key --keyring /usr/share/keyrings/cloud.google.gpg add -
  sudo apt-get update && sudo apt-get -y  upgrade && sudo apt-get install google-cloud-cli
elif [[ $uname =~ $C ]];then
  sudo tee -a /etc/yum.repos.d/google-cloud-sdk.repo << eof
[google-cloud-cli]
name=Google Cloud CLI
baseurl=https://packages.cloud.google.com/yum/repos/cloud-sdk-el8-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=0
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg
       https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
eof
  sudo yum install google-cloud-cli
else
    echo $uname
fi  
}



check_env () {
# do some prepare
command -v jq &>/dev/null || ins jq;
command -v curl &>/dev/null || ins curl;
command -v wget &>/dev/null || ins wget;
command -v gcloud &>/dev/null || ins_oci;

FOLDER=~/.gcp
if [ -d "$FOLDER" ]; then            
   if test -f "$gcp_cfg"; then
       echo "yes"
   else
       cd $FOLDER && wget https://github.com/voyku/voyku/blob/main/gcp/config && chmod 600 config         
   fi
else
    mkdir $FOLDER && chmod 600 $FOLDER
    cd $FOLDER && wget https://github.com/voyku/voyku/blob/main/gcp/config && chmod 600 config       
fi  
cd ~ ; 
auth_json=$(gcloud auth list --format json)
status=$(echo $auth_json | jq .[0].status | tr -d '"')
if [[ $status == "ACTIVE" ]]
then
echo "yes"
else
gcloud init --console-only
fi

}

set_info () {
# set the necessary parameters
type=$(cat $gcp_cfg | jq .type | tr -d '"')
if [[ $type == "default" ]]; then
    print_ok "(type为default)"
elif [[ $type == "do" ]]; then
	config="$HOME/.gcp/do.config";
	url="https://raw.githubusercontent.com/voyku/voyku/main/do/do.sh";
	print_ok "(type为do)"
elif [[ $type == "az" ]]; then
	config="$HOME/.gcp/az.config";
	url="https://raw.githubusercontent.com/voyku/voyku/main/az/az.sh";
	print_ok "(type为az)"
elif [[ $type == "orc" ]]; then
	config="$HOME/.gcp/orc.config";
	url="https://raw.githubusercontent.com/voyku/voyku/main/orc/orc.sh";
	print_ok "(type为orc)"
elif [[ $type == "lin" ]]; then
	config="$HOME/.gcp/lin.config";
	print_ok "(type为lin)"
elif [[ $type == "s5" ]]; then	
	url="https://raw.githubusercontent.com/voyku/voyku/main/script/socks5.sh";
	print_ok "(type为s5)"
elif [[ $type == "vless" ]]; then	
	print_ok "(type为vless)"
else
	print_ok "(请自定义~/.gcp/cool.sh)"
	if test -f "~/.gcp/cool.sh"; then
      exit 1      
   fi
	config="$HOME/.gcp/cool.sh";
fi
size=$(cat $gcp_cfg | jq .size | tr -d '"')
gaccount_json=$(gcloud iam service-accounts list --format json) 
account=$(echo $gaccount_json | jq .[0].email | tr -d '"')
projectnow_json=$(gcloud compute project-info describe --format json)
project=$(echo $projectnow_json | jq .name | tr -d '"')
network="network-tier=PREMIUM,subnet=default"
scopes="https://www.googleapis.com/auth/devstorage.read_only,https://www.googleapis.com/auth/logging.write,https://www.googleapis.com/auth/monitoring.write,https://www.googleapis.com/auth/servicecontrol,https://www.googleapis.com/auth/service.management.readonly,https://www.googleapis.com/auth/trace.append"
}

set_zone () {
zone_name=""
zone_length=0
area_length=0
gcloud compute zones list --format json > /root/zone.json
jq -c '.[].name' /root/zone.json | tr -d '"' | while read i; do
    zone_name2=`echo ${i%-*}`
    if [ "$zone_name2" != "$zone_name" ]; then
    zone_name=$zone_name2
    ((zone_length=zone_length+1))     
    echo -e "$zone_name2 " >> zone.txt
    echo -e "$zone_length.$zone_name2"
    fi
done  
zone=$(cat zone.txt)
zone_array=(${zone})
read -p "$(print_ok "(选择区域)"):" zone_number
zone_selected=`echo ${zone_array[$zone_number - 1]}`
rm -rf zone.txt
jq -c '.[].name' /root/zone.json | tr -d '"' | while read i; do
    zone_name2=`echo ${i%-*}`
    if [ "$zone_name2" == "$zone_selected" ]; then
    ((area_length=area_length+1))     
    echo -e "$i " >> area.txt
    echo -e "$area_length.$i"
    fi
done  
area=$(cat area.txt)
area_array=(${area})
read -p "$(print_ok "(选择可用区)"):" area_number
area_selected=`echo ${area_array[$area_number - 1]}`
inname=`echo ${area_selected//-/}`
rm -rf area.txt
rm -rf zone.json
print_ok "—————————————— region为$area_selected ——————————————"	
disk_debian="auto-delete=yes,boot=yes,device-name=$inname,image=projects/debian-cloud/global/images/debian-11-bullseye-v20220406,mode=rw,size=10,type=projects/$project/zones/$area_selected/diskTypes/pd-balanced"	
disk_centos="auto-delete=yes,boot=yes,device-name=$inname,image=projects/centos-cloud/global/images/centos-7-v20220406,mode=rw,size=20,type=projects/$project/zones/$area_selected/diskTypes/pd-balanced"	 
disk_ubuntu="auto-delete=yes,boot=yes,device-name=$inname,image=projects/ubuntu-os-cloud/global/images/ubuntu-1804-bionic-v20220505,mode=rw,size=10,type=projects/$project/zones/$area_selected/diskTypes/pd-balanced"
image=$(cat $gcp_cfg | jq .image | tr -d '"')
if [[ $image == "centos" ]]; then
   disk=$disk_centos;
elif [[ $image == "ubuntu" ]]; then	
	disk=$disk_ubuntu;
elif [[ $image == "debian" ]]; then	
	disk=$disk_debian;
else
	print_ok "参数有误"
	exit 1
fi
}



set_instances() {
bootNum=$(cat $gcp_cfg | jq .bootNum | tr -d '"')
if [[ $bootNum -eq 1 ]]; then	
	inname_random=`echo $inname$RANDOM`
	exec_launch $inname_random ;
elif [ $bootNum -gt 1 ] && [ $bootNum -le 4 ]; then	
	for_instances $bootNum ;
elif [ $bootNum -gt 4 ] && [ $bootNum -le 12 ]; then	
	pre_projects_json=$(gcloud projects list --format json)
	pre_length=$(echo $pre_projects_json | jq '. | length')
	if [[ $pre_length -lt 2 ]]; then	   
	gcloud projects create project-two --name="projectwo"
	fi   
	gcloud projects list --format json > /root/projects.json
	project_length=0
	jq -c '.[].projectId' /root/projects.json | tr -d '"' | while read i; do
    ((project_length=project_length+1))
	gcloud config set project $i
	set_info
    if [[ $project_length -eq 1 ]]; then	   
	for_instances 4 ;
	elif [[ $project_length -eq 2 ]]; then	   
	for_instances $(($bootNum-4)) ;   
	else
	   break 
    fi	   
    done 
    rm -rf /root/projects.json	   
else
	break 
fi
}

for_instances () {
for ((i = 1; i <= $1; i++)); do	 
  echo -e "第$i台$inname$i" 
  exec_launch $inname$i ;
done
}

exec_launch () {
gcloud compute instances create $1 \
    --project=$project \
	--zone=$area_selected \
	--machine-type=$size \
	--network-interface=${network} \
	--metadata-from-file=startup-script=$config \
	--metadata=ssh-keys=smithao:ssh-rsa\ AAAAB3NzaC1yc2EAAAABJQAAAQEAohFX9JoZusjJMfA2S2xEQeMgKu7u9TRiEhChh0psgP3yF7sICxVSPZQt\+kIYrXEffDRlajlxt78NecRKqfiRh2D4HL0okrESrHOAJ97HZloA9hVPimfAt5oMvzggrVZilN41iaZX4lxYlu8r6fFeZjBocvRs3VN/6JZt1Naj8KGnuLL22wl9UzXeGrw6D2GRtiki6qGNcaNE2mdL4f5y6DGsCHMPqw2a/MrkE9bXX8XYjhd3\+zRa9PNoYV6XoVX0o9E184jrIekOhK892g/kjtbzrNpwUbhDZlVYSifUAVD7URrqZWB8W0nIMjaOTfcyG/Y4yhwR/cSZksstje6IaQ==\ smithao,startup-script-url=$url \
	--maintenance-policy=MIGRATE \
	--provisioning-model=STANDARD \
	--service-account=${account} \
	--scopes=${scopes} \
	--tags=http-server,https-server \
	--create-disk=${disk} \
	--no-shielded-secure-boot \
	--shielded-vtpm \
	--shielded-integrity-monitoring \
	--reservation-affinity=any;
}

function print_ok() {
echo -e "${OK} ${Blue} $1 ${Font}"
}

exec_destroy () {
gcloud compute instances list --format json > /root/instances.json
jq -c '.[]' /root/instances.json | while read i; do
  instance_name=$(echo $i | jq .name | tr -d '"')
  instance_zone=$(echo $i | jq .zone | tr -d '"')
  print_ok "—————————————— 删除$instance_name ——————————————" 
  printf y  | gcloud compute instances delete $instance_name --zone=$instance_zone &>/dev/null
done   
rm -rf /root/instances.json
}

lmain () {
check_env; 
set_info;
set_zone;
set_instances;	
}

[ "$1" == "destroy" ] && exec_destroy || lmain;
