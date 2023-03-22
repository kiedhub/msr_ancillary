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

  prefix_from_cidr()
  {
    # extracts the network prefix from a cidr notation
    # requires cidr 
    # does not check for valid cidr
    [ $DEBUG = true ] && echo "${FUNCNAME[0]} ($1)"
    pfcCidr=$1

    pfcPrefix=$(echo "$pfcCidr" | sed -e 's/\// /' | awk -s '{ print $2 }')

  }

  if_up()
  {
    # checks interface status and bring it up in case it is down
    # requires interface name
    
    [ -z $1 ] && ifUpId=" NO IF ID" || ifUpId=$1
    [ $DEBUG = true ] && echo "${FUNCNAME[0]} ($ifUpId)"

    [ $(ip link show $ifUpId | grep "DOWN" | wc -l) -gt 0 ] && { \
      echo "  Interface $ifUpId down, bringing it up ..."; \
      sudo ip link set dev $ifUpId up; \
    } 
  }

  ip_add()
  {
    # adds an ip address to an interface
    # requires ip-addr/prefix
    [ $DEBUG = true ] && echo "${FUNCNAME[0]} ($1, $2)"
     
    ipAddr=$1
    ipAddIfId=$2
    
    check_vlan $ipAddIfId

    [ $DEBUG = true ] && echo "  Adding IP address $ipAddr to $ipAddIfId"
    sudo ip addr add $ipAddr dev $ipAddIfId

  }

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
      ospf)
        sudo docker-compose -p ospf -f compose.yaml up -d
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
      ospf)
        sudo docker-compose -p ospf -f compose.yaml down
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
    [ $DEBUG = true ] && echo "${FUNCNAME[0]} ($1)"
  
    # check on numeric value
    vid_candidate=$1
    regex='^[0-9]+$'
    ! [[ $vid_candidate =~ $regex ]] && { echo "VLAN ID ($vid_candidate) includes non numeric chars, exiting."; exit ; }
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
    [ $DEBUG = true ] && echo "  ifId: $ifId"

    # check vlan type
    [ $(echo $vlanInterface | sed 's/\./ /g' | wc -w) -eq 1 ] && { vlanOfType="none"; } 
    [ $(echo $vlanInterface | sed 's/\./ /g' | wc -w) -eq 2 ] && { vlanOfType="single"; } 
    [ $(echo $vlanInterface | sed 's/\./ /g' | wc -w) -eq 3 ] && { vlanOfType="double"; } 

    [ $DEBUG = true ] && echo "  Vlan tag format: $vlanOfType"

    [ $vlanOfType = "double" ] && { \
      sVid=$(echo $vlanInterface | sed 's/\./ /g' | awk '{ print $2 }');\
      check_vid_format $sVid;\
      cVid=$(echo $vlanInterface | sed 's/\./ /g' | awk '{ print $3 }');\
      check_vid_format $cVid;\
      isVlanIf=true;\
      [ $DEBUG = true ] && echo "  Is nested VLAN (double tagged): svid $sVid  cvid $cVid";\
    }

    [ $vlanOfType = "single" ] && { \
      vid=$(echo $vlanInterface | sed 's/\./ /g' | awk '{ print $2 }');\
      [ $DEBUG = true ] && echo "  Is 802.1Q VLAN (single tagged): vlanInterface: $vlanInterface vid $vid";\
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
    [ $DEBUG = true ] && echo "  vlanInterface: $vlanInterface"

    # sets sVid/cVid or vid, isNetedVlan and ifId
    check_vlan $vlanInterface

    # parent interface may be down after reboot, so let's check and bring it up
    [ $DEBUG = true ] && echo "  Bring up parent if: $ifId"
    if_up $ifId
    
    [ $isVlanIf = false ] && { echo "No VLAN interface, nothing to do"; return; }
    [ $(sudo ip link show | grep $vlanInterface | wc -l) -gt 0 ] && { \
      echo "VLAN interfce \"$vlanInterface\" already exists, nothing to do";\
      return;\
    }

    [ $DEBUG = true ] && echo "  VLAN check OK, isNestedVlan: $isNestedVlan"

    [ $vlanOfType = "single" ] && { \
      vid_to_lamac $vid;\
      [ $DEBUG = true ] && echo "  802.1Q VLAN (isNestedVlan=$isNestedVlan)";\
      sudo ip link add link $ifId address $laMac name $vlanInterface type vlan id $vid;\
      [ $(sudo ip link show | grep "$vlanInterface" | wc -l) -lt 1 ] && { \
        echo "create_vlan_interface: Failed creating vlan interface $vlanInterface, exiting";\
        exit;\
      } || { \
        [ $DEBUG = true ] && echo "  Bringing up interfaces $ifId and $vlanInterface";\
        if_up $ifId;\
        if_up $vlanInterface;\
      };\
    }
    
    [ $vlanOfType = "double" ] && { \
      vid_to_lamac $sVid;\
      sLaMac=$laMac;\
      vid_to_lamac $cVid;\
      cLaMac=$laMac;\
      [ $DEBUG = true ] && echo "  QinQ VLAN (double tagged)";\
      [ $DEBUG = true ] && echo "    Creating link";\
      [ $DEBUG = true ] && echo "    ifId: $ifId, sLaMac: $sLaMac, cLaMac: $cLaMac, vlanInterface: $vlanInterface, vid: $sVid.$cVid";\

      # create svlan interface
      ! [ $(ip link show | grep "$ifId.$sVid" | wc -l) -gt 0 ] && { \
        [ $DEBUG = true ] && echo "  Creating interface $ifId.$svid";\
        sudo ip link add link $ifId address $sLaMac name $ifId.$sVid type vlan id $sVid;\
        if_up $ifId.$sVid;\
        ! [ $(ip link show | grep "$ifId.$sVid" | wc -l) -gt 0 ] && { echo "Failed creating interface $ifId.$sVid, exiting"; exit; };\
      }
      # create cvlan interface
      ! [ $(ip link show | grep "$ifId.$sVid.$cVid" | wc -l) -gt 0 ] && { \
        [ $DEBUG = true ] && echo "  Creating interface $ifId.$sVid.$cVid using MAC $cLaMac";\
        sudo ip link add link $ifId.$sVid address $cLaMac name $ifId.$sVid.$cVid type vlan id $cVid;\
        if_up $ifId.$sVid.$cVid;\
        ! [ $(ip link show | grep "$ifId.$sVid.$cVid" | wc -l) -gt 0 ] && { \
          echo "Failed creating interface $ifId.$sVid.$cVid, exiting"; exit;\
        };\
      };\
    }
  }

  create_vlan_interface_in_netns()
  {
    # creates a vlan interface in a network namespace
    # requires interface name (of type br1.100.200) and network namespace name

    [ $DEBUG = true ] && echo "${FUNCNAME[0]}"
    vlanInterface=$1
    nsName=$2
    [ $DEBUG = true ] && echo "  vlanInterface: $vlanInterface nsName: $nsName"

    # sets sVid/cVid or vid, isNetedVlan and ifId
    check_vlan $vlanInterface

    # check if parent is a bridge and whether it exists; if bridge, create if not exist
    if [ $(echo "$ifId" | grep -e '^br.*' | wc -l) -eq 1 ]; then 
      isBridge=true || isBridge=false

      if [ $isBridge = true ]; then 
        [ $(ip netns exec $nsName brctl show | grep $ifId | wc -l) -eq 1 ] && \
          bridgeExist=true || bridgeExist=false
      fi

      $DEBUG && echo "  isBridge: $isBridge  bridgeExist: $bridgeExist"

      if [ $bridgeExist = false ]; then
        ip netns exec $nsName brctl addbr $ifId
        $DEBUG && echo "  netns($nsName): creating bridge $ifId"
      fi
    fi

    # parent interface may be down after reboot, so let's check and bring it up
    $DEBUG && echo "  netns($nsName): bring up parent if: $ifId"
    ip netns exec $nsName ip link set $ifId up
    #if_up $ifId
    
    [ $isVlanIf = false ] && { echo "No VLAN interface, nothing to do"; return; }
    [ $(sudo ip netns exec $nsName ip link show | grep $vlanInterface | wc -l) -gt 0 ] && { \
      echo "VLAN interfce \"$vlanInterface\" already exists, nothing to do";\
      return;\
    }

    $DEBUG && echo "  VLAN check OK, isNestedVlan: $isNestedVlan"

    [ $vlanOfType = "single" ] && { \
      vid_to_lamac $vid;\
      $DEBUG && echo "  802.1Q VLAN (isNestedVlan=$isNestedVlan)";\
      sudo ip netns exec $nsName ip link add link $ifId address $laMac name $vlanInterface type vlan id $vid;\
      [ $(sudo ip netns exec $nsName ip link show | grep "$vlanInterface" | wc -l) -lt 1 ] && { \
        echo "  netns($nsName): create_vlan_interface: Failed creating vlan interface $vlanInterface, exiting";\
        exit;\
      } || { \
        $DEBUG && echo "  netns($nsName): Bringing up interfaces $ifId and $vlanInterface";\
        ip netns exec $nsName ip link set $ifId up;\
        ip netns exec $nsName ip link set $vlanInterface up;\
      };\
    }
    
    [ $vlanOfType = "double" ] && { \
      vid_to_lamac $sVid;\
      sLaMac=$laMac;\
      vid_to_lamac $cVid;\
      cLaMac=$laMac;\
      [ $DEBUG = true ] && echo "  QinQ VLAN (double tagged)";\
      [ $DEBUG = true ] && echo "    netns($nsName): Creating link";\
      [ $DEBUG = true ] && echo "    ifId: $ifId, sLaMac: $sLaMac, cLaMac: $cLaMac, vlanInterface: $vlanInterface, vid: $sVid.$cVid";\

      # create svlan interface
      ! [ $(ip netns exec $nsName ip link show | grep "$ifId.$sVid" | wc -l) -gt 0 ] && { \
        $DEBUG = true && echo "  netns($nsName): Creating interface $ifId.$svid";\
        sudo ip netns exec $nsName ip link add link $ifId address $sLaMac name $ifId.$sVid type vlan id $sVid;\
        sudo ip netns exec $nsName ip link set $ifId.$sVid up;\
        ! [ $(ip netns exec $nsName ip link show | grep "$ifId.$sVid" | wc -l) -gt 0 ] && { \
          echo "Failed creating interface $ifId.$sVid, exiting";\
          exit; };\
      }
      # create cvlan interface
      ! [ $(ip netns exec $nsName ip link show | grep "$ifId.$sVid.$cVid" | wc -l) -gt 0 ] && { \
        $DEBUG = true && echo "  Creating interface $ifId.$sVid.$cVid using MAC $cLaMac";\
        sudo ip netns exec $nsName ip link add link $ifId.$sVid address $cLaMac name $ifId.$sVid.$cVid type vlan id $cVid;\
        sudo ip netns exec $nsName ip link set $ifId.$sVid.$cVid up;\
        ! [ $(ip netns exec $nsName ip link show | grep "$ifId.$sVid.$cVid" | wc -l) -gt 0 ] && { \
          echo "  netns($nsName): Failed creating interface $ifId.$sVid.$cVid, exiting";\
          exit;\
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

  delete_vlan_interface_in_netns()
  {
    # deletes a vlan interface inside a network namespace
    # requires interface name and network namespace name

    $DEBUG && echo "  ${FUNCNAME[0]}"
    vlanInterface=$1
    nsName=$2

    # sets sVid/cVid or vid, isNetedVlan and ifId
    check_vlan $vlanInterface

    [ $(sudo ip netns exec $nsName ip link show | grep "$vlanInterface" | wc -l) -gt 0 ] && {\
      sudo ip netns exec $nsName ip link delete $vlanInterface;\
      [ $(sudo ip netns exec §nsName ip link show | grep "$vlanInterface" | wc -l) -gt 0 ] && \
        echo "  netns($nsName): Failed deleting interface $vlanInterface";\
    }
    # if the parent is a bridge, we delete this as well
    if [ $(echo "$ifId" | grep -e '^br.*' | wc -l) -eq 1 ]; then 
      isBridge=true || isBridge=false

      if [ $isBridge = true ]; then 
        [ $(ip netns exec $nsName brctl show | grep $ifId | wc -l) -eq 1 ] && \
          bridgeExist=true || bridgeExist=false
      fi

      $DEBUG && echo "  isBridge: $isBridge  bridgeExist: $bridgeExist"

      if [ $bridgeExist = true ]; then
        ip netns exec $nsName brctl delbr $ifId
        $DEBUG && echo "  netns($nsName): deleting bridge $ifId"
      fi
    fi

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
    # removes running configuration
    # requires destination directory as $1

    [ $DEBUG = true ] && echo "  ${FUNCNAME[0]}"

    scriptDir=$1

    # remove old file
    if [ -e $scriptDir/running.conf ]; then
      # create a persistent copy of the configuration for parameter comparison
      # allows to compare a new config against a previous one
      cp $scriptDir/running.conf $scriptDir/running.conf.last
      sudo chmod +w $scriptDir/running.conf
      rm -f $scriptDir/running.conf
    fi
  }

  wr_running_config()
  {
    # writes running configuration
    # requires destination directory as $1

    [ $DEBUG = true ] && echo "  ${FUNCNAME[0]}"

    scriptDir=$1

    [ -e $scriptDir/running.conf ] && rm_running_config $scriptDir

    echo "# RUNNING CONFIGURATION, DO NOT EDIT THIS FILE!!!" > $scriptDir/running.conf
    cat $FUNC_LIB_SCRIPT_DIR/ancillary.conf >> $scriptDir/running.conf

    # make it read-only
    sudo chmod 444 $scriptDir/running.conf
  }

  check_prev_config()
  {
    # compares parameter with previous configureation (running.conf.last) 
    # requires parameter name as $1 (e.g. ospf1IpAddress)
    
    param_name=$1
    cpcNewValue=${!param_name}
    if [ -e "running.conf.last" ]; then
      cpcExistingValue=$(cat running.conf.last | \
        grep "$param_name" | \
        sed -e 's/"//g' | \
        sed -e 's/=/ /' | \
        awk -s '{ print $ 2 }')
        [ $DEBUG = true ] && echo "  ${FUNCNAME[0]}: $param_name - $cpcExistingValue (old) $cpcNewValue (new)"
        [ $cpcExistingValue == $cpcNewValue ] && cpcOldEqNew=true || cpcOldEqNew=false
    else
      [ $DEBUG = true ] && echo "  ${FUNCNAME[0]}: running.conf.last does not exist"
      cpcOldEqNew=false
    fi
  }
  
  snmp_walk()
  {
    [ $DEBUG = true ] && echo "  ${FUNCNAME[0]} (IP: $1, IfId: $2)"

    ipAddr=$1
    ifId=$2
    ifIndex="100000$ifId"
    v3User="$3"

    echo "*** SNMPv2c testing ***"
    sleep 2
    echo ""
    echo "snmpwalk -v 2c -c public $ipAddr iso.3.6.1.2.1.1.1"
    snmpwalk -v 2c -c public $ipAddr iso.3.6.1.2.1.1.1
    echo ""
    echo "snmpget -v 2c -c public $ipAddr 1.3.6.1.2.1.2.2.1.2.$ifIndex"
    snmpget -v 2c -c public $ipAddr 1.3.6.1.2.1.2.2.1.2.$ifIndex
    echo ""
    echo "snmpget -v 2c -c public $ipAddr 1.3.6.1.2.1.2.2.1.6.$ifIndex"
    snmpget -v 2c -c public $ipAddr 1.3.6.1.2.1.2.2.1.6.$ifIndex
    echo ""
    echo "snmpget -v 2c -c public $ipAddr 1.3.6.1.2.1.2.2.1.8.$ifIndex"
    snmpget -v 2c -c public $ipAddr 1.3.6.1.2.1.2.2.1.8.$ifIndex
    echo ""
    echo "snmpget -v 2c -c public $ipAddr 1.3.6.1.2.1.31.1.1.1.10.$ifIndex"
    snmpget -v 2c -c public $ipAddr 1.3.6.1.2.1.31.1.1.1.10.$ifIndex
    echo ""
    echo "snmpget -v 2c -c public $ipAddr 1.3.6.1.2.1.31.1.1.1.6.$ifIndex"
    snmpget -v 2c -c public $ipAddr 1.3.6.1.2.1.31.1.1.1.6.$ifIndex
    echo ""
    echo "snmpget -v 2c -c public $ipAddr 1.3.6.1.2.1.2.2.1.14.$ifIndex"
    snmpget -v 2c -c public $ipAddr 1.3.6.1.2.1.2.2.1.14.$ifIndex
    echo ""
    echo "snmpget -v 2c -c public $ipAddr 1.3.6.1.2.1.47.1.1.1.1.7.$ifIndex"
    snmpget -v 2c -c public $ipAddr 1.3.6.1.2.1.47.1.1.1.1.7.$ifIndex
    echo ""
    echo "snmpget -v 2c -c public $ipAddr 1.3.6.1.2.1.31.1.1.1.18.$ifIndex"
    snmpget -v 2c -c public $ipAddr 1.3.6.1.2.1.31.1.1.1.18.$ifIndex
    echo ""
    echo ""

    echo "*** SNMPv3 testing ***"
#    snmpwalk -v 3 -l noAuthNoPriv -u test31  172.16.3.20 iso.3.6.1.2.1.1.1
    sleep 2
    echo ""
    echo "snmpwalk -v 3 -l noAuthNoPriv -u $v3User $ipAddr iso.3.6.1.2.1.1.1"
    snmpwalk -v 3 -l noAuthNoPriv -u $v3User $ipAddr iso.3.6.1.2.1.1.1
    echo ""
    echo "snmpget -v 3 -l noAuthNoPriv -u $v3User $ipAddr 1.3.6.1.2.1.2.2.1.2.$ifIndex"
    snmpget -v 3 -l noAuthNoPriv -u $v3User $ipAddr 1.3.6.1.2.1.2.2.1.2.$ifIndex
    echo ""
    echo "snmpget -v 3 -l noAuthNoPriv -u $v3User $ipAddr 1.3.6.1.2.1.2.2.1.6.$ifIndex"
    snmpget -v 3 -l noAuthNoPriv -u $v3User $ipAddr 1.3.6.1.2.1.2.2.1.6.$ifIndex
    echo ""
    echo "snmpget -v 3 -l noAuthNoPriv -u $v3User $ipAddr 1.3.6.1.2.1.2.2.1.8.$ifIndex"
    snmpget -v 3 -l noAuthNoPriv -u $v3User $ipAddr 1.3.6.1.2.1.2.2.1.8.$ifIndex
    echo ""
    echo "snmpget -v 3 -l noAuthNoPriv -u $v3User $ipAddr 1.3.6.1.2.1.31.1.1.1.10.$ifIndex"
    snmpget -v 3 -l noAuthNoPriv -u $v3User $ipAddr 1.3.6.1.2.1.31.1.1.1.10.$ifIndex
    echo ""
    echo "snmpget -v 3 -l noAuthNoPriv -u $v3User $ipAddr 1.3.6.1.2.1.31.1.1.1.6.$ifIndex"
    snmpget -v 3 -l noAuthNoPriv -u $v3User $ipAddr 1.3.6.1.2.1.31.1.1.1.6.$ifIndex
    echo ""
    echo "snmpget -v 3 -l noAuthNoPriv -u $v3User $ipAddr 1.3.6.1.2.1.2.2.1.14.$ifIndex"
    snmpget -v 3 -l noAuthNoPriv -u $v3User $ipAddr 1.3.6.1.2.1.2.2.1.14.$ifIndex
    echo ""
    echo "snmpget -v 3 -l noAuthNoPriv -u $v3User $ipAddr 1.3.6.1.2.1.47.1.1.1.1.7.$ifIndex"
    snmpget -v 3 -l noAuthNoPriv -u $v3User $ipAddr 1.3.6.1.2.1.47.1.1.1.1.7.$ifIndex
    echo ""
    echo "snmpget -v 3 -l noAuthNoPriv -u $v3User $ipAddr 1.3.6.1.2.1.31.1.1.1.18.$ifIndex"
    snmpget -v 3 -l noAuthNoPriv -u test31 $ipAddr 1.3.6.1.2.1.31.1.1.1.18.$ifIndex
  }


}
