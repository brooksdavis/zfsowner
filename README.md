zfsowner
========

Set of scripts to mount zfs filesystems as users to support delegated administration

Scripts
-------
*	useradd.sh

	Install in /usr/local/sbin or your prefered location and
	customize as required.

	Simple script to add a user with a ZFS home directory and a
	second delegated ZFS storage location subject to user control.

*	zfsowner
	
	Install in /usr/local/etc/rc.d to remount user owned mount
	points as the user at boot.  Such mountpoints are marketed by
	the freebsd.org:owner attribute.

*	zfs-update-exports

	Install in /usr/local/bin and add an entry to sudoers like

	> ALL ALL=(root) NOPASSWD: /usr/local/bin/zfs-update-exports

	to allow users to force a refers of exports after altering their
	delegated share setttings.
