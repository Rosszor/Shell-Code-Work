#!/bin/sh
# 					Script Created by Ross Thompson
# 							Version: 1.3
#
# File: Autocfg_Validate.sh       
# Created: 3/11/2015 as Autocfg_Validate.sh
# Purpose: Will run all configuration and validation steps for the server that has been installed with Autocfg_postbuild script.
 
################################################################################
#                                                                            
# MODIFICATIONS: 
# Version: 1.0 - 3/11/2015 
# - Created script.

# Version 1.1 - 5/19/2015
# - Made changes to configure/validation to reflect changes in install script. 
# - Removed Tidal/Splunk/HPOV from configure/validation as they will not be installed.
# - Added Oracle-release file to output to check if/what OEL version

# Version 1.2 - 6/10/2015
# - Changed VAS configuration to use GetUXHOST and created a universal UXHOST variable to be used throughout the script. This will aid in script expansion (Specifically for PBIS validation)

# Version 1.3 - 6/23/2015
# - Added removal of SSH login to the Reboot function. 

# To Add/Update
# - Add PBIS validation
# - Add loop for all ifcfg-ethX files (For Physicals)
# - Add section that removes root login ability
##############################################################################

SetVar() {
##############################################################################
# Set Variables for Script                                                   #
# 	- Some of the set variables will not be used. Most are set for future	 #
# 	expansion of the script.												 #	
##############################################################################
HOST="`hostname|awk -F. '{print $1}'`"
#Variable for log file that all user input and script output is written to
LOG="/tmp/Postbuild_Log"
#Universal UXHOST variable
UXHOST=""
}

GetUXHOST() {
##############################################################################
# Asks user for UXHOST group to add to users.allow file later in the script  #
##############################################################################
echo "#########################################################################"
echo -n "	UXHOST for users.allow?	"
read VASHOST
UXHOST=${VASHOST}
}

ConfigureNetbackup() {
##############################################################################
# Makes changes to Netbackup			                                     #	
#	- Edits /usr/openv/netbackup/bp.conf and restarts the netbackup service  #
#	  if the user selected to add a backnet configuration earlier.			 #
##############################################################################
echo "	Configuring Netbackup Files and Service:"
NBFILE="/usr/openv/netbackup/bp.conf"
echo SERVER = netbpmas01v > ${NBFILE}
echo CLIENT_NAME = ${HOST}-bn >> ${NBFILE}
echo CONNECT_OPTIONS = localhost 1 0 2 >> ${NBFILE}
echo CLIENT_READ_TIMEOUT = 900 >> ${NBFILE}
echo "SERVER = netbpmas21v" >> ${NBFILE}
echo "SERVER = netbpmas21" >> ${NBFILE}
echo "SERVER = netbpmas22" >> ${NBFILE}
echo "SERVER = netbpmas21dr" >> ${NBFILE}
echo "SERVER = netbpmed21" >> ${NBFILE}
echo "SERVER = netbpmed22" >> ${NBFILE}
echo "SERVER = netbpmed23" >> ${NBFILE}
echo "SERVER = netbpmed24" >> ${NBFILE}
echo "SERVER = netbpmed25" >> ${NBFILE}
echo "SERVER = netbpmed26" >> ${NBFILE}
echo "SERVER = netbpmed31" >> ${NBFILE}
echo "SERVER = netbpmed32" >> ${NBFILE}
echo "SERVER = netbpmed33" >> ${NBFILE}
echo "SERVER = netbpmed34" >> ${NBFILE}
chkconfig netbackup on
/etc/init.d/static-route
traceroute netbpmas01v
echo "DONE"
echo "#########################################################################"
}

ConfigureVAS() {
##############################################################################
# Makes changes to VAS			                                     		 #	
#	- Edits  and restarts the vasd service  								 #
##############################################################################
echo "	Configure VAS for new IP and UXHOST information:"
	#Asks user for UXHOST group to add to users.allow
GetUXHOST
	#Add UXHOST to users.allow
echo ${UXHOST} >> /etc/opt/quest/vas/users.allow
	#Edit vas.conf
	#Flush domain information
/opt/quest/bin/vastool flush statedir
echo "	VAS Password = tV!ojLeY"
	#Rejoin to the domain with correct IP infomration and UXHOST
/opt/quest/bin/vastool -u vasadmin join -f -c OU=HOSTS,OU=Unix,DC=Corp,DC=TWCABLE,DC=com -n ${HOST}.corp.twcable.com corp.twcable.com
	#Remove expired license
rm /etc/opt/quest/vas/.licenses/VAS_license_187-20250
/opt/quest/bin/vastool status
echo "DONE"
echo "#########################################################################"
}

ConfigureXymon() {
##############################################################################
# Makes changes to Xymon		                                     		 #	
#	- Edits /etc/sysconfig/xymon-client and starts the service               #
##############################################################################
echo "	Configure Xymon for hostname and xymon server IP:"
sed -i 's/XYMONSERVERS=""/XYMONSERVERS="10.136.255.49"/' /etc/sysconfig/xymon-client
echo "CLIENTHOSTNAME=\"${HOST}\"" >> /etc/sysconfig/xymon-client
echo "DONE"
echo "#########################################################################"
}

RunValidation() {
##############################################################################
# Validation/Log Creation                                                    #
##############################################################################
echo "	Server: ${HOST}"
echo "	Server: ${HOST}" > ${LOG}
echo "" 
echo "" >> ${LOG}
echo "	Please Validate Output:"
echo "	Please Validate Output:" >> ${LOG}
echo "	Log file - /tmp/Postbuild_Log"
echo "	Log file - /tmp/Postbuild_Log" >> ${LOG}
echo "	Date - $(date)"
echo "	Date - $(date)" >> ${LOG}
echo "#########################################################################" >> ${LOG}
echo "REDHAT/OEL VERSION" >> ${LOG}
cat /etc/redhat-release >> ${LOG}
cat /etc/oracle-release >> ${LOG}
echo "#########################################################################" >> ${LOG}
echo "TSG PATCH FILE" >> ${LOG}
cat /etc/tsg_unix_patch_release >> ${LOG}
echo "#########################################################################" >> ${LOG}
echo "/ETC/HOSTS" >> ${LOG}
cat /etc/hosts >> ${LOG}
echo "#########################################################################" >> ${LOG}
echo "/ETC/RESOLV.CONF" >> ${LOG}
echo "	First entry should be xxx.xxx.xxx.xxx for CDC" >> ${LOG}
echo "                     or xxx.xxx.xxx.xxx for CDP" >> ${LOG}
echo ""
cat /etc/resolv.conf >> ${LOG}
echo "#########################################################################" >> ${LOG}
echo "/ETC/SYSCONFIG/NETWORK-SCRIPTS/IFCFG-ETH0" >> ${LOG}
cat /etc/sysconfig/network-scripts/ifcfg-eth0 >> ${LOG}
echo "#########################################################################" >> ${LOG}
if [ -e /etc/sysconfig/network-scripts/ifcfg-eth1 ]; then
	echo "/ETC/SYSCONFIG/NETWORK-SCRIPTS/IFCFG-ETH1" >> ${LOG}
	cat /etc/sysconfig/network-scripts/ifcfg-eth1 >> ${LOG}
	echo "/ETC/INIT.D/STATIC-ROUTE" >> ${LOG}
	cat /etc/init.d/static-route >> ${LOG}
	echo "#########################################################################" >> ${LOG}
fi
echo "NETSTAT -RN" >> ${LOG}
/bin/netstat -rn >> ${LOG}
echo "#########################################################################" >> ${LOG}
echo "/ETC/FSTAB" >> ${LOG}
cat /etc/fstab >> ${LOG} 2>&1 >> ${LOG}
echo "#########################################################################" >> ${LOG}
echo "VOLUME GROUPS" >> ${LOG}
vgdisplay >> ${LOG}
echo "#########################################################################" >> ${LOG}
echo "LOGICAL VOLUMES" >> ${LOG}
lvdisplay >> ${LOG}
echo "#########################################################################" >> ${LOG}
echo "PHYSICAL VOLUMES" >> ${LOG}
pvdisplay >> ${LOG}
echo "#########################################################################" >> ${LOG}
echo "PARTITION TABLE" >> ${LOG}
df -h >> ${LOG}
echo "#########################################################################" >> ${LOG}
echo "MEMORY, CPU AND SWAP" >> ${LOG}
echo "MemTotal:" >> ${LOG}
cat /proc/meminfo |grep MemTotal >> ${LOG}
echo "CPU Total:" >> ${LOG}
cat /proc/cpuinfo |grep processor |wc -l >> ${LOG}
echo "Swap Total:" >> ${LOG}
cat /proc/meminfo |grep SwapTotal >> ${LOG}
echo "#########################################################################" >> ${LOG}
echo "SELINUX" >> ${LOG}
echo "SELinux status:" >> ${LOG}
echo "Should be permissive/targeted" >> ${LOG}
cat /etc/sysconfig/selinux |grep ^SELINUX >> ${LOG}
cat /etc/selinux/ >> ${LOG}
echo "SELinux Enforce mode" >> ${LOG}
cat /selinux/enforce >> ${LOG}
echo "#########################################################################" >> ${LOG}
echo "NTP CONFIGURATION" >> ${LOG}
cat /etc/ntp.conf >> ${LOG}
echo "#########################################################################" >> ${LOG}
echo "SYSCTL" >> ${LOG}
sysctl -p >> ${LOG} 2>&1
echo "#########################################################################" >> ${LOG}

echo "QUEST SSH STATUS" >> ${LOG}
service sshd status >> ${LOG}
echo "#########################################################################" >> ${LOG}

echo "POWERBROKER STATUS" >> ${LOG} 
/usr/local/bin/pbrun -v >> ${LOG} 2>&1
echo "#########################################################################" >> ${LOG}

echo "NETBACKUP STATUS" >> ${LOG}
cat /usr/openv/netbackup/bp.conf >> ${LOG}
service netbackup start >> ${LOG}
/etc/init.d/static-route
traceroute netbpmas01v >> ${LOG}
echo "#########################################################################" >> ${LOG}

echo "VAS STATUS" >> ${LOG}
cat /etc/opt/quest/vas/users.allow >> ${LOG}
service vasd status >> ${LOG}
/opt/quest/bin/vastool status >> ${LOG}
echo "#########################################################################" >> ${LOG}
	
echo "XYMON STATUS" >> ${LOG}
cat /etc/sysconfig/xymon-client >> ${LOG}
service xymon-client status >> ${LOG}
echo "#########################################################################" >> ${LOG}
echo "#########################################################################"
echo "	Please enter your email address:"
read EMAILADDR
mail -a ${LOG} -s "Postbuild_Log: ${HOST}" ${EMAILADDR} < ${LOG} 2>/dev/null
}

Reboot() {
##############################################################################
# Validation	                                                             #
##############################################################################
echo "	REBOOTING SERVER FOR CHANGES:"
sed -i 's/\#PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i '/PermitRootLogin yes/d' /etc/ssh/sshd_config
sed -i 's/\PermitRootLogin yes/PermitRootLogin no/' /etc/opt/quest/ssh/sshd_config
sed -i '/PermitRootLogin yes/d' /etc/opt/quest/ssh/sshd_config
shutdown -r now
}

main() {
##############################################################################
# Main Section																 #
#	Calls all functions in order of operations								 #
##############################################################################
SetVar
	#Call ConfigureVAS function
ConfigureVAS
	#Call ConfigureNetbackup function if Backnet exists
ConfigureNetbackup
	#Call ConfigureXymon function
ConfigureXymon
	#Run Validation function which creates a log to check for errors
RunValidation
#Reboot
}
main