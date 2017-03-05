#!/bin/sh
# 					Script Created by Ross Thompson
# 							Version: 1.1
#
# File: rhel65_vcenter.sh       
# Created: 6/8/2015 as rhel65_vcenter.sh
# Purpose: To be run on all servers imaged with the RHEL 6.5 Template on any vCenter ESX Cluster. Will assign IP/Network and application settings.
################################################################################

################################################################################
#                                                                            
# MODIFICATIONS: 
# Version: 1.0 - 6/8/2015 
# - Created script.

# Version: 1.1 - 6/10/2015
# - Added SetIPv6Off function to disable all IPv6 on the servers. This is required by TWC and also aids in fixing the Mailx problem the script has.
# - Added code to the end of mail command to suppress IPv6 error messages.

#Turn off Debug mode
set +x

RunPrescript() {
##############################################################################
# Message to assure that the user has run the prescript                      #
##############################################################################
echo "#########################################################################"
echo ""
echo "#########################################################################"
echo ""
echo "#########################################################################"
echo ""
echo "PLEASE MAKE SURE YOU HAVE RUN \"rhel65_prescript.sh\" BEFORE RUNNING THIS SCRIPT."
echo "HOSTNAME MUST BE SET AND VNICS MUST BE RESET IN ORDER FOR SCRIPT TO WORK CORRECTLY"
echo "#########################################################################"
echo ""
echo "#########################################################################"
echo ""
echo "#########################################################################"
echo ""
}

SetVar() {
##############################################################################
# Set Variables for Script                                                   #
# 	- Some of the set variables will not be used. Most are set for future	 #
# 	expansion of the script.												 #	
##############################################################################
HOST="`hostname|awk -F. '{print $1}'`"
#Variables to hold MAC addresses of both VNICs
ETH0MAC="0"
ETH1MAC="0"
#Variable to hold VMWareTools mount
VMWARE="/dev/cdrom"
#Variable used by InputCheck function while loop to check if user input is valid
VALID="f"
#Variable to be used by InputCheck function, contains user input
INPUT="x"
#Variable array used by InputCheck function, contains expected answers
EXPECTED[0]="y"
EXPECTED[1]="n"
EXPECTED[2]="b"
#Variables for use if backnet is added and netbackup to be installed
NB_HOME=/usr/openv/netbackup
BN_HOST=`hostname`-bn
DOMAIN=corpbacknet.twcable.com
ROUTE_DIR=/etc/init.d
ROUTE=static-route
FQDN=$BN_HOST.$DOMAIN
#Variable for log file that all user input and script output is written to
LOG="/tmp/Postbuild_Log"
#Follows the line of Functions to get user information
GETTINGINFO="t"
FUNCTIONNUM=1
}

InstallVMWare() {
##############################################################################
# Will use a mount to install VMWare Tools on the server				     #
##############################################################################
if (mount -o loop /dev/cdrom /mnt); then
	if [ ! -d "/tmp/vmware*" ]; then
        echo "  Beginning VMWare Tools Install:"
        cd /tmp
        tar -xzf /mnt/VMwareTools*
        /tmp/vmware-tools-distrib/vmware-install.pl
        echo "VMWare Tools Install Complete, please unmount the disk"
        umount /mnt
	fi
else
        echo "VMWare Tools not mounted:"
        echo "Please mount VMWare tools and try again"
fi
}

WhichGet() {
##############################################################################
# Function to decide which "Get" function to be called.						 #
##############################################################################
while [ "${GETTINGINFO}" = "t" ]; do
	case $FUNCTIONNUM in
	1)
		GetPIP
		;;
	2)
		GetPGATEWAY
		;;
	3)
		GetPNETMASK
		;;
	4)	
		GetPMAC
		;;
	5)
		HasBACKNET
		;;
	6)
		GetBIP
		;;
	7)
		GetBGATEWAY
		;;
	8)
		GetBNETMASK
		;;
	9)
		GetBMAC
		;;
	10)
		HasPRODUCT
		;;
	*)
        GETTINGINFO="f"
        ;;
	esac
done
}

GetPIP(){
##############################################################################
# Asks user for Primary IP information.                                      #
# Once input is provided, the next function is called						 #
##############################################################################
echo "#########################################################################"
echo "	Please answer all questions carefully. Press b at any time to return to previous input question. Default answers are in square brackets."
echo ""
echo -n "	What is the Primary IP?  "
read PIP
if [ "${PIP}" = "b" ]; then
        FUNCTIONNUM="0"
else
        FUNCTIONNUM="2"
fi
}

GetPGATEWAY(){
##############################################################################
# Asks user for Primary Gateway information.                                 #
# Once input is provided, the next function is called						 #
# Offers a "back" option to go to previous question.						 #
##############################################################################
echo "#########################################################################"
echo -n "	What is the Primary Gateway? (b)  "
read PGATEWAY
if [ "${PGATEWAY}" = "b" ]; then
        FUNCTIONNUM="1"
else
        FUNCTIONNUM="3"
fi
}

GetPNETMASK(){
##############################################################################
# Asks user for Primary Netmask information.                                 #
# Once input is provided, the next function is called						 #
# Offers a "back" option to go to previous question.						 #
##############################################################################
echo "#########################################################################"
echo -n "	What is the Primary Netmask? (b)  "
read PNETMASK
if [ "${PNETMASK}" = "b" ]; then
        FUNCTIONNUM="2"
else
        FUNCTIONNUM="4"
fi
}

GetPMAC() {
##############################################################################
# Asks user for Primary MAC Address information.                             #
# Once input is provided, the next function is called						 #
# Offers a "back" option to go to previous question.						 #
##############################################################################
echo "#########################################################################"
echo -n "	Primary MAC Address? (b)  "
read MAC0
ETH0MAC=${MAC0}
if [ "${MAC0}" = "b" ]; then
        FUNCTIONNUM="3"
else
		FUNCTIONNUM="5"
fi
}

HasBACKNET(){
##############################################################################
# Asks user for if server has a backnet NIC                                  #
# Once input is provided, the next function is called						 #
# Offers a "back" option to go to previous question.						 #
##############################################################################
echo "#########################################################################"
#Setting variables to be used by CheckInput function
VALID="f"
EXPECTED[0]=y
EXPECTED[1]=n
EXPECTED[2]=b
echo -n "	Do you have a backnet NIC to configure? (y/n/b)  "
read BACKNET
INPUT=${BACKNET}
CheckInput
BACKNET=${INPUT}
if [ "${BACKNET}" = "y" ]; then
	FUNCTIONNUM="6"
elif [ "${BACKNET}" = "b" ]; then
    FUNCTIONNUM="4"
else
	rm -f /etc/sysconfig/network-scripts/ifcfg-eth1
    FUNCTIONNUM="10"
fi
}

GetBIP() {
##############################################################################
# Asks user for Backnet IP information.                                      #
# Once input is provided, the next function is called						 #
# Offers a "back" option to go to previous question.						 #
##############################################################################
echo "#########################################################################"
echo -n "	What is the Backnet IP? (b)  "
read BIP
if [ "${BIP}" = "b" ]; then
        FUNCTIONNUM="5"
else
        FUNCTIONNUM="7"
fi
}

GetBGATEWAY() {
##############################################################################
# Asks user for Backnet Gateway information.                                 #
# Once input is provided, the next function is called						 #
# Offers a "back" option to go to previous question.						 #
##############################################################################
echo "#########################################################################"
echo -n "	Backnet Gateway? (b)  "
read BGATEWAY
if [ "${BGATEWAY}" = "b" ]; then
        FUNCTIONNUM="6"
else
        FUNCTIONNUM="8"
fi
}

GetBNETMASK() {
##############################################################################
# Asks user for Backnet Netmask information.                                 #
# Once input is provided, the next function is called						 #
# Offers a "back" option to go to previous question.						 #
##############################################################################
echo "#########################################################################"
echo -n "	Backnet Netmask? (b)  "
read BNETMASK
if [ "${BNETMASK}" = "b" ]; then
        FUNCTIONNUM="7"
else
        FUNCTIONNUM="9"
fi
}

GetBMAC() {
##############################################################################
# Asks user for Backnet MAC Address information.                             #
# Once input is provided, the next function is called						 #
# Offers a "back" option to go to previous question.						 #
##############################################################################
echo "#########################################################################"
echo -n "	Backnet MAC Address? (b)  "
read MAC1
ETH1MAC=${MAC1}
if [ "${MAC1}" = "b" ]; then
        FUNCTIONNUM="8"
else
		FUNCTIONNUM="10"
fi
}

HasPRODUCT() {
##############################################################################
# Asks user for if a /product partition is needed                            #
# Once input is provided, the next function is called						 #
# Offers a "back" option to go to previous question.						 #
##############################################################################
echo "#########################################################################"
#Setting variables to be used by CheckInput function
VALID="f"
EXPECTED[0]=y
EXPECTED[1]=n
EXPECTED[2]=b
echo -n "	Would you like to set up a /product volume? (y/n/b)  "
read PRODUCT
INPUT=${PRODUCT}
CheckInput
PRODUCT=${INPUT}
if [ "${PRODUCT}" = "b" ]; then
    FUNCTIONNUM="9"
elif [ "${PRODUCT}" = "y" ]; then
	FUNCTIONNUM="*"
	CreateProduct
else
	FUNCTIONNUM="*"
fi
}

CreateProduct() {
##############################################################################
# Performs all actions required to set up a /product partition.              #
#	- User is asked if /product is on Root Drive or a separate dedicated     #
#	disk.																	 #
##############################################################################
echo "#########################################################################"
#If /product exists, skip next part with error message
if [ ! -d "/product" ]; then	
		if [ ! -d "/dev/sdb1" ]; then
			echo "n
			p
			1
			
			
			w" |fdisk /dev/sdb
			vgcreate vg_product /dev/sdb1
			lvcreate -l 100%VG -n lv_product vg_product
			mkfs.ext4 /dev/vg_product/lv_product
			mkdir /product
			echo "/dev/vg_product/lv_product /product                ext4	defaults        1 2" >> /etc/fstab
			mount /product
			echo "DONE"
			echo "#########################################################################"
		else
			echo "	A /product directory already exists. Please check that a partition has not already been created and try again."
			echo "#########################################################################"
		fi
else
	echo "	A /product directory already exists. Please check that a partition has not already been created and try again."
	echo "#########################################################################"
fi
}

CheckInput() {
##############################################################################
# While loop to check user input is valid                                    #
# Requires an INPUT variable set to user input and an array of EXPECTED 	 #
# answers.																	 #
##############################################################################
while [ "${VALID}" = "f" ]; do
	if [ "${INPUT}" = "${EXPECTED[0]}" ]; then
		VALID="t"
	elif [ "${INPUT}" = "${EXPECTED[1]}" ]; then
		VALID="t"
	elif [ "${INPUT}" = "${EXPECTED[2]}" ]; then
		VALID="t"	
	else
		echo -n "	${INPUT} is not a valid answer... Please enter a valid answer:  "
		read INPUT
	fi
done
}

SetIPv6Off() {
##############################################################################
# Turns off and disables IPv6. 					                             #
##############################################################################
echo "	Disabling IPV6:"
echo "options ipv6 disable=1" > /etc/modprobe.d/ipv6.conf
chkconfig ip6tables off
echo "NETWORKING_IPV6=no" >> /etc/sysconfig/network
echo "# IPv6 support in the kernel, set to 0 by default" >> /etc/sysctl.conf 
echo "net.ipv6.conf.all.disable_ipv6 = 1" >> /etc/sysctl.conf 
echo "net.ipv6.conf.default.disable_ipv6 = 1" >> /etc/sysctl.conf 
sed -i 's/^[[:space:]]*::/#::/' /etc/hosts
echo "DONE"
echo "#########################################################################"
}

SetHosts() {
##############################################################################
# Sets /etc/hosts based on user input                                        #
##############################################################################
echo "	Editing hosts:"
echo "127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4" > /etc/hosts
echo "::1         localhost localhost.localdomain localhost6 localhost6.localdomain6" >> /etc/hosts
echo "#" >> /etc/hosts
echo "# Primary IP" >> /etc/hosts
echo "${PIP}	${HOST}" >> /etc/hosts
if [ "${BACKNET}" = "y" ]; then
	echo "#" >> /etc/hosts
	echo "# Backnet IP" >> /etc/hosts
	echo "${BIP}	${HOST}-bn.corpbacknet.twcable.com" >> /etc/hosts
fi
echo "DONE"
echo "#########################################################################"
}

SetEth0() {
##############################################################################
# Sets Eth0 configuration file based on user input                           #
##############################################################################
echo "	Configuring Eth0 (Primary):"
echo DEVICE=eth0 > /etc/sysconfig/network-scripts/ifcfg-eth0
echo BOOTPROTO=static >> /etc/sysconfig/network-scripts/ifcfg-eth0
echo HOSTNAME=${HOST} >> /etc/sysconfig/network-scripts/ifcfg-eth0
echo HWADDR=${ETH0MAC} >> /etc/sysconfig/network-scripts/ifcfg-eth0
echo TYPE=Ethernet >> /etc/sysconfig/network-scripts/ifcfg-eth0
echo IPADDR=${PIP} >> /etc/sysconfig/network-scripts/ifcfg-eth0
echo NETMASK=${PNETMASK} >> /etc/sysconfig/network-scripts/ifcfg-eth0
echo NM_CONTROLLED=no >> /etc/sysconfig/network-scripts/ifcfg-eth0
echo ONBOOT=yes >> /etc/sysconfig/network-scripts/ifcfg-eth0
	#Call SetGateway function
SetGateway
	#Restart Network to get things pinging
service network restart
echo "DONE"
echo "#########################################################################"
}

SetEth1() {
##############################################################################
# Sets Eth1 configuration file based on user input                           #
##############################################################################
if [ "${BACKNET}" = "y" ]; then
	echo "	Configuring Eth1 (Backnet):"
	echo DEVICE=eth1 > /etc/sysconfig/network-scripts/ifcfg-eth1
	echo BOOTPROTO=static>> /etc/sysconfig/network-scripts/ifcfg-eth1
	echo HWADDR=${ETH1MAC} >> /etc/sysconfig/network-scripts/ifcfg-eth1
	echo TYPE=Ethernet >> /etc/sysconfig/network-scripts/ifcfg-eth1
	echo IPADDR=${BIP} >> /etc/sysconfig/network-scripts/ifcfg-eth1
	echo NETMASK=${BNETMASK} >> /etc/sysconfig/network-scripts/ifcfg-eth1
	echo NM_CONTROLLED=no >> /etc/sysconfig/network-scripts/ifcfg-eth1
	echo ONBOOT=yes >> /etc/sysconfig/network-scripts/ifcfg-eth1
		#Restart Network to get things pinging
	service network restart
		#Call SetStatic_route function (if BACKNET=y)
	SetStatic_route
	echo "DONE"
	echo "#########################################################################"
fi
}

SetStatic_route() {
##############################################################################
# Creates and configures static-route if user entered backnet information.   #
##############################################################################
echo "	Adding /etc/init.d/static-route:"
echo "route add -net xxx.xxx.xxx.xxx gateway ${BGATEWAY} netmask xxx.xxx.xxx.xxx" > /etc/init.d/static-route
chmod +x /etc/init.d/static-route
/etc/init.d/static-route
echo "DONE"
echo "#########################################################################"
}

SetGateway() {
##############################################################################
# Sets /etc/sysconfig/network GATEWAY value based on user input              #
##############################################################################
echo "	Setting GATEWAY value:"
sed -i '/GATEWAY/d' /etc/sysconfig/network
echo "GATEWAY=${PGATEWAY}" >> /etc/sysconfig/network
}

InstallApplications() {
##############################################################################
# Uses packages in /tmp and begins software installations required.		     #
#	Will wait for user input after each install process to assure that user  #
#	can note any failures or errors.										 #
##############################################################################
cd /tmp
echo "#########################################################################"
echo " PBIS:"
if [ -e pbis-enterprise-8.2.0.2969.linux.x86_64.rpm.sh ]; then
	echo -n "	Would you like to install PBIS? (y/n):	"; read INSTALLPBIS
	if [ ! "${INSTALLPBIS}" = "n" ]; then
		INSTALLPBIS="y"
		GetUXHOST
		./pbis-enterprise-8.2.0.2969.linux.x86_64.rpm.sh
		mkdir -p /etc/opt/quest/vas
		echo "GG-UX-GRP-UXHOST-ede" > /etc/opt/quest/vas/users.allow
		echo "${UXHOST}" >> /etc/opt/quest/vas/users.allow
		mkdir -p /var/log/pbislogs
		/opt/pbis/bin/domainjoin-cli --logfile /var/log/pbislogs/join-qdtqoda11-01062014.log --loglevel warning join --disable hostname --notimesync corp.twcable.com vasadmin
		if [ ! "$UXHOST" = "" ]; then
			/opt/pbis/bin/config require "TWCCORP\GG-UX-GRP-UXHOST-ede" "TWCCORP\${UXHOST}"
		else
			/opt/pbis/bin/config require "TWCCORP\GG-UX-GRP-UXHOST-ede"
		fi
		/opt/pbis/bin/config --show req
		echo "DONE"
		echo "#########################################################################"
		echo -n "Press (R) to rerun installer, or ENTER to continue:"; read NEXT
		if [ "${NEXT}" = "R" ]; then
			./pbis-enterprise-8.2.0.2969.linux.x86_64.rpm.sh
			echo "GG-UX-GRP-UXHOST-ede" > /etc/opt/quest/vas/users.allow
			echo "${UXHOST}" >> /etc/opt/quest/vas/users.allow
			/opt/pbis/bin/domainjoin-cli --logfile /var/log/pbislogs/join-qdtqoda11-01062014.log --loglevel warning join --disable hostname --notimesync corp.twcable.com vasadmin
			if [ ! "$UXHOST" = "" ]; then
			/opt/pbis/bin/config require \"XXX\" \"TWCCORP\${UXHOST}\"
			else
				/opt/pbis/bin/config require \"XXX\"
			fi
			/opt/pbis/bin/config --show req
		fi
	else
		echo "	Skipping PBIS:"
	fi
	echo "DONE"
	echo "#########################################################################"
else
	echo "PBIS install not found:"
	echo "PRESS ANY BUTTON TO CONTINUE:"; read NEXT
	echo "DONE"
	echo "#########################################################################"
fi
echo " XYMON MONITORING:"
if [ -e xymon-client-4.3.17-1.el6.x86_64.rpm ]; then
	echo -n "	Would you like to install Xymon (y/n):	"; read INSTALLXYMON
	if [ ! "${INSTALLXYMON}" = "n" ]; then
		INSTALLXYMON="y"
		rpm -ivh xymon-client-4.3.17-1.el6.x86_64.rpm
		echo "DONE"
		echo "#########################################################################"
		echo -n "Press (R) to rerun installer, or ENTER to continue:"; read NEXT
		if [ "${NEXT}" = "R" ]; then
			rpm -ivh xymon-client-4.3.17-1.el6.x86_64.rpm
		fi
	else
		echo "	Skipping Xymon:"
	fi
	echo "DONE"
	echo "#########################################################################"
else
	echo "Xymon install not found:"
	echo "PRESS ANY BUTTON TO CONTINUE:"; read NEXT
	echo "DONE"
	echo "#########################################################################"
fi
cd /
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
echo -n "	Please enter the UXHOST for users.allow:"
read UXHOST
	#Set and add UXHOST to users.allow
echo "GG-UX-GRP-UXHOST-ede" > /etc/opt/quest/vas/users.allow
echo "${UXHOST}" >> /etc/opt/quest/vas/users.allow
	#Edit vas.conf
	#Flush domain information
/opt/quest/bin/vastool flush statedir
echo "	VAS Password = tV!ojLeY"
	#Rejoin to the domain with correct IP infomration and UXHOST
/opt/quest/bin/vastool -u vasadmin join -f -c OU=HOSTS,OU=Unix,DC=Corp,DC=TWCABLE,DC=com -n ${HOST}.corp.twcable.com corp.twcable.com
	#Remove expired license
/opt/quest/bin/vastool status
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
echo "	REBOOT SERVER FOR CHANGES:"
sed -i 's/\#PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/\#PermitRootLogin yes/PermitRootLogin no/' /etc/opt/quest/ssh/sshd_config
echo -n "	Would you like to reboot the server (y/n):  "; read REBOOTSER
	if [ ! "${REBOOTSER}" = "n" ]; then
		shutdown -r now
	fi
}

main() {
##############################################################################
# Main Section																 #
#	Calls all functions in order of operations								 #
##############################################################################
	#Asks user if they have run the prescript file to set hostname first.
RunPrescript
	#Set all variables to be used throughout the script.
SetVar
	#If VMWare Tools is mounted, begin and complete install
InstallVMWare
	#Begin chain of functions to acquire user input
WhichGet
	#Call SetIPv6Off function
SetIPv6Off
	#Call SetHosts function
SetHosts
	#Call SetEth0 function
SetEth0
	#Call SetEth1 function (if BACKNET=y)
SetEth1
	#Call InstallApplications function for PBIS and Xymon
InstallApplications
	#Call ConfigureVAS function
ConfigureVAS
	#Call ConfigureNetbackup function if Backnet exists
ConfigureNetbackup
	#Call ConfigureXymon function
ConfigureXymon
	#Run Validation function which creates a log to check for errors
RunValidation
	#Ask user if they would like to reboot to apply changes
Reboot
}

main