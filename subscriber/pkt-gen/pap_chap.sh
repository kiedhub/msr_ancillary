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
