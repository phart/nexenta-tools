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
# add tunables for 10G networking
#
echo "setting 10G tunables..."
echo "" >> /etc/system
echo "* 10G tunables" >> /etc/system
echo "* `date`" >> /etc/system
echo "set ndd:tcp_wscale_always=1" >> /etc/system
echo "set ndd:tcp_tstamp_if_wscale=1" >> /etc/system
echo "set ndd:tcp_max_buf=16777216" >> /etc/system
echo "set ndd:tcp_cwnd_max=8388608" >> /etc/system
echo "set ndd:tcp_xmit_hiwat=1048576" >> /etc/system
echo "set ndd:tcp_recv_hiwat=1048576" >> /etc/system
