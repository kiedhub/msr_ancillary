#!/usr/bin/env ash

# docker container customization

# load configuration
source /tmp/customize/config

## enable ipv6
#echo "/etc/modules before change:"
#cat /etc/modules
#modprobe ipv6
#echo "ipv6" >> /etc/modules
#echo "/etc/modules after change:"
#cat /etc/modules

# setup loopback interface
ip link add name $lo_name type dummy
ip addr add $lo_ip dev $lo_name
ip -6 addr add $lo_ipv6 dev $lo_name

# ipv6 addressing of std interfaces via compose.yaml doesn't seem to work
#echo "eth0_ipv6 = $eth0_ipv6"
#echo "eth1_ipv6 = $eth1_ipv6"
ip -6 addr add $eth0_ipv6 dev eth0 scope link
ip -6 addr add $eth1_ipv6 dev eth1 scope link

# setting a link local address to be used as the default GW for dn
#ip -6 addr add $eth1_link dev eth1 scope link

#ip link set name $lo_name up

# set up individual bird configuration
mv /usr/local/etc/bird.conf /usr/local/etc/bird.conf.orig
ln -s /tmp/customize/bird.conf /usr/local/etc/bird.conf

# start routing engine
bird
