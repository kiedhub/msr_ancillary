#!/usr/bin/env bash

echo "Sourced functions.lib"

# grab configuration
SOURCE=${BASH_SOURCE[0]}
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
source $SCRIPT_DIR/ancillary.conf

#echo "SOURCE: $SOURCE"
#echo "SCRIPT_DIR: $SCRIPT_DIR"

# RADIUS specific library
aaa_library()
{
  # adds a physical interface to the radius bridge (for external reachability)
  setup_bridge_interface()
  {
    if [ $(sudo brctl show $aaaBridgeName |grep $aaaInterface |wc -l) -gt 0 ]; then
      echo "Interface $aaaInterface already assigned to bridge, nothing to do"
      sudo brctl show aaa |grep ens7
      exit
    elif [ $(sudo brctl show | grep $aaaInterface |wc -l) -gt 0 ]; then
      echo "Interface $aaaInterface assigned to another bridge, please remove interface first"
      exit
    fi
  
    sudo ip link set dev $aaaInterface master $aaaBridgeName
  }
}

common_library()
{
}

### main
case $SERVICE_LIBRARY in
  aaa)
    echo "Radius service"
    aaa_library
    ;;
  speedtest)
    echo "Speedtest Server"
    ;;
  bird)
    echo "Router"
    ;;
  *) 
    echo "unknown service"
    ;;
esac

common_library

## grab configuration file
##SOURCE=${BASH_SOURCE[0]}
##SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
##source $SCRIPT_DIR/config 
#
##site_name=$1
##yaml_template="$SCRIPT_DIR/jumphost.yaml"
##temp_yaml_file=${REMOTE_SITE}_temp.yaml
#
#load_config() {
#  echo "Loading configuration for site: $site_name"
#  $site_name
#  # echo "$IMAGE_VERSION $REMOTE_SITE $LAN_IP $LAN_IF"
#}
#
#build_tempfile () {
#  sed -e "s/\$LAN_IP/$LAN_IP/g" \
#      -e "s/\$LAN_IF/$LAN_IF/g" \
#      -e "s/\$REMOTE_SITE/$REMOTE_SITE/g" \
#      -e "s/\$IMAGE_VERSION/$IMAGE_VERSION/g" $yaml_template > $temp_yaml_file
#  #cat $temp_yaml_file
#}
#
#run_compose_up () {
#  yaml_filename=$1
#  sudo docker-compose -p jumphost -f $yaml_filename up -d
#  #cat $yaml_filename
#}
#
#run_compose_down () {
#  yaml_filename=$1
#  #cat $yaml_filename
#  sudo docker-compose -p jumphost -f $yaml_filename kill
#  sudo docker-compose -p jumphost -f $yaml_filename rm -f
#}
#
#interface_ip_add () {
#  # check if exist
#  if [ $(ip addr show dev $LAN_IF | grep "$LAN_IP" | wc -l) -gt 0 ]; then
#    echo "ip exist, no need to set up"
#  else
#    echo "set up IP: $LAN_IF ${LAN_IP}/${LAN_IP_PREFIX}"
#    sudo ip addr add ${LAN_IP}/${LAN_IP_PREFIX} dev $LAN_IF
#  fi
#}
#
#interface_ip_delete () {
#  if [ $(ip addr show dev $LAN_IF | grep "$LAN_IP" | wc -l) -gt 0 ]; then
#    echo "Remove ${LAN_IP}/${LAN_IP_PREFIX} from dev $LAN_IF "
#    sudo ip addr del ${LAN_IP}/${LAN_IP_PREFIX} dev $LAN_IF
#  else
#    echo "Remove IP: ${LAN_IP}/${LAN_IP_PREFIX} on dev $LAN_IF does not exsit, nothing to do"
#  fi
#}
#
#connect_to_container () {
#  ssh -o StrictHostKeyChecking=no \
#    -o GlobalKnownHostsFile=/dev/null \
#    -o UserKnownHostsFile=/dev/null \
#    -i ./rev-tunnel \
#    rxs@$LAN_IP \
#    -p 51000
#}
#
#get_ssh_revtunnel_id () {
#  sudo docker exec jumphost_edgehub_1 /bin/ps -efd | grep "rxs.*sshd:.*rxs" | awk '{ print $1 }'
#}
#
#get_container_id () {
#  sudo docker ps | grep "$site_name" | awk '{ print $1 }'
#}
#
#### MAIN
### check if configuration exist in configuration file
##if [ -n "$(type -t $site_name)" ] && [ "$(type -t $site_name)" = function ]; then
##  # site exists
##  load_config
##  build_tempfile
##  run_compose
##else
##  # site not round
##  echo "Can't find configuration for $site_name, check config file!"
##  exit
##fi
##
##echo "Ende"
##
###sudo docker-compose -p jumphost -f $yaml_filename up -d
