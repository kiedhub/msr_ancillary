#!/usr/bin/env bash

[ $DEBUG = true ] && echo "Calling: ${BASH_SOURCE[0]}"

subscriber_library() 
{
  [ $DEBUG = true ] && echo "${FUNCNAME[0]}"

  get_subconfig()
  {
    # collects subscriber configuration from ancillary.conf
    # requires: subscriber name as $1
    # returns: interface as $gsInterface and access protocol as $gsAccessProto
  
    [ $DEBUG = true ] && echo "${FUNCNAME[0]} (Subscriber Name: $1)"
  
    gsSubName=$1
  
    gsSubId=$(cat "$SUB_SCRIPT_DIR"/../ancillary.conf | grep "\"$gsSubName\"" | \
      sed -e 's/=/ /' -e 's/Name/ Name/' | awk '{ print $1 }')
  
    gsIfVarName="$gsSubId""Interface"
    gsApVarName="$gsSubId""AccessProto"
  
    [ -z ${!gsIfVarName} ] && { \
      [ $DEBUG = true ] && echo "  No if config for subscriber \"$gsSubName\" "; \
      } || { gsInterface=${!gsIfVarName}; \
      [ $DEBUG = true ] && echo "  $gsIfVarName : $gsInterface"; }
  
    [ -z ${!gsApVarName} ] && { \
      [ $DEBUG = true ] && echo "  No access proto config for subscriber \"$gsSubName\""; \
      } || { \
      gsAccessProto=${!gsApVarName}; \
      [ $DEBUG = true ] && echo "  $gsApVarName : $gsAccessProto"; }
  }

  subscriber_config_remove()
  {
    # removes a subscriber configuration file
    # requires: destinationr file to remove
    [ $DEBUG = true ] && echo "${FUNCNAME[0]} (File: $1)"
   
    scrFile=$1

    sudo chmod +w $scrFile
    scrBakFile=$(echo $scrFile | sed -e 's/\.cfg/.bak/')
    [ $DEBUG = true ] && { echo "  src-file: $scrFile"; echo "  dst-file: $scrBakFile"; }

    sudo mv $scrFile $scrBakFile

  }

  subscriber_config_write()
  {
    # writes subscriber configuration data
    # requires: sub-name as $1, interface as $2 and access-proto as $3

    [ $DEBUG = true ] && echo "${FUNCNAME[0]} (SubscriberName: $1, Interface: $2, Access Protocol: $3)"

    scwSn=$1
    scwIf=$2
    scwAp=$3
    scwFile="$SUB_SCRIPT_DIR/.$scwSn.cfg"

    [ -e $scwFile ] && subscriber_config_remove $scwFile

    echo "$scwSn" > $scwFile
    echo "$scwIf" >> $scwFile
    echo "$scwAp" >> $scwFile

  }

  subscriber_backup_dhclient_leases()
  {
    # backs up dhclient files, requires ip version and subscriber name

    [ $DEBUG = true ] && echo "${FUNCNAME[0]} (IPVersion: $1, SubName: $2)"

    sbdlIpVersion=$1
    sbdlSn=$2
    sbdlV4OrigFile="/var/lib/dhcp/dhclient.leases"
    sbdlV6OrigFile="/var/lib/dhcp/dhclient6.leases"
    sbdlV4BakFile="$SUB_SCRIPT_DIR/.$sbdlSn""_dhclient.leases"
    sbdlV6BakFile="$SUB_SCRIPT_DIR/.$sbdlSn""\_dhclient6.leases"

    case $sbdlIpVersion in 
      v4)
        [ $DEBUG = true ] && echo "  ${FUNCNAME[0]} Backing up $sbdlV4OrigFile to $sbdlV4BakFile"
        [ -e $sbdlV4OrigFile ] && sudo cp -f $sbdlV4OrigFile $sbdlV4BakFile
        ;;
      v6)
        [ $DEBUG = true ] && echo "  ${FUNCNAME[0]} Backing up $sbdlV6OrigFile to $sbdlV6BakFile"
        [ -e $sbdlV6OrigFile ] && sudo cp -f $sbdlV6OrigFile $sbdlV6BakFile
        ;;
      all)
        [ $DEBUG = true ] && echo "  ${FUNCNAME[0]} Backing up $sbdlV4OrigFile to $sbdlV4BakFile"
        [ -e $sbdlV4OrigFile ] && sudo cp -f $sbdlV4OrigFile $sbdlV4BakFile
        [ $DEBUG = true ] && echo "  ${FUNCNAME[0]} Backing up $sbdlV6OrigFile to $sbdlV6BakFile"
        [ -e $sbdlV6OrigFile ] && sudo cp -f $sbdlV6OrigFile $sbdlV6BakFile
        ;;
      *)
        # error message
        echo "${FUNCNAME[0]} unkown IP version (must be on of v4, v6 or all. Exiting ..."
        exit
        ;;
    esac
  }

  subscriber_restore_dhclient_leases()
  {
    # restores dhclient files, requires ip version and subscriber name

    [ $DEBUG = true ] && echo "${FUNCNAME[0]} (IPVersion: $1, SubName: $2)"

    srdlIpVersion=$1
    srdlSn=$2
    srdlV4OrigFile="/var/lib/dhcp/dhclient.leases"
    srdlV6OrigFile="/var/lib/dhcp/dhclient6.leases"
    srdlV4BakFile="$SUB_SCRIPT_DIR/.$srdlSn_dhclient.leases"
    srdlV6BakFile="$SUB_SCRIPT_DIR/.$srdlSn_dhclient6.leases"

    case $srdlIpVersion in 
      v4)
        [ $DEBUG = true ] && echo "  ${FUNCNAME[0]} Restoring $srdlV4OrigFile from $srdlV4BakFile"
        [ -e $srdlV4BakFile ] && sudo mv -b -f $srdlV4BakFile $srdlV4OrigFile || sudo rm -f $srdlV4OrigFile
        ;;
      v6)
        [ $DEBUG = true ] && echo "  ${FUNCNAME[0]} Restoring $srdlV6OrigFile from $srdlV6BakFile"
        [ -e $srdlV6BakFile ] && sudo mv -b -f $srdlV6BakFile $srdlV6OrigFile || sudo rm -f $srdlV6OrigFile
        ;;
      all)
        [ $DEBUG = true ] && echo "  ${FUNCNAME[0]} Restoring $srdlV4OrigFile from $srdlV4BakFile"
        [ -e $srdlV4BakFile ] && sudo mv -b -f $srdlV4BakFile $srdlV4OrigFile || sudo rm -f $srdlV4OrigFile
        [ $DEBUG = true ] && echo "  ${FUNCNAME[0]} Restoring $srdlV6OrigFile from $srdlV6BakFile"
        [ -e $srdlV6BakFile ] && sudo mv -b -f $srdlV6BakFile $srdlV6OrigFile || sudo rm -f $srdlV6OrigFile
        ;;
      *)
        # error message
        echo "  ${FUNCNAME[0]} Error: unkown IP version (must be on of v4, v6 or all. Exiting ..."
        exit
        ;;
    esac
  }

  pppIPv6option()
  {
    # sets/removes IPv6 option for PPP, requires one of [add|remove]
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

  subscriber_session_create()
  {
    # sets up subscriber interface and connects sub to BNG 
    # requires: interface as $1, sub-name as $2 and access-proto as $3

    [ $DEBUG = true ] && echo "${FUNCNAME[0]} (Interface: $1, SubscriberName: $2, \
      Access Protocol: $3)"

    sscIf=$1
    sscSn=$2
    sscAp=$3

    check_vlan $sscIf
    [ $DEBUG = true ] && echo "  Vlan Type: $vlanOfType"

    [ $vlanOfType = "none" ] && isVlanIf=false || isVlanIf=true

    # check if vlan or qinq
    #[ $(echo $subInterface | grep "\." | wc -l) -gt 0 ] && isVlanIf=true || isVlanIf=false 
    #[ $DEBUG = true ] && echo "    Vlan check, isVlanIf=$isVlanIf"

    # set up vlan interface
    [ $isVlanIf = true ] && create_vlan_interface $sscIf
    
    # make sure parent if is up
    [ $isVlanIf = false ] && { \ 
      sudo ip link set dev $sscIf up;\
      [ $DEBUG = true ] && echo "  Bringin up interface $sscIf";\
    }   

    [ $DEBUG = true ] && echo "  Creating a new ip network namespace: $sscSn"
    ip netns add $sscSn

    [ $DEBUG = true ] && echo "  Transferring subscriber interface $sscIf to network namespace $sscSn"
    ip link set $sscIf netns $sscSn

    # request ip address and run test
    [ $DEBUG = true ] && echo "  Switch to newly created namespace $sscSn and connect subscriber"
    
    subscriber_config_write $sscSn $sscIf $sscAp

    # subscriber type specific connectivity
    case $sscAp in
      ipoe4)
        subscriber_backup_dhclient_leases v4 $sscSn
        ip netns exec $sscSn dhclient -4 -v $sscIf
        ;;
      ipoe6)
        subscriber_backup_dhclient_leases v6 $sscSn
        ip netns exec $sscSn dhclient -6 -N -v $sscIf
        #dhclient -6 -N -v $sscIf
        ;;
      ipoe6pd)
        subscriber_backup_dhclient_leases v6 $sscSn
        ip netns exec $sscSn dhclient -6 -P -N -v $sscIf
        #dhclient -6 -P -N -v $sscIf
        ;;
      ipoeds)
        subscriber_backup_dhclient_leases v4 $sscSn
        subscriber_backup_dhclient_leases v6 $sscSn
        ip netns exec $sscSn dhclient -4 -v $sscIf
        ip netns exec $sscSn dhclient -6 -P -N -v $sscIf
        ;;
      pppoe4)
        pppIPv6option remove
        [ $DEBUG = true ] && echo "  create file /etc/ppp/peers/dsl-provider100"
        subPty="pty \"\/usr\/sbin\/pppoe -I $sscIf -T 80 -m 1452\""
        sudo cat /etc/ppp/peers/dsl-provider | sed -e "s/^pty .*$/$subPty/" -e "s/^auth/noauth/" > \
          /etc/ppp/peers/dsl-provider100
        ip netns exec $sscSn pon dsl-provider100
        ;;
      pppoe6)
        ;;
      pppoeds)
        pppIPv6option add
        [ $DEBUG = true ] && echo "  create file /etc/ppp/peers/dsl-provider100"
        subPty="pty \"\/usr\/sbin\/pppoe -I $sscIf -T 80 -m 1452\""
        sudo cat /etc/ppp/peers/dsl-provider | sed -e "s/^pty .*$/$subPty/" -e "s/^auth/noauth/" > \
          /etc/ppp/peers/dsl-provider100
        ip netns exec $sscSn pon dsl-provider100
        ;;
      *)
        [ $DEBUG = true ] && echo "  Unknown subscriber type: $sscAp, exiting"
        exit
        ;;
    esac
    # entering network namespace
    echo "Entering network namespace $sscSn"
    echo "Exit via 'exit' and './disconnect.sh'"
    echo ""

    ip netns exec $sscSn bash --rcfile <(cat ~/.bashrc; echo 'PS1="Namespace > "')

  }

  subscriber_session_remove()
  {
    # disconnects a subscriber session, deletes the interface and namespace
    # requires sub-name as $1 and the written config file (sub-name.cfg)
    [ $DEBUG = true ] && echo "  ${FUNCNAME[0]}"
    
    ssrSn=$1
    ssrFile="$SUB_SCRIPT_DIR/.$ssrSn.cfg" 
    ssrIf=$(cat $ssrFile | sed '2q;d')
    ssrAp=$(cat $ssrFile | sed '3q;d')
    [ $DEBUG = true ] && echo "  SubName: $ssrSn, Interface: $ssrIf, AccessProto: $ssrAp"

    check_vlan $ssrIf
    [ $DEBUG = true ] && echo "  Vlan Type: $vlanOfType"

    [ $vlanOfType = "none" ] && isVlanIf=false || isVlanIf=true

    # subscriber type specific disconnect
    case $ssrAp in
      ipoe4)
        ip netns exec $ssrSn dhclient -4 -r
        subscriber_restore_dhclient_leases v4 $ssrSn
        #sudo rm /var/lib/dhclient.leases
        ;;
      ipoe6)
        ip netns exec $ssrSn dhclient -6 -r
        subscriber_restore_dhclient_leases v6 $ssrSn
        #sudo rm /var/lib/dhclient6.leases
        ;;
      ipoe6pd)
        ip netns exec $ssrSn dhclient -6 -r
        subscriber_restore_dhclient_leases v6 $ssrSn
        #sudo rm /var/lib/dhclient6.leases
        #dhclient -6 -P -N -v $ssrIf
        ;;
      ipoeds)
        ip netns exec $ssrSn dhclient -4 -r
        ip netns exec $ssrSn dhclient -6 -r
        subscriber_restore_dhclient_leases v4 $ssrSn
        subscriber_restore_dhclient_leases v6 $ssrSn
        #sudo rm /var/lib/dhclient.leases
        #sudo rm /var/lib/dhclient6.leases
        ;;
      pppoe4)
        ip netns exec $ssrSn poff dsl-provider100
        ;;
      pppoe6)
        ip netns exec $ssrSn poff dsl-provider100
        ;;
      pppoeds)
        ip netns exec $ssrSn poff dsl-provider100
        ;;
      *)
        [ $DEBUG = true ] && echo "  Unknown subscriber type: $ssrAp, exiting"
        exit
        ;;
    esac

    #common namespace actions
    ip netns exec $ssrSn ip link del dev $ssrIf

		ip netns del $ssrSn

    #[ $(echo $subInterface | grep "\." | wc -l) -gt 0 ] && isVlanIf=true || isVlanIf=false
    #[ $DEBUG = true ] && echo "    Vlan check, isVlanIf=$isVlanIf"

    # delete vlan interface
    [ $isVlanIf = true ] && delete_vlan_interface $subInterface

    subscriber_config_remove $ssrFile
  }
}

