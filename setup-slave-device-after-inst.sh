#!/bin/bash

. "$(dirname "$0")/utils.sh"

# dhcpd conf:

#filename "/@/grub.pxe";
#if substring (option vendor-class-identifier, 15, 5) = "00007" {
#  filename "/@/shim.efi";
#}

mountpoint=/srv/slave
subvol=.snapshots/1/snapshot

snapshot_mount="$(prepare_chroot "${mountpoint}/${subvol}")"

# Create a default snapper config
cp ${snapshot_mount}/etc/snapper/{config-templates/default,configs/root}
chroot "${snapshot_mount}" snapper --no-dbus set-config NUMBER_CLEANUP=no TIMELINE_CREATE=no BACKGROUND_COMPARISON=no

cleanup_chroot "${snapshot_mount}"

btrfs property set ${mountpoint}/${subvol} ro true

cat >${mountpoint}/grub.cfg <<EOF
# Get the path of the loaded image
eval "set net_default_boot_file=\$net_${net_default_interface}_boot_file"
regexp -s root_path (.+/)[^/]+ $net_default_boot_file
# And export it, used as prefix for all loaded files
export root_path

source ${root_path}/snapshot.cfg
set prefix=(tftp)${root_path}${snapshot_root}/boot/grub2
source ${prefix}/grub.cfg
EOF

echo "Now run slave-update.sh once"
