#!/usr/bin/env bash

##############################################################################
# common script header (adapt log file name)
# The script has to be run as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root!"
   echo "Issue a 'sudo bash' before running it."
   exit 1
fi

# set up logging
exec > /root/dhcp_server_script.$(date +%Y%m%d-%H%M%S).log 2>&1
exec < /dev/null
set -x

# end common script header
##############################################################################

apt-get update
apt install isc-dhcp-server

mv /etc/default/isc-dhcp-server /etc/default/isc-dhcp-server.orig

cat << EOF >> /etc/default/isc-dhcp-server
# On what interfaces should the DHCP server (dhcpd) serve DHCP requests?
#	Separate multiple interfaces with spaces, e.g. "eth0 eth1".
INTERFACES="eth2"
EOF

mv /etc/dhcp/dhcpd.conf /etc/dhcp/dhcpd.conf.orig

cat << EOF >> /etc/dhcp/dhcpd.conf
# The ddns-updates-style parameter controls whether or not the server will
# attempt to do a DNS update when a lease is confirmed. We default to the
# behavior of the version 2 packages ('none', since DHCP v2 didn't
# have support for DDNS.)
ddns-update-style none;

# option definitions common to all supported networks...
option domain-name "casa.com";
option domain-name-servers 172.25.25.5, 172.25.25.6;

default-lease-time 600;
max-lease-time 7200;

authoritative;

# Use this to send dhcp log messages to a different log file (you also
# have to hack syslog.conf to complete the redirection).
log-facility local7;

subnet 50.50.0.0 netmask 255.255.0.0 {
  range 50.50.200.1 50.50.250.250;
  option domain-name-servers 172.25.25.5;
  option domain-name "casa.com";
  option routers 50.50.0.1;
  option broadcast-address 50.50.255.255;
  default-lease-time 600;
  max-lease-time 7200;
}
subnet 11.98.0.0 netmask 255.255.0.0 {
}
EOF

## configuration stopped working where
# add route (right place, do we need to setup ip address on eth2,...?)
not_working()
{
ip route add 50.0.0.0/255.0.0.0 via 11.98.4.14 dev eth2

# disable firewall
ufw allow  67/udp
ufw reload

# Start dhcpv4 server
service isc-dhcp-server start

mv /etc/dhcp/dhcpd6.conf /etc/dhcp/dhcpd6.conf.orig
cat << EOF >> /etc/dhcp/dhcpd6.conf
default-lease-time 600;
max-lease-time 7200;
log-facility local7;
subnet6 5050::/112 {
        range6 5050::2 5050::200;
        option dhcp6.name-servers fec0:0:0:0:1::1;
 
}
 
subnet6 2019:beef:beef:beef:5:5:5::/112 {
}
EOF

# create dhcpv6 lease file /112
touch /var/lib/dhcp/dhcpd6.leases

# setup ipv6 addresses and routes
ifconfig eth2 inet6 add 2019:beef:beef:beef:5:5:5:1/112
route -A inet6 add 5050::/112 gw 2019:beef:beef:beef:5:5:5:2 eth2

# start dhcpv6 server
dhcpd -6 -d -cf /etc/dhcp/dhcpd6.conf eth2
}
