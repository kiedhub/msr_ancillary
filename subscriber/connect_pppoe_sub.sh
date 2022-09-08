#!/bin/bash 

# sub_testrun.sh
SERVICE_LIBRARY="subscriber"
DEBUG=true

# grab configuration
SUB_SOURCE=${BASH_SOURCE[0]}
SUB_SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

. $SUB_SCRIPT_DIR/../functions.sh

cd $SUB_SCRIPT_DIR

SET_DNS=false

usage()
{
  echo "connecting a pppoe subscriber ipv4 only or dual-stack"
  echo "  usage: ./connnect_pppoe_sub [v4|ds]"
  echo "  example: ./connnect_pppoe_sub v4"
  echo

}

setIPv6option()
{
  [ $DEBUG = true ] && echo "${FUNCNAME[0]} (Action: $1)"

  sIPv6action=$1

  ! [ -e /etc/ppp/options ] && { echo "  File /etc/ppp/options does not exist, exiting." ; exit ; }

  [ $(sudo cat /etc/ppp/options | grep "^[ ^I]*+ipv6 ipv6cp-use-ipaddr" | wc -l) -gt 0 ] && \
    hasIPv6option=true || \
    hasIPv6option=false

  case $sIPv6action in
    add)
      [ $hasIPv6option = false ] && { \
        [ $DEBUG = true ] && echo "  Adding IPv6 option to /etc/ppp/options"; \
        sudo echo "+ipv6 ipv6cp-use-ipaddr" >> /etc/ppp/options; \
      }
      ;;
    remove)
      [ $hasIPv6option = true ] && { \
      [ $DEBUG = true ] && echo "  Removing IPv6 option from /etc/ppp/options"; \
        sudo mv /etc/ppp/options /etc/ppp/options.orig; \
        sudo cat /etc/ppp/options.orig | sed -e 's/+ipv6 ipv6cp-use-ipaddr/#+ipv6 ipv6cp-use-ipaddr/' \
          > /etc/ppp/options ; \
        }
      ;;
    *)
      [ $DEBUG = true ] && echo "  Wrong parameter, use remove or add"
      ;;
  esac


}


[ -z $1 ] && testCase=v4 || testCase=$1

case $testCase in
  v4)
    sName=$sub2Name
    sInterface=$sub2Interface
    sAccessProto=$sub2AccessProto
    setIPv6option remove
    ;;
  ds)
    sName=$sub3Name
    sInterface=$sub3Interface
    sAccessProto=$sub3AccessProto
    setIPv6option add
    ;;
  *)
    usage
    ;;
esac

echo "Parameters: $sName, $sInterface, $sAccessProto"
#subName=$sub2Name
#subInterface=$sub2Interface
#subAccessProto=$sub2AccessProto

#subName=$sub3Name
#subInterface=$sub3Interface
#subAccessProto=$sub3AccessProto

#sub2Name="pppoE-Sub"
#sub2Interface="ens8.200.2048"
#sub2AccessProto="pppoe"

create_vlan_interface $sInterface
subPty="pty \"\/usr\/sbin\/pppoe -I $sInterface -T 80 -m 1452\""
sudo cat /etc/ppp/peers/dsl-provider | sed -e "s/^pty .*$/$subPty/" -e "s/^auth/noauth/" > /etc/ppp/peers/dsl-provider100

#[ $DEBUG = true ] && sudo cat /etc/ppp/peers/dsl-provider100

#create_subscriber 
########################
# put everything into a separate ip namespace
echo "Creating a new ip network namespace: $sName"
ip netns add $sName
echo "Transferring subscriber interface $sInterface to network namespace $sName"
ip link set $sInterface netns $sName

echo "Switch to newly created namespace $sName and request IP address"

ip netns exec $sName pon dsl-provider100 
sleep 5

# setting DNS server through: /run/systemd/resolve/resolv.conf ?
if [ $SET_DNS = true ]; then
  echo "Setting Nameserver due to bug in dhclient"
  ip netns exec $sName echo "nameserver $(resolvectl | grep 'DNS Servers' | awk '{ print $3 }')" 2> /dev/null > /etc/resolv.conf
fi

echo "Entering network namespace $sName"
echo "Exit via 'exit' and './disconnect.sh'"
echo "pppoe connectivity may require a couple of seconds."
echo ""

ip netns exec $sName bash --rcfile <(cat ~/.bashrc; echo 'PS1="IP Namespace > "')

exit
