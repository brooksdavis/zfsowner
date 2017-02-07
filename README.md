zfsowner
========

Set of scripts to mount zfs filesystems as users to support delegated
administration and non-root superuser rights.  As currently implemented,
the scripts are suitable for managing NFS shares to test lab machines.

Setup
-----
*	Install and modify the scripts below as required for your setup.

*	Add the following to /etc/sysctl.conf:

		vfs.usermount=1
		vfs.zfs.super_owner=1

	and set the sysctls manually or reboot.

*	On the parent export directory (e.g. pool/exports/users) create
	a delegated permission set named @users_delegation

		zfs allow -s @users_delegation clone,create,destroy,mount,promote,rename,sharenfs,snapshot pool/exports/users

*	You will likely also want to set a default sharenfs property

		zfs set sharenfs="-ro -network 192.168.5.0/24 -maproot=root" pool/exports/users

Scripts
-------
*	useradd.sh

	Install in /usr/local/sbin or your preferred location and
	customize as required.

	Simple script to add a user with a ZFS home directory and a
	second delegated ZFS storage location subject to user control.

*	zfsowner

	Install in /usr/local/etc/rc.d to remount user owned mount
	points as the user at boot.  Such mountpoints are marked by
	the org.freebsd:owner attribute.

*	zfs-update-exports

	Install in /usr/local/bin and add an entry to sudoers like

		ALL ALL=(root) NOPASSWD: /usr/local/bin/zfs-update-exports

	to allow users to force a refresh of exports after altering their
	delegated share setttings.
