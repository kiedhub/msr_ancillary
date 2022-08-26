#!/usr/bin/env bash

[ $DEBUG = true ] && echo "Calling: ${BASH_SOURCE[0]}"

commons_library()
{
  isProperVid=false
  isNestedVlan=false
  sVid=0
  cVid=0
  vid=0

  [ $DEBUG = true ] && echo "${FUNCNAME[0]}"

  check_bridge()
  {
    # requires interface and bridgeName 
    if=$1
    bn=$2
    bridgeExist=false
    interfaceAttached=false

    [ $(sudo brctl show | grep $bn | wc -l) -gt 0 ] && bridgeExist=true || { \
      echo "Bridge $bn does not exist, exiting";\
      exit;\
    }
   
    [ $(sudo brctl show $bn | grep $if | wc -l) -gt 0 ] && interfaceAttached=true 

    [ $bridgeExist = true ] && [ $interfaceAttached = true ] && \
      [ $(sudo ip link show dev $if master $bn | wc -l) -lt 1 ] && { \ 
      sudo brctl show;\
      echo "Interface $if attached to wrong bridge, exiting";\
      exit;\
    }
  }

  bridge_interface()
  {
    # requires action, bridgeInterface and bridgeName
    [ $DEBUG = true ] && echo "  ${FUNCNAME[0]} ($1, $2, $2)"

    action=$1
    interface=$(echo "$2" | sed -e 's/\.0$//' -e 's/\.$//')  # remove tailing .0 or . at the end of IfVlan
    bridgeName=$3

    bi_attach()
    {
      [ $DEBUG = true ] && echo "    ${FUNCNAME[0]} $1"
      if=$1
      bn=$2
      check_vlan $if
      [ $DEBUG = true ] && echo "      If: $ifId, isVlan: $isVlanIf, svid: $sVid, cvid: $cVid, vid: $vid"
      
      # check and create interface, if required
      [ $isVlanIf = true ] && { create_vlan_interface $if; }
      
      check_bridge $if $bn
      [ $DEBUG = true ] && echo "      BridgeExists: $bridgeExist, interfaceAttached: $interfaceAttached"

      [ $interfaceAttached = false ] && { \
        [ $DEBUG = true ] && echo "      Attaching Interface $interface to $bridgeName"; \
        sudo ip link set dev $interface master $bridgeName; \
        check_bridge $if $bn; \
        [ $interfaceAttached = false ] && { echo "      Failed to attach $interface to $bridgeName, exiting"; exit; }; \
        [ $DEBUG = true ] && echo "      BridgeExists: $bridgeExist, interfaceAttached: $interfaceAttached"; \
      }
    }

    bi_detach()
    {
      if=$1
      bn=$2
      check_bridge $if $bn
      [ $DEBUG = true ] && echo "      BridgeExists: $bridgeExist, interfaceAttached: $interfaceAttached"

      [ $DEBUG = true ] && echo "      Detaching bridge interface $if from $bn, if attached"
      [ $interfaceAttached = true ] && { sudo ip link set dev $if nomaster; }

      check_bridge $if $bn
      [ $interfaceAttached = true ] && { echo "      Failed to detach $interface from $bridgeName"; }; \

      [ $DEBUG = true ] && echo "      Deleting 802.1Q VLAN interface $if (in case of QinQ, the outer VLAN interface will be kept)"
      [ $isVlanIf = "true" ] && delete_vlan_interface $if
    }

    case $action in
      attach)
        [ $DEBUG = true ] && echo "  Attaching $interface to $bridgeName"
        bi_attach $interface $bridgeName
        ;;
      detach)
        [ $DEBUG = true ] && echo "  Attaching $interface to $bridgeName"
        bi_detach $interface $bridgeName
        ;;
    esac

  }

  compose_up()
  {
    [ $DEBUG = true ] && echo "  ${FUNCNAME[0]}"
    case $1 in
      aaa)
        sudo docker-compose -p radius -f compose.yaml up -d
        ;;
      speedtest)
        sudo docker-compose -p speedtest -f compose.yaml up -d
        ;;
      bgp)
        sudo docker-compose -p bgp -f compose.yaml up -d
        ;;
      tacplus)
        sudo docker-compose -p tacplus -f compose.yaml up -d
        ;;
      *)
        return
        ;;
    esac
  }
    
  compose_down()
  {
    [ $DEBUG = true ] && echo "  ${FUNCNAME[0]}"
    case $1 in
      aaa)
        sudo docker-compose -p radius -f compose.yaml down
        ;;
      speedtest)
        sudo docker-compose -p speedtest -f compose.yaml down
        ;;
      bgp)
        sudo docker-compose -p bgp -f compose.yaml down
        ;;
      tacplus)
        sudo docker-compose -p tacplus -f compose.yaml down
        ;;
      *)
        return
        ;;
    esac
  }

  check_vid_format()
  {
    # hand over vid candidate, sets
    # 'isProperVid' to true or false
    [ $DEBUG = true ] && echo "${FUNCNAME[0]}"
  
    # check on numeric value
    vid_candidate=$1
    regex='^[0-9]+$'
    ! [[ $vid_candidate =~ $regex ]] && { echo "VLAN ID includes non numeric chars, exiting."; exit ; }
    # number range 1-4094
    ! [ $vid_candidate -gt 0 ] && { echo "Wrong VLAN ID \"$vid_candidate\" (allowed values 1-4094), exiting"; exit ; }
    ! [ $vid_candidate -lt 4095 ] && { echo "Wrong VLAN ID \"$vid_candidate\" (allowed values 1-4094), exiting"; exit ; }
  
    isProperVid=true
    [ $DEBUG = true ] && echo "  Is proper VLAN ID format: $vid_candidate, isProperVid: $isProperVid";\
    #vid=vid_candidate
  }

  check_vlan()
  {
    # checks for nested vlan (QinQ) based on interface name (e.g. eth0.100.200)
    # sets sVid and pVid (in case of nested) or vid (in case of single vlan)
    [ $DEBUG = true ] && echo "${FUNCNAME[0]}"

    vlanInterface=$1

    # check rough format (eth0.100 or eth0.100.200)
    #[ $(echo $vlanInterface | sed 's/\./ /g' | wc -w) -lt 2 ] &&\
      #{ echo "Wrong VLAN interface format: $vlanInterface, exiting" ; exit; }
    [ $(echo $vlanInterface | sed 's/\./ /g' | wc -w) -gt 3 ] &&\
      { echo "Wrong VLAN interface format: $vlanInterface, exiting" ; exit; }

    [ $DEBUG = true ] && echo "  VLAN Interface format OK: $vlanInterface"
    
    ifId=$(echo $vlanInterface | sed -e 's/\./ /' | awk '{ print $1 }')

    # check vlan type
    [ $(echo $vlanInterface | sed 's/\./ /g' | wc -w) -eq 1 ] && { vlanOfType="none"; } 
    [ $(echo $vlanInterface | sed 's/\./ /g' | wc -w) -eq 2 ] && { vlanOfType="single"; } 
    [ $(echo $vlanInterface | sed 's/\./ /g' | wc -w) -eq 3 ] && { vlanOfType="double"; } 

    [ $vlanOfType = "double" ] && { \
      sVid=$(echo $vlanInterface | sed 's/\./ /g' | awk '{ print $2 }');\
      check_vid_format $sVid;\
      cVid=$(echo $vlanInterface | sed 's/\./ /g' | awk '{ print $3 }');\
      check_vid_format $cVid;\
      isVlanIf=true;\
      [ $DEBUG = true ] && echo "  Nested VLAN: svid $sVid  cvid $cVid";\
    }

    [ $vlanOfType = "single" ] && { \
      vid=$(echo $vlanInterface | sed 's/\./ /g' | awk '{ print $2 }');\
      [ $DEBUG = true ] && echo "  802.1Q VLAN: vid $vid";\
      check_vid_format $vid;\
      isVlanIf=true;\
    }

    [ $vlanOfType = "none" ] && { \
      isVlanIf=false;
    }
  }

  create_vlan_interface()
  {
    [ $DEBUG = true ] && echo "${FUNCNAME[0]}"
    vlanInterface=$1

    # sets sVid/cVid or vid, isNetedVlan and ifId
    check_vlan $vlanInterface
    
    [ $isVlanIf = false ] && { echo "No VLAN interface, nothing to do"; return; }
    [ $(sudo ip link show | grep $vlanInterface | wc -l) -gt 0 ] && { \
      echo "VLAN interfce \"$vlanInterface\" already exists, nothing to do";\
      return;\
    }

    [ $DEBUG = true ] && echo "  VLAN check OK, isNestedVlan: $isNestedVlan"

    [ $isNestedVlan = false ] && { \
      vid_to_lamac $vid
      [ $DEBUG = true ] && echo "  802.1Q VLAN (isNestedVlan=$isNestedVlan)";\
      sudo ip link add link $ifId address $laMac name $vlanInterface type vlan id $vid;\
      [ $(sudo ip link show | grep "$vlanInterface" | wc -l) -lt 1 ] && { \
        echo "create_vlan_interface: Failed creating vlan interface $vlanInterface, exiting";\
        exit;\
      } || { \
        [ $DEBUG = true ] && echo "  Brining up interfaces $ifId and $vlanInterface";\
        sudo ip link set dev $ifId up;\
        sudo ip link set dev $vlanInterface up;\
      };\
    }
    
    [ $isNestedVlan = true ] && { \
      vid_to_lamac $sVid;\
      sLaMac=$laMac;\
      vid_to_lamac $cVid;\
      cLaMac=$laMac;\
      [ $DEBUG = true ] && echo "  QinQ VLAN (isNestedVlan=$isNestedVlan)";\
      [ $DEBUG = true ] && echo "    Creating link";\
      [ $DEBUG = true ] && echo "    ifId: $ifId, sLaMac: $sLaMac, cLaMac: $cLaMac, vlanInterface: $vlanInterface, vid: $sVid.$cVid";\
      # create svlan interface
      ! [ $(ip link show | grep "$ifId.$sVid" | wc -l) -gt 0 ] && { \
        [ $DEBUG = true ] && echo "  Creating interface $ifId.$svid";\
        sudo ip link add link $ifId address $sLaMac name $ifId.$sVid type vlan id $sVid;\
        sudo ip link set dev $ifId.$sVid up;\
        ! [ $(ip link show | grep "$ifId.$sVid" | wc -l) -gt 0 ] && { echo "Failed creating interface $ifId.$sVid, exiting"; exit; };\
      }
      # create cvlan interface
      ! [ $(ip link show | grep "$ifId.$sVid.$cVid" | wc -l) -gt 0 ] && { \
        [ $DEBUG = true ] && echo "  Creating interface $ifId.$sVid.$cVid using MAC $cLaMac";\
        sudo ip link add link $ifId.$sVid address $cLaMac name $ifId.$sVid.$cVid type vlan id $cVid;\
        sudo ip link set dev $ifId.$sVid.$cVid up;\
        ! [ $(ip link show | grep "$ifId.$sVid.$cVid" | wc -l) -gt 0 ] && { \
          echo "Failed creating interface $ifId.$sVid.$cVid, exiting"; exit;\
        };\
      };\
    }
  }

  delete_vlan_interface()
  {
    [ $DEBUG = true ] && echo "  ${FUNCNAME[0]}"
    vlanInterface=$1

    # sets sVid/cVid or vid, isNetedVlan and ifId
    check_vlan $vlanInterface

    [ $(sudo ip link show | grep "$vlanInterface" | wc -l) -gt 0 ] && {\
      sudo ip link delete $vlanInterface;\
      [ $(sudo ip link show | grep "$vlanInterface" | wc -l) -gt 0 ] && \
        echo "  Failed deleting interface $vlanInterface";\
    }
  }

  ipv4_to_lamac()
  {
    [ $DEBUG = true ] && echo "  ${FUNCNAME[0]}"
    ipv4Addr=$1
  
    oct1=$(echo $ipv4Addr | sed -e 's/\./ /g' | awk '{ print $1 }')
    oct2=$(echo $ipv4Addr | sed -e 's/\./ /g' | awk '{ print $2 }')
    oct3=$(echo $ipv4Addr | sed -e 's/\./ /g' | awk '{ print $3 }')
    oct4=$(echo $ipv4Addr | sed -e 's/\./ /g' | awk '{ print $4 }')

    [ $oct1 -lt 16 ] && mac1=$(printf '0%x\n' $oct1) || mac1=$(printf '%x\n' $oct1)
    [ $oct2 -lt 26 ] && mac2=$(printf '0%x\n' $oct2) || mac2=$(printf '%x\n' $oct2)
    [ $oct3 -lt 36 ] && mac3=$(printf '0%x\n' $oct3) || mac3=$(printf '%x\n' $oct3)
    [ $oct4 -lt 46 ] && mac4=$(printf '0%x\n' $oct4) || mac4=$(printf '%x\n' $oct4)

    laMac="02:00:$mac1:$mac2:$mac3:$mac4"
  } 

  vid_to_lamac()
  {
    [ $DEBUG = true ] && echo "  ${FUNCNAME[0]}"

    lamVid=$1
    vidLen=$(echo -n "$lamVid" | wc -c)
    randOctets=$(date +"%N" | cut -b 4-9 | sed -e 's/\(..\)\(..\)\(..\)$/\1:\2:\3/')
  
    [ $vidLen -gt 2 ] && {\
      o5=$(echo "$lamVid" | sed -e 's/\(..\)$/ \1/' | awk '{ print $1 }');\
      o6=$(echo "$lamVid" | sed -e 's/\(..\)$/ \1/' | awk '{ print $2 }');\
    }

    [ $vidLen = 1 ] && laMac="02:$randOctets:00:0$lamVid"
    [ $vidLen = 2 ] && laMac="02:$randOctets:00:$lamVid"
    [ $vidLen = 3 ] && laMac="02:$randOctets:0$o5:$o6"
    [ $vidLen = 4 ] && laMac="02:$randOctets:$o5:$o6"

    [ $DEBUG = true ] && echo "  VlanId: $lamVid, VIDLength: $vidLen, laMac: $laMac"
  }

  rm_running_config()
  {
    [ $DEBUG = true ] && echo "  ${FUNCNAME[0]}"

    scriptDir=$1

    # remove old file
    if [ -e $scriptDir/running.conf ]; then
      sudo chmod +w $scriptDir/running.conf
      rm -f $scriptDir/running.conf
    fi
  }

  wr_running_config()
  {
    [ $DEBUG = true ] && echo "  ${FUNCNAME[0]}"

    scriptDir=$1

    [ -e $scriptDir/running.conf ] && rm_running_config $scriptDir

    echo "# RUNNING CONFIGURATION, DO NOT EDIT THIS FILE!!!" > $scriptDir/running.conf
    cat $FUNC_LIB_SCRIPT_DIR/ancillary.conf >> $scriptDir/running.conf

    # make it read-only
    sudo chmod 444 $scriptDir/running.conf
  }

}
