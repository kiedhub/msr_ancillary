#!/usr/bin/env bash

[ $DEBUG = true ] && echo "Calling: ${BASH_SOURCE[0]}"

ospf_library()
{
  [ $DEBUG = true ] && echo "${FUNCNAME[0]}"

  if [ $ospf1InterfaceVlan = "0" ]; then
    tacPlusIf="$ospf1Interface"
    isVlanIf="false"
  else
    tacPlusIf="$ospf1Interface.$ospf1InterfaceVlan"
    isVlanIf="true"
  fi  

  build_compose_file()
  {     
    [ $DEBUG = true ] && echo "  ${FUNCNAME[0]}"
    ospf1BS=$(echo $ospf1BridgeSubnet | sed -e "s.\/.\\\/.g")
    ospf1v6BS=$(echo $ospf1v6BridgeSubnet | sed -e "s.\/.\\\/.g" )
    [ $DEBUG = true ] && echo "    ospf1BS: $ospf1BS"
    [ $DEBUG = true ] && echo "    ospf1v6BS: $ospf1v6BS"
  
    cat $composeSampleFile | \
    sed -e "s/\$ospf1IpAddress/$ospf1IpAddress/g" \
      -e "s/\$ospf1BridgeName/$ospf1BridgeName/g" \
      -e "s/\$ospf2BridgeName/$ospf2BridgeName/g" | \
    sed -e "s/\$ospf1BridgeSubnet/$ospf1BS/g"  \
      -e "s/\$ospf1Ipv6Address/$ospf1Ipv6Address/g" \
      -e "s/\$ospf1v6BridgeSubnet/$ospf1v6BS/g"  > $composeDestFile

    [ $DEBUG = true ] && echo "    created compose file $composeDestFile"
  }

  clean_up_directory()
  {
    [ $DEBUG = true ] && echo "  ${FUNCNAME[0]}"
    echo "Re-setting ownership to $USER:$USER"
    sudo chown -R $USER:$USER $OSPF_SCRIPT_DIR/volumes

    echo "Deleting log files"
    sudo rm -r $OSPF_SCRIPT_DIR/volumes/log/
  }
}

