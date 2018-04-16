#!/bin/bash

root="/srv/slave/@"

. "$(dirname "$0")/utils.sh"

# What's the current snapshot?
if [ -e "${root}/current-snapshot" ]; then
	old_subvol="$(readlink "${root}/current-snapshot")"
else
	old_subvol = ".snapshots/1/snapshot"
fi

# Create a new RW snapshot
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
	### TODO: How detect that this is necessary? ###

	# update-bootloader can't do this, so do it ourselves (todo: theme?)
	chroot "${snapshot_mount}" grub2-mknetdir --themes=openSUSE --net-directory / >/dev/null
	ret=$?
	# grub2-mknetdir sets a wrong prefix, so do it ourselves
	[ $ret == 0 ] && chroot "${snapshot_mount}" grub2-mkimage -O i386-pc-pxe -o /boot/grub2/i386-pc/grub.pxe -p "(tftp)" pxe tftp
	ret=$?
	# Config file regeneration has to be disabled, so do it ourselves as well
	[ $ret == 0 ] && chroot "${snapshot_mount}" grub2-mkconfig -o /boot/grub2/grub.cfg >/dev/null 2>&1
	ret=$?

	# Use the binaries from /usr/lib64/efi to keep the signature
	ln -sfT current-snapshot/usr/lib64/efi/grub.efi "${root}/grub.efi"
	ln -sfT current-snapshot/usr/lib64/efi/shim.efi "${root}/shim.efi"
	ln -sfT current-snapshot/usr/lib/grub2/i386-pc "${root}/i386-pc"
	ln -sfT current-snapshot/usr/lib/grub2/x86_64-efi "${root}/x86_64-efi"
	# Here we need a generated one
	ln -sfT current-snapshot/boot/grub.pxe "${root}/grub.pxe"
fi

cleanup_chroot "${snapshot_mount}"

if [ $ret != 0 ]; then
	echo "Operation failed - deleting snapshot"
	btrfs subvolume delete "${root}/.snapshots/${new_snapshot_id}/snapshot"
	rm -rf "${root}/.snapshots/${new_snapshot_id}"
else
	# Make sure it's read-only
	btrfs property set "${root}/${new_subvol}" ro true

	echo "set snapshot_root=/${new_subvol}" > "${root}/snapshot.cfg"
        ln -sfT "${new_subvol}" "${root}/current-snapshot"

	echo "Active snapshot is now ${new_subvol}"
fi

exit $ret
