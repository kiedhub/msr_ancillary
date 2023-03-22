#!/usr/bin/env bash

# st_testrun.sh
# runs a speed test and populates results via snmp

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
STDOUT=`readlink -f /proc/$$/fd/1`
STDERR=`readlink -f /proc/$$/fd/2`
#exec > ~/sub_testrun.log 2>&1
#exec < /dev/null
#set -x

##############################################################################

# definitions

sub_name="speedtest"
sub_if="eth1"
s_vlanid=2810
c_vlanid=501

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

# put everything into a separate ip namespace
ip netns add $sub_name
ip link set $c_vlan_ifname netns $sub_name

# request ip address and run test
ip netns exec $sub_name dhclient

################################
# here we have to add our code
# old script did: ip netns exec $sub_name ~/run-speedtest.sh
ip netns exec $sub_name ip a
ip netns exec $sub_name ip route

################################

# reset back to original 
# release ip address, reset dns server and delete ip link and namespace
ip netns exec $sub_name dhclient -r
echo "nameserver 8.8.8.8" > /etc/resolv.conf

# delete interface in ip namespace
ip netns exec $sub_name ip link del dev $c_vlan_ifname

# delete namespace
ip netns del $sub_name

#exec 1>$STDOUT 2>$STDERR
#cat ~/sub_testrun.log |grep -v "^+"
