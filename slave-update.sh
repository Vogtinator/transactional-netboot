#!/bin/bash

root="/srv/slave"

. "$(dirname "$0")/utils.sh"

# Create a new RW snapshot
old_subvol="$(readlink "${root}/current-snapshot")"
snapshot_mount="$(prepare_chroot "${root}/${old_subvol}")" || exit 1

new_snapshot_id="$(chroot "${snapshot_mount}" snapper --no-dbus create -t single -p)"
new_subvol=".snapshots/${new_snapshot_id}/snapshot"

cleanup_chroot "${snapshot_mount}"

# Make it read-writable
btrfs property set "${root}/${new_subvol}" ro false

# Chroot to it
snapshot_mount="$(prepare_chroot "${root}/${new_subvol}")"

PS1='slave:\w # ' chroot "${snapshot_mount}" $@
ret=$?

if [ $ret == 0 ]; then
	# Generate new PXE grub image
	chroot "${snapshot_mount}" grub2-mkimage -O i386-pc-pxe -o /boot/grub.pxe -p "(tftp)" pxe tftp
	ret=$?
fi

cleanup_chroot "${snapshot_mount}"

if [ $ret != 0 ]; then
	echo "Operation failed - deleting snapshot"
	btrfs subvolume delete "${root}/.snapshots/${new_snapshot_id}/snapshot"
	rm -rf "${root}/.snapshots/${new_snapshot_id}"
else
	# Make sure it's read-only
	btrfs property set "${root}/${new_subvol}" ro true

	echo "set snapshot_root=/$new_subvol" > "${root}/snapshot.cfg"
        ln -sfT "${new_subvol}" "${root}/current-snapshot"

	echo "Active snapshot is now ${new_subvol}"
fi

exit $ret
