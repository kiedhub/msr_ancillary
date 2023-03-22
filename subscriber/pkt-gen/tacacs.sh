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
exec > /root/tacacs_script.$(date +%Y%m%d-%H%M%S).log 2>&1
exec < /dev/null
set -x

# end common script header
##############################################################################

apt-get -y install tacacs+
touch /var/log/tac_plus.acct
mv /etc/tacacs+/tac_plus.conf /etc/tacacs+/tac_plus.conf.orig
cat << EOF >> /etc/tacacs+/tac_plus.conf
# Created by Henry-Nicolas Tourneur(henry.nicolas@tourneur.be)
# See man(5) tac_plus.conf for more details

# Define where to log accounting data, this is the default.

accounting file = /var/log/tac_plus.acct

# This is the key that clients have to use to access Tacacs+

key = testing123

# Use /etc/passwd file to do authentication
    
default authentication = file /etc/passwd
 
group = support {
    default service = deny
    service = exec {
    priv-lvl = 7
    }
}

group = sqa {
    default service = permit
    service = exec {
    priv-lvl = 15
    }
}
#Defining my users and assigning them to groups above
user = mary {
    name = "Network Support"
    member = support
}

user = vbng_admin {
    name = "vBNG Admin"
    member = sqa
}

user = vbng_operator {
    name = "vBNG Operator"
    member = support
}
EOF

useradd -m -p $(openssl passwd -crypt admin) -s /bin/bash vbng_admin
useradd -m -p $(openssl passwd -crypt operator) -s /bin/bash vbng_operator

/usr/sbin/tac_plus -C /etc/tacacs+/tac_plus.conf

exit 0
