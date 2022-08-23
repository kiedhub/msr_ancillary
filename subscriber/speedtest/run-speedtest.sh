#!/usr/bin/env bash

#source "/home/ubuntu/speedtest/subscriber_lib.sh"
#
## make array associative (hashmap instead of numbered)
#declare -A subscriber
#
## required data
#subscriber[name]='speedtest'
#subscriber[physicalIF]='eth1'
#subscriber[svlan]='2810'
#subscriber[cvlan]='600'
#
## will be set as below or via functions
#subscriber[sIF]="${subscriber[physicalIF]}.${subscriber[svlan]}"
#subscriber[cIF]="${subscriber[sIF]}.${subscriber[cvlan]}"
#subscriber[mac]=""
#subscriber[s_mac]=""
#subscriber[interface]=""
#subscriber[namespace]=""
#subscriber[isConnected]=""
#subscriber[namespaceCmd]=""
#
#subscriber_connect_ipoe
## run speedtest
#backup_cmd=${subscriber[namespaceCmd]}
#
##subscriber[namespaceCmd]="/home/ubuntu/speedtest/librespeed-cli --server 49 --concurrent 3 > /tmp/st_result.txt"
#subscriber[namespaceCmd]="/home/ubuntu/speedtest/run-speedtest.sh"
#subscriber_execute_nscmd
#
#subscriber[namespaceCmd]=$backup_cmd

#subscriber_disconnect_ipoe


/home/ubuntu/speedtest/librespeed-cli --local-json /home/ubuntu/speedtest/custom-server.json --server 1 > /tmp/local_st_result.txt
/home/ubuntu/speedtest/librespeed-cli --server 49 > /tmp/internet_st_result.txt


#local_dwn=$(cat /tmp/local_st_result.txt |grep  -e "Download rate" | cut -d ':' -f2 |sed -e 's/Mbps//' | sed -e 's/.//')
#local_up=$(cat /tmp/local_st_result.txt |grep  -e "Upload rate" | cut -d ':' -f2 |sed -e 's/Mbps//' | sed -e 's/.//')
#internet_dwn=$(cat /tmp/internet_st_result.txt |grep  -e "Download rate" | cut -d ':' -f2 |sed -e 's/Mbps//' | sed -e 's/.//')
#internet_up=$(cat /tmp/internet_st_result.txt |grep  -e "Upload rate" | cut -d ':' -f2 |sed -e 's/Mbps//' | sed -e 's/.//')
##echo $local_dwn $local_up $internet_dwn $internet_up
#
#return_val=$1
#
#case $return_val in 
#
#  loc_dwn)
#    echo $local_dwn
#    ;;
#
#  loc_up)
#    echo $local_up
#    ;;
#
#  int_dwn)
#    echo $internet_dwn
#    ;;
#
#  int_up)
#    echo $internet_up
#    ;;
#
#esac
#
