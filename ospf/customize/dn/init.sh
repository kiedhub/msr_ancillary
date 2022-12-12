#!/usr/bin/env ash

apk add tcpdump

# docker container customization

# load configuration
source /tmp/customize/config

# setup loopback interface
ip link add name $lo_name type dummy
ip addr add $lo_ip dev $lo_name
ip -6 addr add $lo_ipv6 dev $lo_name

# ipv6 addressing of std interfaces via compose.yaml doesn't seem to work
#echo "eth0_ipv6 = $eth0_ipv6"
ip -6 addr add $eth0_ipv6 dev eth0 

#ip link set name $lo_name up

# set up individual bird configuration
mv /usr/local/etc/bird.conf /usr/local/etc/bird.conf.orig
ln -s /tmp/customize/bird.conf /usr/local/etc/bird.conf

# start routing engine
#bird

apk add tcptraceroute

ip route replace default via 11.20.0.10
ip -6 route replace default via fd00::11:20:0:10 dev eth0
#ip -6 route replace default via fe80::11:20:0:10 dev eth0
