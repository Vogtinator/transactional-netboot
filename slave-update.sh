#!/bin/bash

root="/srv/slave"

default_subvol="$(btrfs subvolume get-default "${root}" | cut -d' ' -f9-)"

snapshot="$(mktemp -d)"

mount --bind --make-private "${root}/${default_subvol}" "${snapshot}"

# Make sure it's read-only
#btrfs property set ${snapshot} ro true

for i in dev sys proc; do
    mount --bind "/${i}" "${snapshot}/${i}"
done

mount -t tmpfs tmpfs "${snapshot}/run"
mount -t tmpfs tmpfs "${snapshot}/tmp"

#mkdir -p /tmp/etcupper
#cp /etc/resolv.conf /tmp/etcupper
#mount -t overlay overlay -o "lowerdir=/tmp/etcupper:${snapshot}/etc" "${snapshot}/etc"

#for i in var opt home root; do 
#    mount -o bind "${root}/${i}" "${snapshot}/${i}"
#done

mount --bind "${root}/.snapshots" "${snapshot}/.snapshots"

(cd "${snapshot}"; chroot "${snapshot}" $@)
ret=$?

umount ${snapshot}/{.snapshots,etc,tmp,run,proc,sys,dev,}
#umount ${snapshot}/{.snapshots,root,home,opt,var,etc,tmp,run,proc,sys,dev,}

rm -rf /tmp/etcupper

rmdir ${snapshot}

default_subvol="$(btrfs subvolume get-default "${root}" | cut -d' ' -f9-)"

echo "set snapshot_root=/$default_subvol" > /srv/tftpboot/snapshot.cfg

exit $ret
