#!/usr/bin/env bash

[ $DEBUG = true ] && echo "Calling: ${BASH_SOURCE[0]}"

tacplus_library() 
{
  # set interface type
  if [ $tacPlusInterfaceVlan = "0" ]; then
    tacPlusIf="$tacPlusInterface"
    isVlanIf="false"
  else
    tacPlusIf="$tacPlusInterface.$tacPlusInterfaceVlan"
    isVlanIf="true"
  fi

  build_compose_file()
  {
    [ $DEBUG = true ] && echo "  ${FUNCNAME[0]}"
    tacPlusBS=$(echo $tacPlusBridgeSubnet | sed -e "s.\/.\\\/.g")
    [ $DEBUG = true ] && echo "    tacPlusBS: $tacPlusBS"

    cat $composeSampleFile | \
    sed -e "s/\$tacPlusIpAddress/$tacPlusIpAddress/g" \
      -e "s/\$tacPlusBridgeName/$tacPlusBridgeName/g" \
      -e "s/\$tacPlusBridgeSubnet/$tacPlusBS/g" > $composeDestFile

    [ $DEBUG = true ] && echo "    Created compose file $composeDestFile"
  }

  clean_up_directory()
  {
    echo "Re-setting ownership to $USER:$USER"
    sudo chown -R $USER:$USER $TACP_SCRIPT_DIR/volumes

    echo "Deleting log files"
    sudo rm -r $TACP_SCRIPT_DIR/volumes/log/
  }

}


#exit
