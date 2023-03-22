#!/bin/bash 

##############################################################################
# common script header (adapt log file name)
# The script has to be run as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root!"
   echo "Issue a 'sudo bash' before running it."
   exit 1
fi

# set up logging
# first store existing output redirects
# use "exec 1>$STDOUT 2>$STDERR" whenever you want to restore 
# STDOUT=`readlink -f /proc/$$/fd/1`
# STDERR=`readlink -f /proc/$$/fd/2`
#exec > ~/sub_testrun.log 2>&1
#exec < /dev/null
#set -x

##############################################################################

# definitions

healthcheck_file="/tmp/healthcheck_status"

sub_id=999
sub_name="sub$sub_id"
sub_if="eth1"
s_vlanid=2810
c_vlanid=$sub_id

s_vlan_ifname="$sub_if.$s_vlanid"
c_vlan_ifname="$s_vlan_ifname.$c_vlanid"

# prepend 0s to lt 4 digit vlan ids (just to get mac addresses set according to vids)
s_vlanid_lenght=${#s_vlanid}
c_vlanid_lenght=${#c_vlanid}

if [ $s_vlanid_lenght -eq 1 ]; then
  s_vlanid_padded="000$s_vlanid"
elif [ $s_vlanid_lenght -eq 2 ]; then
  s_vlanid_padded="00$s_vlanid"
elif [ $s_vlanid_lenght -eq 3 ]; then
  s_vlanid_padded="0$s_vlanid"
elif [ $s_vlanid_lenght -eq 4 ]; then
  s_vlanid_padded="$s_vlanid"
else
  echo "wrong s_vlanid length, please fix in script"
  exit 0
fi

if [ $c_vlanid_lenght -eq 1 ]; then
  c_vlanid_padded="000$c_vlanid"
elif [ $c_vlanid_lenght -eq 2 ]; then
  c_vlanid_padded="00$c_vlanid"
elif [ $c_vlanid_lenght -eq 3 ]; then
  c_vlanid_padded="0$c_vlanid"
elif [ $c_vlanid_lenght -eq 4 ]; then
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

s_vlan_mac="00:00:$s_vlanid_hundrets:$s_vlanid_tenths:00:00"
c_vlan_mac="00:00:$s_vlanid_hundrets:$s_vlanid_tenths:$c_vlanid_hundrets:$c_vlanid_tenths"

api_call() {
  echo "nameserver 8.8.8.8" > /etc/resolv.conf

  if [ -z $1 ]; then
    err_msg=default
  else
    err_msg=$1
  fi

  # netw_err or dhcp_err
  case $err_msg in
    netw_err) 
      spm_result=$(curl -s "https://www.pushsafer.com/api?k=yUEdu7uR15NBeTuv7zbH&pr=2&m=Edge%20Hub%20Pilot%3A%20Lost%20Internet%20connectivity")
      ;;
    dhcp_err)
      spm_result=$(curl -s "https://www.pushsafer.com/api?k=yUEdu7uR15NBeTuv7zbH&pr=2&m=Edge%20Hub%20Pilot%3A%20No%20DHCP%20Lease")
      ;;
    netw_rest)
      spm_result=$(curl -s "https://www.pushsafer.com/api?k=yUEdu7uR15NBeTuv7zbH&pr=2&m=Edge%20Hub%20Pilot%3A%20Internet%20Connectivity%20restored")
      ;;
    default)
      spm_result=$(curl -s "https://www.pushsafer.com/api?k=yUEdu7uR15NBeTuv7zbH&pr=2&m=Edge%20Hub%20Pilot%3A%20Unspecified%20Failure")
      ;;
  esac

  is_transmitted=$(echo $spm_result | grep -oe "success.*message transmitted" | wc -l )

  if [ $is_transmitted -lt 1 ]; then
    #echo "sending failed $is_transmitted"
    echo "FAILED"
    return
  else
    #echo "successfully transmitted $is_transmitted"
    echo "SUCCESS"
    return
  fi

}

send_push_msg() {
  # netw_err or dhcp_err
  err_type=$1
  # raise alarm via push safer
  if [[ $(api_call "$err_type") = "SUCCESS" ]]; then
    echo "FAILED AND SENT ALARM" > $healthcheck_file
    return
  else
    echo "NO SUCCESS - FAILED TO SEND ALARM" > $healthcheck_file
    return
  fi
}

connect_sub() {
  #check for s-vlan
  #echo "Checking for existing S-VLAN ($s_vlanid) interface ($s_vlan_ifname)"
  exist_svlan=$(ifconfig | grep ".$s_vlanid " | wc -l)
  
  if [ $exist_svlan -lt 1 ]; then
    #echo "S-VLAN interface ($s_vlan_ifname) not found, setting it up ..."
    ip link add link "$sub_if" address $s_vlan_mac name "$s_vlan_ifname" type vlan id $s_vlanid
    ip link set dev $sub_if up
    ip link set dev "$s_vlan_ifname" up
  else
    sub_if=$(ifconfig | grep -oe ".*\.2810" | cut -d '.' -f1)
    #echo "S-VLAN ID $s_vlanid exists at $sub_if as $s_vlan_ifname ... nothing to do"
  fi
  
  #set up eth link
  #echo "Setting up C-VLAN ($c_vlanid) interface ($c_vlan_ifname)"
  #echo "ip link add link $s_vlan_ifname address $c_vlan_mac name $c_vlan_ifname type vlan id $c_vlanid"
  ip link add link $s_vlan_ifname address $c_vlan_mac name $c_vlan_ifname type vlan id $c_vlanid
  #echo "ip link set dev $c_vlan_ifname up"
  ip link set dev $c_vlan_ifname up
  
  # put everything into a separate ip namespace
  #echo "Creating a new ip network namespace: $sub_name"
  ip netns add $sub_name
  ip link set $c_vlan_ifname netns $sub_name
  
  # request ip address and run test
  # adapted /etc/dhcp/dhclient.conf to 1 retry and 2 sec timeout
  ip netns exec $sub_name dhclient 
}

disconnect_sub() {
  
  ip netns exec $sub_name dhclient -r
  echo "nameserver 8.8.8.8" > /etc/resolv.conf
  
  ip netns exec $sub_name ip link del dev $c_vlan_ifname
  
  ip netns del $sub_name
  
}

ping_healthcheck() {
  hch_result=$(ip netns exec "$sub_name" ping -c 1 -W 1 8.8.8.8)
  # covers everything after dhcp address was assignd (network error)
  packet_loss=$(echo $hch_result | grep -oe "[0-9]*% packet loss" | cut -d '%' -f1)

  # result if no ip address was assigned (dhcp error)
  netw_unreachable=$(echo $hch_result | grep "Network is unreachable" | wc -l)
  if [ $netw_unreachable -gt 0 ]; then
    echo "NO DHCP LEASE"
    return
  fi

  #echo $packet_loss
  if [ ! -z $packet_loss ]; then 
    if [ $packet_loss -gt 0 ]; then
      # packets lost, healthcheck failed
      echo "FAILED"
      return
    else
      # no packet loss, healthcheck succeeded
      echo "SUCCESS"
      return
    fi
  fi

}

prev_healthcheck() {
  if [ ! -f $healthcheck_file ]; then
    echo "SUCCESS"
    return
  fi
  if [ $(cat $healthcheck_file | grep "FAILED" | wc -l) -ge 1 ]; then
    echo "FAILED"
    return
  fi
  if [ $(cat $healthcheck_file | grep "SUCCESS" | wc -l) -ge 1 ]; then
    echo "SUCCESS"
    return
  fi
}


logger "Healthcheck script: Connecting subscriber"

connect_sub

logger "Healthcheck script: Starting Healthcheck to 8.8.8.8"

if [[ $(ping_healthcheck) = "SUCCESS" ]]; then
  if [[ $(prev_healthcheck) = "FAILED" ]]; then
    logger "Healthcheck script: First success after outage, sending push notification"
    send_push_msg netw_rest
  echo "SUCCESS" > $healthcheck_file
  logger "Healthcheck script: Healthcheck successful"
    
  fi
fi

if [[ $(ping_healthcheck) = "FAILED" && $(prev_healthcheck) = "SUCCESS" ]]; then
  logger "Healthcheck script: Healthcheck failed (packet loss > 0%), sending push message"
  send_push_msg netw_err
fi

if [[ $(ping_healthcheck) = "NO DHCP LEASE" && $(prev_healthcheck) = "SUCCESS" ]]; then
  logger "Healthcheck script: Healthcheck failed (no dhcp lease), sending push message"
  send_push_msg dhcp_err 
fi

if [[ ( $(ping_healthcheck) = "NO DHCP LEASE" || $(ping_healthcheck) = "NO DHCP LEASE" ) && $(prev_healthcheck) = "SUCCESS" ]]; then
  logger "Healthcheck script: Healthcheck continuesly failed, push message already sent"
fi
#ip netns exec $sub_name bash --rcfile <(cat ~/.bashrc; echo 'PS1="IP Namespace > "')

logger "Healthcheck script: Disconnecting subscriber"
disconnect_sub
