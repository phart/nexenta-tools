#!/bin/bash
#
# post-install.sh
#
# NexentaStor post installation script.
#
# Copyright (C) 2016  Nexenta Systems
# William Kettler <william.kettler@nexenta.com>
#
# 2016-06-30 - Initial commit
# 2016-07-17 - Spelling fixes
#

#
# Generate a rollback checkpoint
#
echo "Create a rollback checkpoint..."
nmc -c "setup appliance checkpoint create"

#
# Disable SMART
#
echo "Disabling SMART collector..."
nmc -c 'setup collector smart-collector disable'

echo "Disabling Auto SMART check..."
nmc -c 'setup trigger nms-autosmartcheck disable'

echo "Disabling SMART on all drives..."
nmc -c 'setup lun smart disable all'

#
# Enable SMB2
#
echo "Enabling SMB2..."
sharectl set -p smb2_enable=true smb

echo "Disabling oplocks..."
svccfg -s network/smb/server setprop smbd/oplock_enable = false
svcadm refresh network/smb/server
svcadm restart network/smb/server

#
# adjust swap
#
echo "Adjusting swap..."
swap -d /dev/zvol/dsk/syspool/swap
MEMSIZE=`prtconf | grep '^Mem' | /usr/gnu/bin/awk '{printf "%d", ($3/1024)}'`
if [[ "$MEMSIZE" -le 4 ]]; then
    SWAPSIZE=1G
elif [[ "$MEMSIZE" -le 4 ]]; then
    SWAPSIZE=2G
elif [[ "$MEMSIZE" -lt 128 ]]; then
    SWAPSIZE=4G
elif [[ "$MEMSIZE" -lt 256 ]]; then
    SWAPSIZE=8G
else    # 256G or greater
    SWAPSIZE=16G
fi
zfs set volsize=$SWAPSIZE syspool/swap
swap -a /dev/zvol/dsk/syspool/swap

#
# Enable VAAI
#
echo "Enabling VAAI..."
echo "" >> /etc/system
echo "* Enable VAAI" >> /etc/system
echo "* `date`" >> /etc/system
echo "set stmf_sbd:HardwareAcceleratedInit = 1" >> /etc/system
echo "set stmf_sbd:HardwareAcceleratedLocking = 1" >> /etc/system
echo "set stmf_sbd:HardwareAcceleratedMove = 1" >> /etc/system

#
# Enable NMI
#
echo "Enabling NMI..."
echo "" >> /etc/system
echo "* Enable NMI" >> /etc/system
echo "* `date`" >> /etc/system
echo "set snooping=1" >> /etc/system
echo "set pcplusmp:apic_panic_on_nmi=1" >> /etc/system
echo "set apix:apic_panic_on_nmi = 1" >> /etc/system

#
# add tunables for 10G networking; /etc/system as previous does not work
#
echo "setting 10G tunables..."

ipadm set-prop -p send_buf=1048576 tcp
ipadm set-prop -p recv_buf=1048576 tcp
ipadm set-prop -p max_buf=16777216 tcp
ipadm set-prop -p _wscale_always=1 tcp
ipadm set-prop -p _tstamp_if_wscale=1 tcp
ipadm set-prop -p _cwnd_max=8388608 tcp

#
# install fmware tools if this is a VSA
#
dmidecode -t 1 | grep 'Product Name' | grep -i vmware > /dev/null
if [ $? == 0 ]; then
    echo "VMware detected, checking for vmware tools...."
    dpkg -l | grep 'Open Virtual Machine Tools' > /dev/null
    if [ $? != 0 ]; then
        echo "Open VM Tools being installed..."
        dpkg -i service-management-open-vm-tools_40-0-2_solaris-i386.deb
    else
        echo "Open VM Tools found"
    fi
fi
