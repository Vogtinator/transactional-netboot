#!/bin/bash

mountpoint=/srv/slave
subvol=.snapshots/1/snapshot

for i in proc sys dev; do
	mount --bind /$i ${mountpoint}/${subvol}/$i
done

mount --bind --make-private ${mountpoint}/.snapshots ${mountpoint}/${subvol}/.snapshots

cp ${mountpoint}/${subvol}/etc/snapper/{config-templates/default,configs/root}
chroot ${mountpoint}/${subvol} snapper --no-dbus set-config NUMBER_CLEANUP=no TIMELINE_CREATE=no BACKGROUND_COMPARISON=no

umount ${mountpoint}/${subvol}/{.snapshots,proc,sys,dev}

btrfs property set ${mountpoint}/${subvol} ro true
