#!/bin/bash

root="/srv/slave"

snapshot_mount="$(mktemp -d)"

# Create a new RW snapshot
old_subvol="$(readlink "${root}/current-snapshot")"

mount --bind --make-private "${root}/${old_subvol}" "${snapshot_mount}"

for i in dev sys proc; do
    mount --bind "/${i}" "${snapshot_mount}/${i}"
done
mount -t tmpfs tmpfs "${snapshot_mount}/run"
mount -t tmpfs tmpfs "${snapshot_mount}/tmp"
mount --bind "${root}/.snapshots" "${snapshot_mount}/.snapshots"

new_snapshot_id="$(chroot "${snapshot_mount}" snapper --no-dbus create -t single -p)"
new_subvol=".snapshots/${new_snapshot_id}/snapshot"

umount ${snapshot_mount}/{tmp,run,proc,sys,dev,.snapshots,}

# Chroot to it
mount --bind --make-private "${root}/${new_subvol}" "${snapshot_mount}"

for i in dev sys proc; do
    mount --bind "/${i}" "${snapshot_mount}/${i}"
done
mount -t tmpfs tmpfs "${snapshot_mount}/run"
mount -t tmpfs tmpfs "${snapshot_mount}/tmp"
mount --bind "${root}/.snapshots" "${snapshot_mount}/.snapshots"

PS1='slave:\w # ' chroot "${snapshot_mount}" $@
ret=$?

if [ $ret == 0 ]; then
	# Generate new PXE grub image
	chroot "${snapshot_mount}" grub2-mkimage -O i386-pc-pxe -o /boot/grub.pxe -p "(tftp)" pxe tftp
	ret=$?
fi

umount ${snapshot_mount}/{tmp,run,proc,sys,dev,.snapshots,}
rmdir ${snapshot_mount}

if [ $ret != 0 ]; then
	echo "Operation failed - deleting snapshot"
	btrfs subvolume delete "${root}/.snapshots/${new_snapshot_id}/snapshot"
	rm -rf "${root}/.snapshots/${new_snapshot_id}"
else
	# Make sure it's read-only
	btrfs property set ${root}/${new_subvol} ro true

	echo "set snapshot_root=/$new_subvol" > ${root}/snapshot.cfg
        ln -sfT ${new_subvol} ${root}/current-snapshot

	echo "Active snapshot is now ${new_subvol}"
fi

exit $ret
