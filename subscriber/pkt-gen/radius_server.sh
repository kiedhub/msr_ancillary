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
exec > /root/pap_chap_script.$(date +%Y%m%d-%H%M%S).log 2>&1
exec < /dev/null
set -x

# end common script header
##############################################################################

apt-get update
apt-get install -y software-properties-common python-software-properties
add-apt-repository -y ppa:freeradius/stable-3.0
apt-get update
apt-get install -y freeradius freeradius-mysql freeradius-utils

# Insert IPv4 client configuration
mv /etc/freeradius/clients.conf /etc/freeradius/clients.conf.orig
cat /etc/freeradius/clients.conf.orig | \
  sed -E 's/^(# IPv6 Client)/# IPv4 Client\nclient 11.98.4.0\/24 {\n    secret = 1234\n}\n\n\1/' \
  > /etc/freeradius/clients.conf

# set authentication type
mv /etc/freeradius/users /etc/freeradius/users.orig
cat /etc/freeradius/users.orig |sed -E 's/(DEFAULT Auth-Type :=.*)/# \1\nDEFAULT Auth-Type := Accept/' \
  > /etc/freeradius/users

# add casa radius dictionary
mv /usr/share/freeradius/dictionary /usr/share/freeradius/dictionary.orig
cat /usr/share/freeradius/dictionary.orig | sed -E 's/(\$INCLUDE dictionary.camiant)/\1\n\$INCLUDE dictionary.casa/' \
  > /usr/share/freeradius/dictionary

cat << EOF >> /usr/share/freeradius/dictionary.casa



##############################################################################
#
#      #       Casa Systems's Dictionary
#     ###      Version 3.2.0 Build xxxx
#    #   #     
#   ### ###
#  #########
#
##############################################################################



VENDOR          CASA                            20858

BEGIN-VENDOR    CASA

ATTRIBUTE   Casa-DHCP-Option-60                     1	         string
ATTRIBUTE   Casa-Command-Type                       10	       string
ATTRIBUTE   Casa-Subscriber-Mac                     12	       string
ATTRIBUTE   Casa-Circuit-ID                         13	       string
ATTRIBUTE   Casa-Remote-ID                          14	       string
ATTRIBUTE   Casa-Primary-DNS                        15	       string
ATTRIBUTE   Casa-Secondary-DNS                      16	       string
ATTRIBUTE   Casa-Force-NAK                          17	       string
ATTRIBUTE   Casa-Force-Renew                        18	       string
ATTRIBUTE   Casa-Ip-Access-List                     19	       string
ATTRIBUTE   Casa-Class-Map                          20	       string
ATTRIBUTE   Casa-Policy-Qos-Config                  22	       string
ATTRIBUTE   Casa-Policy-PBR-Config                  23	       string
ATTRIBUTE   Casa-Activate-DT                        24	       string
ATTRIBUTE   Casa-Deactivate-DT                      25	       string
ATTRIBUTE   Casa-Dynamic-Template                   26	       string
ATTRIBUTE   Casa-Ipv4-Unnumbered                    27	       string
ATTRIBUTE   Casa-authorize-Option                   28	       string
ATTRIBUTE   Casa-Ipv6-Primary-DNS                   29	       string
ATTRIBUTE   Casa-Ipv6-Secondary-DNS                 30	       string
ATTRIBUTE   Casa-Acct-Input-Gigawords-Ipv4          31	       integer
ATTRIBUTE   Casa-Acct-Input-Octets-Ipv4             32	       integer
ATTRIBUTE   Casa-Acct-Input-Packets-Ipv4            33	       integer
ATTRIBUTE   Casa-Acct-Input-Gigawords-Ipv6          34	       integer
ATTRIBUTE   Casa-Acct-Input-Octets-Ipv6             35	       integer
ATTRIBUTE   Casa-Acct-Input-Packets-Ipv6            36	       integer
ATTRIBUTE   Casa-Acct-Output-Gigawords-Ipv4         37	       integer
ATTRIBUTE   Casa-Acct-Output-Octets-Ipv4            38	       integer
ATTRIBUTE   Casa-Acct-Output-Packets-Ipv4           39	       integer
ATTRIBUTE   Casa-Acct-Output-Gigawords-Ipv6         40	       integer
ATTRIBUTE   Casa-Acct-Output-Octets-Ipv6            41	       integer
ATTRIBUTE   Casa-Acct-Output-Packets-Ipv6           42	       integer
ATTRIBUTE   Casa-Acct-Address-Family-Status         43	       integer
ATTRIBUTE   Casa-Vrf-Name                           44	       string
ATTRIBUTE   Casa-Ip-Gateway                         45	       ipaddr
ATTRIBUTE   Casa-Li-Config-Mediation                46	       string 
ATTRIBUTE   Casa-Li-Remove-Mediation                47	       string
ATTRIBUTE   Casa-Li-Activate-Stream                 48	       string
ATTRIBUTE   Casa-Li-Deactivate-Stream               49	       string
ATTRIBUTE   Casa-Actual-Data-Rate-Upstream          50	       integer
ATTRIBUTE   Casa-Actual-Data-Rate-Downstream        51	       integer
ATTRIBUTE   Casa-Ipv6-Gateway                       52         ipv6addr

END-VENDOR      CASA
EOF

# some performace optimizations
echo "* soft nofile 40960" >> /etc/security/limits.conf
echo "* hard nofile 40960" >> /etc/security/limits.conf

# change max_requests value to 30960
mv /etc/freeradius/radiusd.conf /etc/freeradius/radiusd.conf.orig
cat /etc/freeradius/radiusd.conf.orig |sed -E 's/(max_requests =.*)/# \1\nmax_requests = 30960/' \
  > /etc/freeradius/radiusd.conf

echo "ulimit -HSn 65536" >> /etc/rc.local
echo "ulimit -HSn 65536" >> /root/.bash_profile
ulimit -HSn 65536
