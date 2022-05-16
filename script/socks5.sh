#!/usr/bin/env bash
yum install -y wget &&  wget --no-check-certificate https://raw.github.com/Lozy/danted/master/install.sh -O install.sh 
bash install.sh --port=1500 --user=123 --passwd=456