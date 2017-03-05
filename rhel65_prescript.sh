#!/bin/sh
# 					Script Created by Ross Thompson
# 							Version: 1.0
#
# File: rhel65_prescript.sh       
# Created: 6/8/2015 as rhel65_prescript.sh
# Purpose: To be run before "rhel65_vcenter.sh" to set hostname and VNIC
#			settings accordingly.
################################################################################

#                                                                            
# MODIFICATIONS: 
# Version: 1.0 - 2/17/2015 
# - Created script.

#Turn off Debug mode
set +x

echo "#########################################################################"
echo ""
echo -n "	What is the Hostname of the server?  "
read HOSTN
sed -i '/HOSTNAME/d' /etc/sysconfig/network
echo "HOSTNAME=${HOSTN}" >> /etc/sysconfig/network
echo hostname ${HOSTN}
rm -f /etc/udev/rules.d/70-persistent-net.rules

service postfix stop
rm -f /var/lib/postfix/master.lock
service postfix start

shutdown -r now