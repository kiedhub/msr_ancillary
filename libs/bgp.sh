#!/usr/bin/env bash

[ $DEBUG = true ] && echo "Calling: ${BASH_SOURCE[0]}"

bgp_library()
{
  [ $DEBUG = true ] && echo "${FUNCNAME[0]}"

  # set interface type
  if [ $bgp1InterfaceVlan = "0" ]; then
    bgp1If="$bgp1Interface"
    bgp1isVlanIf="false"
  else
    bgp1If="$bgp1Interface.$bgp1InterfaceVlan"
    bgp1isVlanIf="true"
  fi  
  [ $DEBUG = true ] && echo "  bgp1If: $bgp1If"

  if [ $bgp2InterfaceVlan = "0" ]; then
    bgp2If="$bgp2Interface"
    bgp2isVlanIf="false"
  else
    bgp2If="$bgp2Interface.$bgp2InterfaceVlan"
    bgp2isVlanIf="true"
  fi  
  [ $DEBUG = true ] && echo "  bgp2If: $bgp2If"
    
  # adds a physical interfaces to a bgp bridge (for external reachability)
  attach_bridge_interface()
  {
  [ $DEBUG = true ] && echo "  ${FUNCNAME[0]}"
    # create vlan interface for first bgp connection (if necessary)
    if [ $(sudo ip link show | grep "$bgp1If" | wc -l) -lt 1 ]; then
      if [ $bgp1isVlanIf = "true" ]; then
        ipv4_to_lamac $bgp1IpAddress
        create_vlan_interface $bgp1If
      fi  
    fi  

    if [ $(sudo brctl show $bgp1BridgeName |grep $bgp1If |wc -l) -gt 0 ]; then
      echo "Interface $bgp1If already assigned to bridge, nothing to do"
      sudo brctl show $bgp1BridgeName |grep $bgp1If
      return
    elif [ $(sudo brctl show | grep $bgp1If |wc -l) -gt 0 ]; then
      echo "Interface $bgp1If assigned to another bridge, please remove interface first"
      return
    fi  

    sudo ip link set dev $bgp1If master $bgp1BridgeName

    # create vlan interface for second bgp connection (if necessary)
    if [ $(sudo ip link show | grep "$bgp2If" | wc -l) -lt 1 ]; then
      if [ $bgp2isVlanIf = "true" ]; then
        ipv4_to_lamac $bgp2IpAddress
        create_vlan_interface $bgp2If
      fi
    fi

    if [ $(sudo brctl show $bgp2BridgeName |grep $bgp2If |wc -l) -gt 0 ]; then
      echo "Interface $bgp2If already assigned to bridge, nothing to do"
      sudo brctl show $bgp2BridgeName |grep $bgp2If
      return
    elif [ $(sudo brctl show | grep $bgp2If |wc -l) -gt 0 ]; then
      echo "Interface $bgp2If assigned to another bridge, please remove interface first"
      return
    fi

    sudo ip link set dev $bgp2If master $bgp2BridgeName
  }

  set_bridge_interface()
  {
    [ $DEBUG = true ] && echo "  ${FUNCNAME[0]}" 
    [ $DEBUG = true ] && echo "    isp: $1 action: $2"
    [ $DEBUG = true ] && echo "    bgp1If: $bgp1If bgp2If: $bgp2If"
    isp=$1
    action=$2 
    [ $isp = "isp1" ] && bridgeName=$bgp1BridgeName
    [ $isp = "isp2" ] && bridgeName=$bgp2BridgeName
    
    case $action in
      up)
        [ $DEBUG = true ] && echo "    sudo ip link set dev $bridgeName up"
        sudo ip link set dev $bridgeName up
        ;;
      down)
        [ $DEBUG = true ] && echo "    sudo ip link set dev $bridgeName down"
        sudo ip link set dev $bridgeName down
        ;;
      *)
        [ $DEBUG = true ] && echo "    \"$action\" is no valid action!"
        exit 
    esac
    
  } 

  detach_bridge_interface()
  {
    [ $DEBUG = true ] && echo "  ${FUNCNAME[0]}"
    if [ $(sudo brctl show $bgp1BridgeName |grep $bgp1If |wc -l) -gt 0 ]; then
      sudo ip link set dev $bgp1Interface nomaster
    fi
    
    [ $bgp1isVlanIf = "true" ] && delete_vlan_interface $bgp1If
    
    if [ $(sudo brctl show $bgp2BridgeName |grep $bgp2If |wc -l) -gt 0 ]; then
      sudo ip link set dev $bgp2Interface nomaster
    fi  
        
    [ $bgp2isVlanIf = "true" ] && delete_vlan_interface $bgp2If
        
  }     
        
  build_compose_file()
  {     
    [ $DEBUG = true ] && echo "  ${FUNCNAME[0]}"
    bgp1BS=$(echo $bgp1BridgeSubnet | sed -e "s.\/.\\\/.g")
    bgp1v6BS=$(echo $bgp1v6BridgeSubnet | sed -e "s.\/.\\\/.g" )
    bgp2BS=$(echo $bgp2BridgeSubnet | sed -e "s.\/.\\\/.g")
    bgp2v6BS=$(echo $bgp2v6BridgeSubnet | sed -e "s.\/.\\\/.g" )
    [ $DEBUG = true ] && echo "    bgp1BS: $bgp1BS"
    [ $DEBUG = true ] && echo "    bgp2BS: $bgp2BS"
    [ $DEBUG = true ] && echo "    bgp1v6BS: $bgp1v6BS"
    [ $DEBUG = true ] && echo "    bgp2v6BS: $bgp2v6BS"
  
    cat $composeSampleFile | \
    sed -e "s/\$bgp1IpAddress/$bgp1IpAddress/g" \
      -e "s/\$bgp2IpAddress/$bgp2IpAddress/g" \
      -e "s/\$bgp1BridgeName/$bgp1BridgeName/g" \
      -e "s/\$bgp2BridgeName/$bgp2BridgeName/g" | \
      sed -e "s/\$bgp3BridgeName/$bgp3BridgeName/g" \
      -e "s/\$bgp4BridgeName/$bgp4BridgeName/g" \
      -e "s/\$bgp5BridgeName/$bgp5BridgeName/g" | \
      sed -e "s/\$bgp1BridgeSubnet/$bgp1BS/g" \
      -e "s/\$bgp2BridgeSubnet/$bgp2BS/g" | \
      sed -e "s/\$bgp1Ipv6Address/$bgp1Ipv6Address/g" \
      -e "s/\$bgp2Ipv6Address/$bgp2Ipv6Address/g" \
      -e "s/\$bgp2v6BridgeSubnet/$bgp2v6BS/g" \
      -e "s/\$bgp1v6BridgeSubnet/$bgp1v6BS/g" > $composeDestFile

    [ $DEBUG = true ] && echo "    created compose file $composeDestFile"
  }

  remove_running_conf_file()
  {
    [ $DEBUG = true ] && echo "  ${FUNCNAME[0]}"
    # remove old file
    if [ -e $BGP_SCRIPT_DIR/running.conf ]; then
      sudo chmod +w $BGP_SCRIPT_DIR/running.conf
      rm -f $BGP_SCRIPT_DIR/running.conf
    fi
  }

  write_running_config()
  {
    [ $DEBUG = true ] && echo "  ${FUNCNAME[0]}"
    remove_running_conf_file
    echo "# RUNNING CONFIGURATION, DO NOT EDIT THIS FILE!!!" > $BGP_SCRIPT_DIR/running.conf
    cat $FUNC_LIB_SCRIPT_DIR/ancillary.conf >> $BGP_SCRIPT_DIR/running.conf

    # make it read-only
    sudo chmod 444 $BGP_SCRIPT_DIR/running.conf
  }

  clean_up_directory()
  {
    [ $DEBUG = true ] && echo "  ${FUNCNAME[0]}"
    echo "Re-setting ownership to $USER:$USER"
    sudo chown -R $USER:$USER $BGP_SCRIPT_DIR/volumes

    echo "Deleting log files"
    sudo rm -r $BGP_SCRIPT_DIR/volumes/log/
  }

}

