#!/usr/bin/env bash

# subscriber_lib.sh
# common subscriber functions

log (){
  msg=$1
  logger "Speedtest script: $msg"
}

subscriber_generate_mac_address (){
  # generates subscriber mac address based on provided s- and c-vlan tag
  # example parameters s-vlan: 2810, c-vlan: 500
  # example (00:00:28:10:05:00)
  # requires: subscriber[svlan], subscriber[cvlan]
  # sets:     subscriber[mac], subscriber[s_mac]
  
  s_vlanid=${subscriber[svlan]}
  c_vlanid=${subscriber[cvlan]}
  
  # prepend 0s to lt 4 digit vlan ids (just to get mac addresses set according to vids)
  s_vlanid_length=${#s_vlanid}
  c_vlanid_length=${#c_vlanid}
  
  # pad s-vlan mac part
  if [ $s_vlanid_length -eq 1 ]; then
    s_vlanid_padded="000$s_vlanid"
  elif [ $s_vlanid_length -eq 2 ]; then
    s_vlanid_padded="00$s_vlanid"
  elif [ $s_vlanid_length -eq 3 ]; then
    s_vlanid_padded="0$s_vlanid"
  elif [ $s_vlanid_length -eq 4 ]; then
    s_vlanid_padded="$s_vlanid"
  else
    echo "wrong s_vlanid $s_vlanid length $s_vlanid_length, please fix in script"
    exit 0
  fi
  
  # pad c-vlan mac part
  if [ $c_vlanid_length -eq 1 ]; then
    c_vlanid_padded="000$c_vlanid"
  elif [ $c_vlanid_length -eq 2 ]; then
    c_vlanid_padded="00$c_vlanid"
  elif [ $c_vlanid_length -eq 3 ]; then
    c_vlanid_padded="0$c_vlanid"
  elif [ $c_vlanid_length -eq 4 ]; then
    c_vlanid_padded="$c_vlanid"
  else
    echo "wrong c_vlanid length, please fix in script"
    exit 0
  fi
  
  # split into 255 bit junks for mac address
  s_vlanid_hundrets=$(echo $s_vlanid_padded | grep -oe "^..")
  s_vlanid_tenths=$(echo $s_vlanid_padded | grep -oe "..$")
  c_vlanid_hundrets=$(echo $c_vlanid_padded | grep -oe "^..")
  c_vlanid_tenths=$(echo $c_vlanid_padded | grep -oe "..$")
  
  subscriber[s_mac]="00:00:$s_vlanid_hundrets:$s_vlanid_tenths:00:00"
  subscriber[mac]="00:00:$s_vlanid_hundrets:$s_vlanid_tenths:$c_vlanid_hundrets:$c_vlanid_tenths"
  
}

subscriber_create_sub_if (){
  # generates a subscriber (and required sub-) interface in the form of
  # eth1.2810.500
  # requires: subscriber[svlan], subscriber[physicalIF], subscriber[s_mac]
  # sets:     subscriber[interface]
  
  sub_if=${subscriber[physicalIF]}
  s_vlanid=${subscriber[svlan]}
  s_vlan_ifname=${subscriber[sIF]}
  s_vlan_mac=${subscriber[s_mac]}
  c_vlan_ifname=${subscriber[cIF]}
  c_vlan_mac=${subscriber[mac]}
  
  #check for s-vlan
  exist_svlan=$(ifconfig | grep ".$s_vlanid " | wc -l)
  
  if [ $exist_svlan -lt 1 ]; then
    echo "S-VLAN not found, setting it up ..."
    ip link add link "$sub_if" address $s_vlan_mac name "$s_vlan_ifname" type vlan id $s_vlanid
    ip link set dev $sub_if up
    ip link set dev "$s_vlan_ifname" up
  else
    sub_if=$(ifconfig | grep -oe ".*\.2810" | cut -d '.' -f1)
    echo "s_vlanid $s_vlanid exists at $sub_if ... nothing to do"
  fi
  
  #set up eth link
  ip link add link $s_vlan_ifname address $c_vlan_mac name $c_vlan_ifname type vlan id $c_vlanid
  ip link set dev $c_vlan_ifname up
}

subscriber_destroy_sub_if (){
  # delete interface in ip namespace
  # requires: subscriber[namespace]; subscriber[cIF]
  # sets:     
  sub_namespace=${subscriber[namespace]}
  c_vlan_ifname=${subscriber[cIF]}
  
  ip netns exec $sub_name ip link del dev $c_vlan_ifname
  
}

subscriber_create_netns (){
  # set up a network namespace to separate activities
  # requires: subscriber[name]; subscriber[cIF]
  # sets:     subscriber[namespace];
  # put everything into a separate ip namespace
  sub_name=${subscriber[name]}
  c_vlan_ifname=${subscriber[cIF]}
  
  ip netns add $sub_name
  ip link set $c_vlan_ifname netns $sub_name

  subscriber[namespace]=$sub_name
}

subscriber_destroy_netns (){
  # destroys ip namespace
  # requires: subscriber[namespace];
  # sets:     subscriber[namespace];
  sub_namespace=${subscriber[namespace]}
  ip netns del $sub_namespace
  subscriber[namespace]=""

}

subscriber_iprequest_ipoe (){
  # connectes an ipoe subscriber
  # set up a network namespace to separate activities
  # requires: subscriber[name]; subscriber[cIF]
  # sets:     subscriber[isConnected] 
  
  sub_namespace=${subscriber[namespace]} 
  # request ip address and run test
  ip netns exec $sub_namespace dhclient

  subscriber[isConnected]=TRUE

}

subscriber_iprelease_ipoe (){
  # disconnectes an ipoe subscriber
  # release ip address, reset dns server and delete ip link and namespace
  # requires: subscriber[namespace];
  # sets:     subscriber[isConnected];
  ip netns exec $sub_name dhclient -r
  echo "nameserver 8.8.8.8" > /etc/resolv.conf
  subscriber[isConnected]=FALSE

}

subscriber_execute_nscmd (){
  # executes a command in the subscribers namespace
  # has the advantage that onle the command has to be provided
  # as all other subscriber parameters already exist
  # requires: subscriber datastructure
  # sets: nothing

  # first we check that the subscriber is connected
  # and the namespace exist
  if [ -z "${subscriber[namespace]}" ]; then
    echo "No ip namespace for subscriber named \"${subscriber[name]}\""
    exit
  else
    sub_namespace=${subscriber[namespace]}
  fi
  
  if [ -z "${subscriber[namespaceCmd]}" ]; then
    echo "No command to execute, please provide \"namespaceCmd\" in the script you are running. "
    exit
  else
    ns_cmd=${subscriber[namespaceCmd]}
  fi
 
  ip netns exec $sub_namespace $ns_cmd

}

subscriber_connect_ipoe (){
  # connect subscriber by creating interface, namespace and request IP address
  # datastructure requirements see functions
  subscriber_generate_mac_address
  # echo "Generated MAC addresses: ${subscriber[s_mac]} and ${subscriber[mac]}"
  subscriber_create_sub_if
  # echo "Created subscriber interface ${subscriber[interface]}"
  subscriber_create_netns
  # echo "Created ip namespace: ${subscriber[namespace]}"
  subscriber_iprequest_ipoe

}

subscriber_disconnect_ipoe (){
  # disconnect subscriber by release IP address, namespace and deleting interface
  # datastructure requirements see functions
  subscriber_iprelease_ipoe
  # echo "Released IP address "
  subscriber_destroy_sub_if
  # echo "Destroyed subscriber interface ${subscriber[interface]}"
  subscriber_destroy_netns
  # echo "Destroyed network namespace ${subscriber[namespace]}"

}


########################################################################
# script sample

# make array associative (hashmap instead of numbered)
declare -A subscriber

# required data
subscriber[name]='speedtest'
subscriber[physicalIF]='eth1'
subscriber[svlan]='2810'
subscriber[cvlan]='600'

# will be set as below or via functions
subscriber[sIF]="${subscriber[physicalIF]}.${subscriber[svlan]}"
subscriber[cIF]="${subscriber[sIF]}.${subscriber[cvlan]}"
subscriber[mac]=""
subscriber[s_mac]=""
subscriber[interface]=""
subscriber[namespace]=""
subscriber[isConnected]=""
subscriber[namespaceCmd]=""

subscriber_connect_ipoe
## run speedtest
#backup_cmd=${subscriber[namespaceCmd]}
#
#log "executing speedtest now..."
#subscriber[namespaceCmd]="/home/ubuntu/speedtest/run-speedtest.sh"
#subscriber_execute_nscmd
#
#subscriber[namespaceCmd]=$backup_cmd
#
#loc_dwn=$(/home/ubuntu/speedtest/speedtest-results.sh loc_dwn)
#loc_up=$(/home/ubuntu/speedtest/speedtest-results.sh loc_up)
#int_dwn=$(/home/ubuntu/speedtest/speedtest-results.sh int_dwn)
#int_up=$(/home/ubuntu/speedtest/speedtest-results.sh int_up)
#
#log "results: Local downstream    $loc_dwn bits/sec"
#log "results: Local upstream      $loc_up bits/sec"
#log "results: Internet downstream $int_dwn bits/sec"
#log "results: Internet upstream   $int_up bits/sec"
#
subscriber_disconnect_ipoe

########################################################################
