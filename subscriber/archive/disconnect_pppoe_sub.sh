#!/usr/bin/env bash

# sub_testrun.sh
# sub_testrun.sh
SERVICE_LIBRARY="subscriber"
DEBUG=true

# grab configuration
SUB_SOURCE=${BASH_SOURCE[0]}
SUB_SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

#SUB_CUSTOM_DIR="$SUB_SCRIPT_DIR/volumes/customize"
#SUB_TESTRUN_DIR="$SUB_SCRIPT_DIR/volumes/customize/subscriber_client/testing"

. $SUB_SCRIPT_DIR/../functions.sh
cd $SUB_SCRIPT_DIR

usage()
{
  echo "connecting a pppoe subscriber ipv4 only or dual-stack"
  echo "  usage: ./connnect_pppoe_sub [v4|ds]"
  echo "  example: ./connnect_pppoe_sub v4"
  echo

}


[ -z $1 ] && testCase=v4 || testCase=$1

case $testCase in
  v4)
    sName=$sub2Name
    sInterface=$sub2Interface
    sAccessProto=$sub2AccessProto
    ;;
  ds)
    sName=$sub3Name
    sInterface=$sub3Interface
    sAccessProto=$sub3AccessProto
    ;;
  *)
    usage
    ;;
esac

#sName=$sub2Name
#sInterface=$sub2Interface
#sAccessProto=$sub2AccessProto
#
#sName=$sub3Name
#sInterface=$sub3Interface
#sAccessProto=$sub3AccessProto

#sub2Name="pppoE-Sub"
#sub2Interface="ens8.200.2048"
#sub2AccessProto="pppoe"

poff dsl-provider100

##########################################################################
# disconnect sub and 
# reset back to original 
# release ip address, reset dns server and delete ip link and namespace
ip netns exec $sName dhclient -r
#echo "nameserver 8.8.8.8" > /etc/resolv.conf
ip netns exec $sName ip link del dev $sInterface
ip netns del $sName
##########################################################################

delete_vlan_interface $sInterface

