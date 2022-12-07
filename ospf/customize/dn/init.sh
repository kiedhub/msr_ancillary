#!/usr/bin/env ash

# docker container customization

# load configuration
source /tmp/customize/config

# setup loopback interface
ip link add name $lo_name type dummy
ip addr add $lo_ip dev $lo_name
#ip link set name $lo_name up

# set up individual bird configuration
mv /usr/local/etc/bird.conf /usr/local/etc/bird.conf.orig
ln -s /tmp/customize/bird.conf /usr/local/etc/bird.conf

# start routing engine
#bird

apk add tcptraceroute

ip route replace default via 11.20.0.10
