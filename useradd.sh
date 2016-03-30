#!/bin/sh
#-
# Copyright (c) 2013-2014 SRI International
# All rights reserved.
#
# This software was developed by SRI International and the University of
# Cambridge Computer Laboratory under DARPA/AFRL contract FA8750-10-C-0237
# ("CTSRD"), as part of the DARPA CRASH research programme.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
# OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
# LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
# OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
# SUCH DAMAGE.
#
# useradd - add user with deligated ZFS file system
#
# Before this script will work, you must create the appropriate permission
# set on pool/exports/users.  This one should work:
# zfs allow -s @users_delegation clone,create,destroy,mount,promote,rename,sharenfs,snapshot pool/exports/users

DEFSHELL=/bin/tcsh
DRYRUN=0
VERBOSE=0

HOME_DIR=/home
HOME_DATASET=pool${HOME_DIR}
EXPORT_DIR=/exports/users
EXPORT_DATASET=pool${EXPORT_DIR}

warn()
{
	echo "useradd:" "$@" 1>&2
}

err()
{
	ret=$1
	shift

	echo "useradd:" "$@" 1>&2
	exit $ret
}

verb()
{
	if [ $VERBOSE -gt 0 ]; then
		echo "$@"
	fi
}

doit()
{
	verb "$@"
	if [ $DRYRUN -eq 0 ]; then
		"$@"
	fi
}

usage()
{
	cat << EOF 1>&2
usage: useradd [-k <keyfile>] <name>
EOF
	exit 1
}

shell="$DEFSHELL"

while getopts "k:nv" opt; do
	case "$opt" in
	k)	keyfile="${OPTARG}" ;;
	n)	DRYRUN=1 ;;
	v)	VERBOSE=1 ;;
	*)	usage ;;
	esac
done
shift $(($OPTIND - 1))

if [ $# -ne 1 ]; then
	usage
fi

name=$1

if ! id "${name}" > /dev/null 2>&1; then
	err 1 "unknown user: '${name}'"
fi
ugid=`id -g $name`
if [ "$ugid" != "`id -u $name`" ]; then
	err 1 "user $name exists, but uid != gid"
fi

homedir=${HOME_DIR}/$name
if [ ! -d $homedir ]; then
	ds=${HOME_DATASET}/$name
	doit zfs create $ds
	if [ $homedir != `zfs get -o value -H mountpoint $ds` ]; then
		doit zfs set mountpoint=${homedir} ${ds}
	fi
	doit chown $name:$name $homedir
	doit chmod 755 $homedir
fi
sshdir=$homedir/.ssh
if [ ! -d $sshdir ]; then
	doit mkdir $sshdir
	doit chown $name:$name $sshdir
	doit chmod 700 $sshdir
fi
if [ -n "${keyfile}" ]; then
	if [ -e $sshdir/authorized_keys ]; then
		warn "$sshdir/authorized_keys exists, ignoring -k ${keyfile}"
	else
		doit cp $keyfile $sshdir/authorized_keys
		doit chown $name:$name $sshdir/authorized_keys
		doit chmod 700 $sshdir/authorized_keys
	fi
fi


# Create the users's delegated ZFS directory
userdir="${EXPORT_DIR}/$name"
echo "Creating ${userdir} if required"
if [ ! -d "$userdir" ]; then
	doit mkdir $userdir
fi
if [ $DRYRUN -eq 0 ]; then
	eval `stat -s $userdir`
else
	st_uid="0"
	st_gid="0"
fi
if [ "$st_uid" -ne "$ugid" -o "$st_gid" -ne "$ugid" ]; then
	doit chown $name:$name $userdir
fi
ds=`zfs list -H -o name ${EXPORT_DATASET}/$name 2> /dev/null`
if [ -z "$ds" ]; then
	ds=${EXPORT_DATASET}/$name
	doit zfs create -o org.freebsd:owner=$name $ds
	if [ $userdir != `zfs get -o value -H mountpoint $ds` ]; then
		doit zfs set mountpoint=${homedir} ${ds}
	fi
	doit zfs allow $name @users_delegation $ds
fi

if [ $DRYRUN -eq 0 ]; then
	mount -t zfs | egrep -q '^'${ds}' on '${userdir}' \(zfs, .*, mounted by '${name}'\)$'
else
	false
fi
if [ $? -ne 0 ]; then
        # Unmount file system if it is actually mounted.
        if [ "`zfs get -H -o value mounted ${ds} 2> /dev/null`" = "yes" ]; then
                doit zfs umount ${ds}
        fi

	doit su -m ${name} -c "zfs mount ${ds}"
fi
