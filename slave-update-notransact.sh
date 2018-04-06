#!/bin/bash

root="/srv/slave"

snapshot_mount="$(mktemp -d)"

# Create a new RW snapshot
old_subvol="$(btrfs subvolume get-default "${root}" | cut -d' ' -f9-)"

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
# Make sure it's read-write
btrfs property set ${snapshot_mount} ro false

for i in dev sys proc; do
    mount --bind "/${i}" "${snapshot_mount}/${i}"
done
mount -t tmpfs tmpfs "${snapshot_mount}/run"
mount -t tmpfs tmpfs "${snapshot_mount}/tmp"
mount --bind "${root}/.snapshots" "${snapshot_mount}/.snapshots"

chroot "${snapshot_mount}" $@

# Make sure it's read-only
btrfs property set ${snapshot_mount} ro true

umount ${snapshot_mount}/{tmp,run,proc,sys,dev,.snapshots,}

rmdir ${snapshot_mount}

new_subvol_id=$(btrfs subvol list ${root} | awk "/\\/${new_snapshot_id}\\/snapshot/ { print \$2 }")
btrfs subvolume set-default ${new_subvol_id} ${root}

echo "set snapshot_root=/$new_subvol" > /srv/tftpboot/snapshot.cfg

exit $ret
