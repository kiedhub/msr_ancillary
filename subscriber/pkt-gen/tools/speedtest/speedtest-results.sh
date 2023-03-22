#!/usr/bin/env bash


local_dwn=$(cat /tmp/local_st_result.txt |grep  -e "Download rate" | cut -d ':' -f2 |sed -e 's/Mbps//' | sed -e 's/.//')
local_up=$(cat /tmp/local_st_result.txt |grep  -e "Upload rate" | cut -d ':' -f2 |sed -e 's/Mbps//' | sed -e 's/.//')
internet_dwn=$(cat /tmp/internet_st_result.txt |grep  -e "Download rate" | cut -d ':' -f2 |sed -e 's/Mbps//' | sed -e 's/.//')
internet_up=$(cat /tmp/internet_st_result.txt |grep  -e "Upload rate" | cut -d ':' -f2 |sed -e 's/Mbps//' | sed -e 's/.//')

return_val=$1

# present result in bits per sec

case $return_val in 

  loc_dwn)
    #echo $local_dwn
    echo $(echo $local_dwn 1000000 | awk '{printf "%d\n",$1*$2}')
    ;;

  loc_up)
    echo $(echo $local_up 1000000 | awk '{printf "%d\n",$1*$2}')
    ;;

  int_dwn)
    echo $(echo $internet_dwn 1000000 | awk '{printf "%d\n",$1*$2}')
    ;;

  int_up)
    echo $(echo $internet_up 1000000 | awk '{printf "%d\n",$1*$2}')
    ;;

esac

