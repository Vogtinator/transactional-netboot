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

ln -sfT current-snapshot/usr/lib64/efi/grub.efi ${mountpoint}/grub.efi
ln -sfT current-snapshot/usr/lib64/efi/shim.efi ${mountpoint}/shim.efi
ln -sfT current-snapshot/usr/lib/grub2/i386-pc ${mountpoint}/i386-pc
ln -sfT current-snapshot/boot/grub.pxe ${mountpoint}/grub.pxe

cat >${mountpoint}/grub.cfg <<EOF
source /snapshot.cfg
set prefix=${prefix}/${snapshot_root}/usr/lib/grub2
source ${snapshot_root}/boot/grub2/grub.cfg
EOF
