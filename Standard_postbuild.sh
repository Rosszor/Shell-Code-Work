#!/bin/sh
# 					Script Created by Ross Thompson
# 							Version: 2.1
#
# File: Autocfg_postbuild.sh       
# Created: 2/17/2015 as Autocfg_postbuild.sh
# Purpose: Will run through server immediately after Autocfg imaging and make necessary changes. Minimum of 70GB Root drive required
 
################################################################################
#                                                                            
# MODIFICATIONS: 
# Version: 1.0 - 2/17/2015 
# - Created script.

# Version: 1.1 - 2/18/2015 
# - Added User Input code for NIC settings and Location.

# Version: 1.2 - 2/19/2015 
# - Separated some functions for simplicity and functionality.
# - Began commenting all functions for ease of use.
# - Added some variation dependent on user input.
# - Added several new functions for increased scalability 

# Version: 1.3 - 2/20/2015 
# - Added support for creating /product logical from root volume group.
# - Fixed some bugs in the code and continued to add further comments. 

# Version: 1.4 - 2/22/2015 
# - Separated the UserInput and SetBacknetVars functions for increased scalability and addition of a "Back" option for user interface.
# - Added a CheckInput function that uses a while loop and an array of expected answers to stop incorrect user input.

# Version: 1.5 - 2/27/2015 
# - Added a root password change.
# - Added KSH and NSCD yum installs.

# Version: 1.6 - 3/2/2015 
# - Added a while loop in InstallPackages that will read a file full of package names and install them one by one. This will add re-usability for future packages that need to be installed. Simply add the package name to the file and it will be installed upon running this script.
# - Added a log file, and set all input, output and error messages to it.
# - Removed previously entered lines from files to avoid duplicate lines being entered if script is run multiple times.

# Version: 1.7 - 3/3/2015 
# - Added small function that sets the GATEWAY value in /etc/sysconfig/network.
# - Moved SetIPv6Off further up in the chain of commands to service network restart acts without error
# - Added function that checks for, mounts and runs the VMWare tools installer.

# Version: 1.8 - 3/4/2015  
# - Added small changes to InstallPackages function (sshd config)
# - Created functions to configure services, set the home directory, set the MOTD, set the static-route and install 3rd party applications. 
# - Re-ordered the main function to run InstallApplications before setting production IPs
# - Added a SetMSVIP function to assure that corepnas01cdp can be mounted, DNS will resolve and packages can be installed before setting production IPs
# - Added Configuration functions for Tidal, VAS and Netbackup to be performed after 3rd party applications have been installed.
# - Added a GetUXHOST function to get UXHOST from user for use in vas users.allow file later in the script.
# - Added a rerun ability to application installs, in case of error can CTRL-Z, fix and restart the script.
# - Added a quick sendmail that will send the /tmp/Postbuild_Log file to the user defined email address.

# Version: 1.9 - 3/5/2015
# - Fixed a continuous loop between asking for Backnet Netmask and Backnet MAC address. 
# - Added variables and if statements so that configure Tidal/VAS/Netbackup are only called if the user selected to install them. 
# - Fixed an issue where users.allow file was being emptied during the ConfigureVAS function.

# Version: 2.0 - 3/6/2015
# - Began adding configurations for CDC environment.
# - Added a ConfigureXymon function to assure xymon-client is properly set up.
# - Changed all options from "if y" to "if not n" so that default answer is yes.

# Version: 2.1 - 3/9/2015
# - Finished adding NCE/CDC VM integration. Tested working
# - Began incorporating necessary actions from previous VerifyServer and ConfigureServer scripts. Finished Verification script. Log-file is now emailed to user that displays all information used in validation of server. 
# - ConfigureServer script not necessary at this time for VMs.

# Version: 2.2 - 3/11/2015
# - Removed Configure and validate functions and added to a separate script. This will allow the user to reboot the server after all installs and IP addresses have been set, change the VLAN in vCenter, and subsequently configure and validate with the server using the correct IP addresses. 

# To Add/Update
# - Add PBIS install script and configuration
# - Add configuration functions for other applications installed. 
# - Add options for physical boxes and make sure CDC VM's work
##############################################################################

#Turn off Debug mode
set +x

SetVar() {
##############################################################################
# Set Variables for Script                                                   #
# 	- Some of the set variables will not be used. Most are set for future	 #
# 	expansion of the script.												 #	
##############################################################################
if [ -d "/opt/VRTSvcs/bin" ]; then PATH=$PATH:/opt/VRTSvcs/bin; fi
if [ -d "/opt/VRTS/bin" ]; then PATH=$PATH:/opt/VRTS/bin; fi
if [ -d "/usr/local/bin" ]; then PATH=$PATH:/usr/local/bin; fi
export PATH

CP="/bin/cp -p"
DF="/bin/df"
LS="/bin/ls"
LL="${LS} -ltr"
LN="/bin/ln"
MV="/bin/mv"
PS="/bin/ps -aef"
RM="/bin/rm"
CAT="/bin/cat"
MNT1="/mnt"
ZFS="/sbin/zfs"
ECHO="/bin/echo"
LSFS="/usr/sbin/lsfs"
PBRUN="/usr/local/bin/pbrun"
TOUCH="/bin/touch"
DATE="$(date +%h%d)"
HOST="`hostname|awk -F. '{print $1}'`"
NZHOST="`hostname|awk -F. '{print $1}'|cut -c1-4`"
SLEEP2="/bin/sleep 2"
TMPDIR="/var/tmp"
SYSFILE="/etc/system"
MKFS="/opt/VRTS/bin/mkfs"
VXDG="/usr/sbin/vxdg"
VXDISK="/usr/sbin/vxdisk"
VXPRINT="/usr/sbin/vxprint"
BPLIST="/usr/openv/netbackup/bin/bplist"
BPCLNT="/usr/openv/netbackup/bin/bpclntcmd"
LUXADM="/usr/sbin/luxadm"
PROJADD="/usr/sbin/projadd"
PROJMOD="/usr/sbin/projmod"
PRTDIAG="/usr/sbin/prtdiag -v"
VXASSIST="/usr/sbin/vxassist"
#Variable used by InputCheck function while loop to check if user input is valid
VALID="f"
#Variable to be used by InputCheck function, contains user input
INPUT="x"
#Variable array used by InputCheck function, contains expected answers
EXPECTED[0]="y"
EXPECTED[1]="n"
EXPECTED[2]="b"
#Variable for log file that all user input and script output is written to
LOG="/tmp/Postbuild_Log"
#Variable to hold MAC address of Eth0
ETH0MAC=$(ifconfig eth0 |grep HWaddr |awk -F"HWaddr " '{print $2}')
#Variable to hold VMWareTools mount
VMWARE="/dev/cdrom"
#Variables for use if backnet is added and netbackup to be installed
NB_HOME=/usr/openv/netbackup
BN_HOST=`hostname`-bn
DOMAIN=corpbacknet.twcable.com
ROUTE_DIR=/etc/init.d
ROUTE=static-route
FQDN=$BN_HOST.$DOMAIN
#Variables needed for verify server
CRONALLOW="/etc/cron.allow"
NTPFILE="/etc/ntp.conf"
}

SetRootPass() {
##############################################################################
# Changes the root password of the server                                    #
# 	- Changes from autocfg default password of "jack@lope" to the standard   #
#   root pass for cloud engineering.			  					         #	
##############################################################################
echo "Setting Cloud Engineering Root Password"
echo -e "changeme\changeme" |(passwd --stdin $USER)
echo "DONE"
echo "#########################################################################"
}

SetMSVIP() {
##############################################################################
# Sets Eth0 to a dedicated MSV IP address to assure that corepnas01cdp can   #
# 	be mounted and 3rd party apps can be installed.							 #
#	- Also assures that DNS will resolve and packages can be installed 	 	 #
#	error.																	 #
##############################################################################
if [ "${LOCATION}" = "y" ]; then
	MSVIP="10.64.170.219"
	MSVGATEWAY="10.64.170.1"
else 
	MSVIP="10.136.173.170"
	MSVGATEWAY="10.136.173.1"
fi
echo "	Configuring /etc/sysconfig/network:"
echo DEVICE=eth0 > /etc/sysconfig/network-scripts/ifcfg-eth0
echo BOOTPROTO=static >> /etc/sysconfig/network-scripts/ifcfg-eth0
echo HOSTNAME=${HOST} >> /etc/sysconfig/network-scripts/ifcfg-eth0
echo HWADDR=${ETH0MAC} >> /etc/sysconfig/network-scripts/ifcfg-eth0
echo TYPE=Ethernet >> /etc/sysconfig/network-scripts/ifcfg-eth0
echo IPADDR=${MSVIP} >> /etc/sysconfig/network-scripts/ifcfg-eth0
echo NETMASK=255.255.255.0 >> /etc/sysconfig/network-scripts/ifcfg-eth0
echo NM_CONTROLLED=no >> /etc/sysconfig/network-scripts/ifcfg-eth0
echo ONBOOT=yes >> /etc/sysconfig/network-scripts/ifcfg-eth0
	#Setting Gateway
sed -i '/GATEWAY/d' /etc/sysconfig/network
echo "GATEWAY=${MSVGATEWAY}" >> /etc/sysconfig/network
	#Restart Network to get things pinging
service network restart
echo "DONE"
echo "#########################################################################"
}

GetLOCATION(){
##############################################################################
# Asks user for Server Location (cdc/cdp) information.						 #
##############################################################################
echo "#########################################################################"
#Setting variables to be used by CheckInput function
VALID="f"
EXPECTED[0]=y
EXPECTED[1]=n
EXPECTED[2]=69
echo -n "	Is the server located in Charlotte? (y/n)  "
read LOCATION
INPUT=${LOCATION}
CheckInput
LOCATION=${INPUT}
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
GetPGATEWAY
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
	GetPIP
fi
GetPNETMASK
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
	GetPGATEWAY
fi
HasBACKNET
}

#GetUXHOST() {
##############################################################################
# Asks user for UXHOST group to add to users.allow file later in the script  #
##############################################################################
#echo "#########################################################################"
#echo -n "	UXHOST for users.allow? (b)  "
#read UXHOST
#if [ "${UXHOST}" = "b" ]; then
	#GetPNETMASK
#fi
#HasBACKNET
#}

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
		#Netbackup must be installed
	InstallNetbackup
	GetBIP 
fi
if [ "${BACKNET}" = "b" ]; then
	GetPNETMASK
fi
HasPRODUCT
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
	HasBACKNET
fi
GetBGATEWAY
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
	GetBIP
fi
GetBNETMASK
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
	GetBGATEWAY
fi
GetBMAC
}

GetBMAC() {
##############################################################################
# Asks user for Backnet MAC Address information.                             #
# Once input is provided, the next function is called						 #
# Offers a "back" option to go to previous question.						 #
##############################################################################
echo "#########################################################################"
echo -n "	Backnet MAC Address? (b)  "
read BMAC
if [ "${BMAC}" = "b" ]; then
	GetBNETMASK
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
if [ "${PRODUCT}" = "y" ]; then
	SetProductVars
fi
if [ "${PRODUCT}" = "b" ]; then
	HasBACKNET
fi
}

SetProductVars() {
##############################################################################
# Runs if user confirms /product creation                                    #
# Once input is provided, the next function is called						 #
# Offers a "back" option to go to previous question.						 #
##############################################################################
echo "#########################################################################"
#Setting variables to be used by CheckInput function
VALID="f"
EXPECTED[0]=1
EXPECTED[1]=2
EXPECTED[2]=b

echo "Available Drives for Product:"
echo "Please take note of available free space."
echo "#################################"
vgdisplay ${HOST} |grep Free
echo "#################################"
fdisk -l |grep /dev/sdb
echo "#################################"
echo -n "	Is /product coming from Root Disk(1) or an Additional Disk(2)? (1/2/b)  "
read PRODUCTLOCATION
INPUT=${PRODUCTLOCATION}
CheckInput
PRODUCTLOCATION=${INPUT}
if [ "${PRODUCTLOCATION}" = "b" ]; then
	HasPRODUCT
fi
echo -n "	What is the size of the /product in GB?  "
read PRODUCTSIZE
CreateProduct
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
	PRODUCTSIZE=$[ $PRODUCTSIZE - 5 ]
	if [ "${PRODUCTLOCATION}" = "1" ]; then	
		lvcreate -L ${PRODUCTSIZE}G -n lv_product ${HOST}
		mkfs.ext4 /dev/${HOST}/lv_product
		mkdir /product
		echo "/dev/${HOST}/lv_product /product                    ext4    defaults        1 2" >> /etc/fstab
		mount /product
		echo "DONE"
		echo "#########################################################################"
	else
		if [ ! -d "/dev/sdb1" ]; then
			echo "n
			p
			1
			
			
			w" |fdisk /dev/sdb
			vgcreate vg_product /dev/sdb1
			lvcreate -L ${PRODUCTSIZE}G -n lv_product vg_product
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
	fi
else
	echo "	A /product directory already exists. Please check that a partition has not already been created and try again."
	echo "#########################################################################"
fi
}

ConfigureServices() {
##############################################################################
# Enables and Disables all required services                                 #
##############################################################################
echo "	Enabling/Disabling Services:"
echo "	Turning off iptables:"
chkconfig --level 2345 iptables off
chkconfig --level 2345 ip6tables off
echo "	Enabling nscd:"
service nscd start
chkconfig --level 2345 nscd on
echo "	Enabling NTP:"
service ntpd start
chkconfig ntpd on
echo "	Enabling IMPI:"
service ipmi start
chkconfig --level 2345 ipmi on
echo "	Setting SELinux:"
sed -i 's/SELINUX=disabled/SELINUX=permissive/' /etc/sysconfig/selinux
echo 0 > /selinux/enforce
	#Allow root login (will remove once script includes vas install/config)
if [ "`grep \"^PermitRootLogin yes\" /etc/ssh/sshd_config`" = "" ]; then
    echo "	Allowing root login from SSH:"
    echo "PermitRootLogin yes" >> /etc/ssh/sshd_config
fi
	#Adding TWC NTP server to ntp.conf
echo "	Add NTP servers to the ntp.conf:"
	#Creating backup of original
mv /etc/ntp.conf /etc/ntp.conf.orig
	#Setting driftfile, for frequency syncro 
egrep -v "^driftfile|^server" /etc/ntp.conf.orig > /etc/ntp.conf
echo "server twcntp.twcable.com" >> /etc/ntp.conf
	#Call SetIPv6Off function
SetIPv6Off
echo "DONE"
echo "#########################################################################"
}

SetHomeDir() {
##############################################################################
# Performs configuration changes for users /home direcotry                   #
##############################################################################
echo "	Set \$USER default home directory:"
if [ -d /home ]; then
    if [ ! -d /export/home ]; then 
		mkdir -p /export/home; 
	fi
	echo "	Moving all home direcotries to /export:"
	mv /home/* /export/home
	rm -rf /home
	useradd -D -b /export/home
fi
echo "DONE"
echo "#########################################################################"
}

SetMOTD() {
##############################################################################
# Creates and displays TWC MOTD and configures issueserial                   #
##############################################################################
echo "	Add TWC MOTD and /etc/issueserial:"
cat >> /etc/issueserial << EOF
echo "Standard MOTD Text"

Kernel \r on an \m
Connected on \l at \b bps
\U

EOF
cat > /etc/motd << EOF
echo "Standard MOTD Text"
echo "DONE"
echo "#########################################################################"
EOF
}

SetStatic_route() {
##############################################################################
# Creates and configures static-route if user entered backnet information.   #
##############################################################################
if [ ! -e /etc/init.d/static-route ]; then
	echo "	Adding /etc/init.d/static-route:"
	echo "route add -net 10.222.56.0 gateway ${BGATEWAY} netmask 255.255.252.0" > /etc/init.d/static-route
	chmod +x /etc/init.d/static-route
	if [ ! -h /etc/rc3.d/S76static-route ]; then
		ln -s /etc/init.d/static-route /etc/rc3.d/S76static-route
	fi
else
	echo "	Static-route already exists:"
fi
/etc/init.d/static-route
echo "DONE"
echo "#########################################################################"
}

SetResolv() {	
##############################################################################
# Sets /etc/resolv.conf based on user input                                  #
#	- Uses input from user in LOCATION variable to determine order of 		 #
# 	nameservers in the resolv.conf file. 									 #
# 	 - Uses Charlotte order as a default (if user does not answer question   #
#	from the UserInput function)											 #
##############################################################################
echo "  Editing Resolv.conf:"
echo "domain twcable.com" > /etc/resolv.conf
if [ "${LOCATION}" = "n" ]; then
	echo "nameserver xxx.xxx.xxx.xxx" >> /etc/resolv.conf
	echo "nameserver xxx.xxx.xxx.xxx" >> /etc/resolv.conf
else
	echo "nameserver xxx.xxx.xxx.xxx" >> /etc/resolv.conf
	echo "nameserver xxx.xxx.xxx.xxx" >> /etc/resolv.conf
fi
echo "search twcable.com css.twcable.com corpbacknet.twcable.com" >> /etc/resolv.conf
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
echo "${PIP}	${HOST}.twcable.com	${HOST}" >> /etc/hosts
echo "#" >> /etc/hosts
echo "# Primary IP" >> /etc/hosts
echo "${PIP}	${HOST}	Primary" >> /etc/hosts
if [ "${BACKNET}" = "y" ]; then
	echo "#" >> /etc/hosts
	echo "# Backnet IP" >> /etc/hosts
	echo "${BIP}	${HOST}-bn	Backnet" >> /etc/hosts
fi
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
	echo HWADDR=${BMAC} >> /etc/sysconfig/network-scripts/ifcfg-eth1
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

InstallPackages() {
##############################################################################
# Installs all Yum packages needed for the server                            #
##############################################################################
echo "	Installing and configuring necessary Yum packages:"
echo "	Installing SSHD:"
yum -y install openssh-server openssh-clients
service sshd start
chkconfig sshd on
sed -i 's/\(#ListenAddress 0.0.0.0*\)/ListenAddress 0.0.0.0/' /etc/ssh/sshd_config
service sshd restart
echo "DONE"
echo "#########################################################################"
echo "	Installing NFS-Utils:"
yum -y install nfs-utils
chkconfig nfs on
service rpcbind restart
service nfs restart
echo "DONE"
echo "#########################################################################"
echo "	Installing KSH Shell:"
yum -y install ksh
echo "DONE"
echo "#########################################################################"
echo "	Installing Xinetd:"
yum -y install xinetd
service xinetd restart
echo "DONE"
echo "#########################################################################"
while read line
do 
	echo "	Installing $line:"
	yum -y install $line
	echo "DONE"
	echo "#########################################################################"
done < RPMList.txt
}

InstallApplications() {
##############################################################################
# Mounts COREPINF01CDP and begins software installations required.		     #
#	Will wait for user input after each install process to assure that user  #
#	can note any failures or errors.										 #
##############################################################################
	#Mounting corepnas01cdp to /mnt for software installs
mount xxx.xxx.xxx.xxx:/osbuilds/LINUX/data/apps /mnt
cd /mnt
echo "#########################################################################"
	#Beginning Bladelogic install
echo "	BLADELOGIC:"
if [ -x install_Bladelogic ]; then
	echo -n "	Would you like to install BladeLogic? (y/n):  "; read INSTALLBL
	if [ ! "${INSTALLBL}" = "n" ]; then
		echo "	Begin Bladelogic install:"
		mkdir /usr/lib/rsc
		/mnt/install_Bladelogic
		echo -n "Press (R) to rerun installer, or ENTER to continue:"; read NEXT
		if [ "${NEXT}" = "R" ]; then
			/mnt/install_Bladelogic
		fi
	else
		echo "	Skipping BladeLogic:"
	fi
	echo "DONE"
	echo "#########################################################################"
else
    echo "BladeLogic install not found:"
	echo "PRESS ANY BUTTON TO CONTINUE:"; read NEXT
	echo "DONE"
	echo "#########################################################################"
fi
	#Beginning HPOV Install (Will add and edit when HPOV certified)
#echo "	HPOV:"
#if [ -x install_HPOV ]; then
	#echo -n "	Would you like to install HPOV? (y/n):  "; read INSTALLHPOV
	#if [ ! "${INSTALLHPOV}" = "n" ]; then
		#echo "	Begin HPOV install:"
		#/mnt/install_HPOV
		#echo -n "Press (R) to rerun installer, or ENTER to continue:"; read NEXT
		#if [ ""${NEXT}"" = "R" ]; then
		#	/mnt/install_HPOV
		#fi
	#else
	#	echo "	Skipping HPOV:"
	#fi
	#echo "DONE"
	#echo "#########################################################################"
#else
	#echo "HPOV 1103 install not found:"
    #echo "PRESS ANY BUTTON TO CONTINUE:"; read NEXT
	#echo "DONE"
	#echo "#########################################################################"
#fi
	#Beginning install of VAS
echo "	VAS:"
if [ -x install_VAS ]; then
	echo -n "	Would you like to install VAS? (y/n):  "; read INSTALLVAS
	if [ ! "${INSTALLVAS}" = "n" ]; then
		echo "	Begin Vintela VAS install:"
		/mnt/install_VAS
		echo -n "Press (R) to rerun installer, or ENTER to continue:"; read NEXT
		if [ "${NEXT}" = "R" ]; then
			/mnt/install_VAS
		fi
	else
		echo "	Skipping VAS:"
	fi
	echo "DONE"
	echo "#########################################################################"
else
	echo "VAS install not found:"
	echo "PRESS ANY BUTTON TO CONTINUE:"; read NEXT
	echo "DONE"
	echo "#########################################################################"
fi
	#Beginning Quest SSH install
echo "	QUEST SSH:"
if [ -x install_SSH ]; then
	echo -n "	Would you like to install Quest SSH? (y/n):  "; read INSTALLQSSH
	if [ ! "${INSTALLQSSH}" = "n" ]; then
		echo "	Begin Quest SSH install:"
		/mnt/install_SSH
		echo -n "Press (R) to rerun installer, or ENTER to continue:"; read NEXT
		if [ "${NEXT}" = "R" ]; then
			/mnt/install_SSH
		fi
	else
		echo "	Skipping Quest SSH:"
	fi
	echo "DONE"
	echo "#########################################################################"
else
	echo "Quest SSH install not found:"
	echo "PRESS ANY BUTTON TO CONTINUE:"; read NEXT
	echo "DONE"
	echo "#########################################################################"
fi
	#Beginning Tidal install
echo "	TIDAL:"
if [ -x install_Tidal ]; then
	echo -n "	Would you like to install Tidal? (y/n):  "; read INSTALLTIDAL
	if [ ! "${INSTALLTIDAL}" = "n" ]; then
		echo "	Begin Tidal install:"
		/mnt/install_Tidal
		echo -n "Press (R) to rerun installer, or ENTER to continue:"; read NEXT
		if [ "${NEXT}" = "R" ]; then
			/mnt/install_Tidal
		fi
	else
		echo "	Skipping Tidal:"
	fi
	echo "DONE"
	echo "#########################################################################"
else
	echo "Tidal install not found:"
	echo "PRESS ANY BUTTON TO CONTINUE:"; read NEXT
	echo "DONE"
	echo "#########################################################################"
fi
	#Beginning PowerBroker install
echo "	POWERBROKER:"
if [ -x install.powerbroker ]; then
	echo -n "	Would you like to install PowerBroker? (y/n):  "; read INSTALLPB
	if [ ! "${INSTALLPB}" = "n" ]; then
		echo "	Begin PowerBroker install:"
		/mnt/install.powerbroker
		echo -n "Press (R) to rerun installer, or ENTER to continue:"; read NEXT
		if [ "${NEXT}" = "R" ]; then
			/mnt/install.powerbroker
		fi
	else
		echo "	Skipping PowerBroker:"
	fi
	echo "DONE"
	echo "#########################################################################"
else
	echo "PowerBroker install not found:"
	echo "PRESS ANY BUTTON TO CONTINUE:"; read NEXT
	echo "DONE"
	echo "#########################################################################"
fi
	#Beginning Splunk Install
echo "	SPLUNK:"
if [ -x install_Splunk ]; then
	echo -n "	Would you like to install Splunk? (y/n):  "; read INSTALLSPLUNK
	if [ ! "${INSTALLSPLUNK}" = "n" ]; then
		echo "	Begin Splunk install:"
		/mnt/install_Splunk
		echo -n "Press (R) to rerun installer, or ENTER to continue:"; read NEXT
		if [ "${NEXT}" = "R" ]; then
			/mnt/install_Splunk
		fi
	else
		echo "	Skipping Splunk:"
	fi
	echo "DONE"
	echo "#########################################################################"
else
	echo "Splunk install not found:"
	echo "PRESS ANY BUTTON TO CONTINUE:"; read NEXT
	echo "DONE"
	echo "#########################################################################"
fi
	#Beginning Netbackup Install
echo "	NETBACKUP:"
if [ -x install_NetBackup ]; then
	echo -n "	Would you like to install NETBACKUP? (y/n):  "; read INSTALLNB
	if [ ! "${INSTALLNB}" = "n" ]; then
		echo "	Begin Netbackup install:"
		/mnt/install_NetBackup
		echo -n "Press (R) to rerun installer, or ENTER to continue:"; read NEXT
		if [ "${NEXT}" = "R" ]; then
			/mnt/install_NetBackup
		fi
	else
		echo "	Skipping NETBACKUP:"
	fi
	echo "DONE"
	echo "#########################################################################"
else
	echo "Netbackup install not found:"
	echo "PRESS ANY BUTTON TO CONTINUE:"; read NEXT
	echo "DONE"
	echo "#########################################################################"
fi
	#Unmounting corepnas01cdp
cd /
umount /mnt
}

InstallNetbackup() {
##############################################################################
# Installs Netbackup automatically if backnet VIP is present			     #
##############################################################################
	#Mounting corepnas01cdp to /mnt for software installs
mount 10.136.160.61:/osbuilds/LINUX/data/apps /mnt
cd /mnt
echo "	NETBACKUP:"
if [ -x install_NetBackup ]; then
	if [ ! -e "/usr/openv/netbackup/bp.conf" ]; then
		INSTALLNB="y"
		echo "	Begin Netbackup install:"
		/mnt/install_NetBackup
		echo -n "Press (R) to rerun installer, or ENTER to continue:"; read NEXT
		if [ "${NEXT}" = "R" ]; then
			/mnt/install_NetBackup
		fi
		echo "DONE"
		echo "#########################################################################"
	else
		echo "Netbackup already installed, skipping:"
		echo "#########################################################################"
	fi	
else
	echo "Netbackup install not found:"
	echo "PRESS ANY BUTTON TO CONTINUE:"; read NEXT
	echo "DONE"
	echo "#########################################################################"
fi
cd /
umount /mnt
}

SetIPv6Off() {
##############################################################################
# Turns off and disables IPv6. 					                             #
##############################################################################
echo "	Disabling IPV6:"
echo 1 > /proc/sys/net/ipv6/conf/all/disable_ipv6
echo "# IPv6 disabled" >> /etc/sysctl.conf
#Remove any previously entered lines
sed -i '/net.ipv6.conf.all.disable_ipv6 = 1/d' /etc/sysctl.conf
sed -i '/net.ipv6.conf.default.disable_ipv6 = 1/d' /etc/sysctl.conf
sed -i '/net.ipv6.conf.lo.disable_ipv6 = 1/d' /etc/sysctl.conf
#Add 3 lines to assure IPv6 remains turned off
echo "net.ipv6.conf.all.disable_ipv6 = 1" >> /etc/sysctl.conf
echo "net.ipv6.conf.default.disable_ipv6 = 1" >> /etc/sysctl.conf
echo "net.ipv6.conf.lo.disable_ipv6 = 1" >> /etc/sysctl.conf
#sysctl -p
echo "DONE"
echo "#########################################################################"
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

Reboot() {
##############################################################################
# Validation	                                                             #
##############################################################################
echo "	REBOOTING SERVER FOR CHANGES:"
shutdown -r now
}

main() {
##############################################################################
# Main Section																 #
#	Calls all functions in order of operations								 #
##############################################################################
	#Set all variables to be used throughout the script.
SetVar
	#Set the root password to Cloud Engineering default
SetRootPass
	#If VMWare Tools is mounted, begin and complete install
#InstallVMWare
	#Call GetLOCATION function
GetLOCATION
	#Call SetResolv function
SetResolv
	#Call SetMSVIP function
#SetMSVIP
	#Call InstallPackages function
InstallPackages
	#Call InstallApplications
InstallApplications
	#Call ConfigureServices function
ConfigureServices
	#Begin chain of functions to acquire user input
#GetPIP
	#Call SetHosts function
SetHosts
	#Call SetEth0 function
SetEth0
	#Call SetEth1 function (if BACKNET=y)
SetEth1
	#Call SetHomeDir function
SetHomeDir
	#Call SetMOTD function
SetMOTD
Reboot
}
main