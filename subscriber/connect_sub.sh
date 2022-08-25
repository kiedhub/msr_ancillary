#!/bin/bash 

# sub_testrun.sh
SERVICE_LIBRARY="subscriber"
DEBUG=true

# grab configuration
SUB_SOURCE=${BASH_SOURCE[0]}
SUB_SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

. $SUB_SCRIPT_DIR/../functions.sh

cd $SUB_SCRIPT_DIR

#subInterface="ens9"
#subSvlan="100"
#subCvlan="200"
#subAccessProto="ipoe"
SET_DNS=false

#create_vlan_interface $subInterface
setup_subscriber 

########################
# put everything into a separate ip namespace
echo "Creating a new ip network namespace: $subName"
ip netns add $subName
echo "Transferring subscriber interface $subInterface to network namespace $subName"
ip link set $subInterface netns $subName

# request ip address and run test
echo "Switch to newly created namespace $subName and request IP address"
#export PS1="$subName netns#"
ip netns exec $subName dhclient

#echo "Show assigned IP address"
#echo "ip netns exec $subName ip a show dev $c_vlan_ifname"
#echo ""
#echo "Show routes"
#echo "$(ip netns exec $subName ip route)"
#echo ""

# setting DNS server through: /run/systemd/resolve/resolv.conf ?
if [ $SET_DNS = true ]; then
  echo "Setting Nameserver due to bug in dhclient"
  ip netns exec $subName echo "nameserver $(resolvectl | grep 'DNS Servers' | awk '{ print $3 }')" 2> /dev/null > /etc/resolv.conf
fi

echo "Entering network namespace $subName"
echo "Exit via 'exit' and './disconnect.sh'"
echo ""

ip netns exec $subName bash --rcfile <(cat ~/.bashrc; echo 'PS1="IP Namespace > "')
exit

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

# if set to 1 then nameserver in namespace will be set 'manually' by copying
# the first DNS Server from resolvctl. This overcomes a bug in latest Ubuntu
# releases where dhclient is not able to properly configure name servers
SET_DNS=1

sub_id=1
sub_name="sub$sub_id"
sub_if="eth1"
s_vlanid=2810
c_vlanid=$((500 + $sub_id))

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
#clear
echo "Checking for existing S-VLAN ($s_vlanid) interface ($s_vlan_ifname)"
# avoid ifconfg (tools may not be installed), using ip link instead
#exist_svlan=$(ifconfig | grep ".$s_vlanid " | wc -l)
exist_svlan=$(ip link show | grep ".$s_vlanid" | wc -l)

if [ $exist_svlan -lt 1 ]; then
  echo "S-VLAN interface ($s_vlan_ifname) not found, setting it up ..."
  ip link add link "$sub_if" address $s_vlan_mac name "$s_vlan_ifname" type vlan id $s_vlanid
  ip link set dev $sub_if up
  ip link set dev "$s_vlan_ifname" up
else
  #sub_if=$(ifconfig | grep -oe ".*\.2810" | cut -d '.' -f1)
  sub_if=$(ip link show | grep -oe ".*\.$s_vlanid" | cut -d '.' -f1 | awk '{ print $2 }')
  echo "S-VLAN ID $s_vlanid exists at $sub_if as $s_vlan_ifname ... nothing to do"
fi

#set up eth link
echo "Setting up C-VLAN ($c_vlanid) interface ($c_vlan_ifname)"
ip link add link $s_vlan_ifname address $c_vlan_mac name $c_vlan_ifname type vlan id $c_vlanid
ip link set dev $c_vlan_ifname up

# put everything into a separate ip namespace
echo "Creating a new ip network namespace: $sub_name"
ip netns add $sub_name
echo "Transferring subscriber interface $c_vlan_ifname to network namespace $sub_name"
ip link set $c_vlan_ifname netns $sub_name

# request ip address and run test
echo "Switch to newly created namespace $sub_name and request IP address"
#export PS1="$sub_name netns#"
ip netns exec $sub_name dhclient

#echo "Show assigned IP address"
#echo "ip netns exec $sub_name ip a show dev $c_vlan_ifname"
#echo ""
#echo "Show routes"
#echo "$(ip netns exec $sub_name ip route)"
#echo ""

if [ $SET_DNS -eq 1 ]; then
  echo "Setting Nameserver due to bug in dhclient"
  ip netns exec $sub_name echo "nameserver $(resolvectl | grep 'DNS Servers' | awk '{ print $3 }')" 2> /dev/null > /etc/resolv.conf
fi

echo "Entering network namespace $sub_name"
echo "Exit via 'exit' and './disconnect.sh'"
echo ""

ip netns exec $sub_name bash --rcfile <(cat ~/.bashrc; echo 'PS1="IP Namespace > "')
