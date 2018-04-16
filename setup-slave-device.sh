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
  <date>$(date +"%F %T")</date>
  <description>Initial installation</description>
</snapshot>
EOF

echo "Now install into nfs, <ip>:/<prefix>/.snapshots/1/snapshot"

