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
    ospf2BS=$(echo $ospf2BridgeSubnet | sed -e "s.\/.\\\/.g")
    ospf2v6BS=$(echo $ospf2v6BridgeSubnet | sed -e "s.\/.\\\/.g" )
    [ $DEBUG = true ] && echo "    ospf1BS: $ospf1BS"
    [ $DEBUG = true ] && echo "    ospf1v6BS: $ospf1v6BS"
    [ $DEBUG = true ] && echo "    ospf2BS: $ospf2BS"
    [ $DEBUG = true ] && echo "    ospf2v6BS: $ospf2v6BS"
  
    cat $composeSampleFile | \
    sed -e "s/\$ospf1IpAddress/$ospf1IpAddress/g" \
      -e "s/\$ospf1Ipv6Address/$ospf1Ipv6Address/g" \
      -e "s/\$ospf1BridgeName/$ospf1BridgeName/g" | \
    sed -e "s/\$ospf2IpAddress/$ospf2IpAddress/g" \
      -e "s/\$ospf2Ipv6Address/$ospf2Ipv6Address/g" \
      -e "s/\$ospf2BridgeName/$ospf2BridgeName/g" | \
    sed -e "s/\$ospf1BridgeSubnet/$ospf1BS/g"  \
      -e "s/\$ospf2BridgeSubnet/$ospf2BS/g"  \
      -e "s/\$ospf2v6BridgeSubnet/$ospf2v6BS/g" \
      -e "s/\$ospf1v6BridgeSubnet/$ospf1v6BS/g"  > $composeDestFile

    [ $DEBUG = true ] && echo "    created compose file $composeDestFile"
  }

  build_frr_config()
  {
    # builds configuration for specific element
    [ $DEBUG = true ] && echo "  ${FUNCNAME[0]}"

    # we run through all frr config directories
    find $OSPF_SCRIPT_DIR/volumes/* -type d | grep -e "frr$" | \
      while IFS= read -r d; do 
        # backup old config file first
        if [ -e $d/frr.conf ]; then
          t_stamp=$(date +"%h-%d-%H:%M:%S")
          cp $d/frr.conf $d/../backup_configs/frr.conf.$t_stamp
        else 
          echo "    ${FUNCNAME[0]}: $d/frr.conf doesn't exist, can't backup"
        fi
        #ls $d/../backup_configs
        [ $DEBUG = true ] && echo "    ${FUNCNAME[0]}: writing new configuration file based on template 'frr_sample.conf'"
        # create new config file
        echo "Directory d: $d"
        cat $d/frr_sample.conf | \
          sed -e "s/\$ospf1IpAddress/$ospf1IpAddress/g" \
              -e "s/\$ospf1Ipv6Address/$ospf1Ipv6Address/g" \
              -e "s/\$ospf1IpPrefix/$ospf1IpPrefix/g" | \
          sed -e "s/\$ospf2IpAddress/$ospf2IpAddress/g" \
              -e "s/\$ospf2Ipv6Address/$ospf2Ipv6Address/g" \
              -e "s/\$ospf2IpPrefix/$ospf2IpPrefix/g" | \
          sed -e "s/\$ospf1BridgeSubnet/$ospf1BS/g" \
              -e "s/\$ospf2BridgeSubnet/$ospf2BS/g" > $d/frr.conf
      done

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

