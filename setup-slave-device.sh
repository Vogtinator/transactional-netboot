#!/bin/bash

dev="$1"
mountpoint=/srv/slave

mkfs.btrfs -f $dev || exit 1

mount -o subvol=/ $dev $mountpoint
btrfs subvol create ${mountpoint}/@
btrfs subvol create ${mountpoint}/@/.snapshots
mkdir ${mountpoint}/@/.snapshots/1
btrfs subvol create ${mountpoint}/@/.snapshots/1/snapshot
mkdir ${mountpoint}/@/.snapshots/1/snapshot/.snapshots
umount $mountpoint

echo "$dev $mountpoint btrfs subvol=/@ 0 0" >> /etc/fstab
mount $mountpoint

cat > ${mountpoint}/.snapshots/1/info.xml <<EOF
<?xml version="1.0"?>
<snapshot>
  <type>single</type>
  <num>1</num>
  <date>now</date>
  <description>Initial installation</description>
</snapshot>
EOF

btrfs subvol set-default $(btrfs subvol list ${mountpoint} | awk '/snapshot$/ { print $2 }') ${mountpoint}

echo "${mountpoint}/.snapshots/1/snapshot *(rw,no_root_squash,no_subtree_check,async,fsid=0)" >> /etc/exports

exportfs -ra

echo "Now install into nfs"

