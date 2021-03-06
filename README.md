transactional-netboot
=====================

Set up the server
-----------------

1. Use any working Linux system with NFS and tftp servers. openSUSE Leap 15.0 and Tumbleweed are known to work.
2. Install transactional-netboot from obs://home:favogt:nfsroot/
3. Create a directory containing all minion systems, for instance /srv/minion. The directory needs to be on btrfs, with CoW enabled, but not part of snapper's snapshots. Create a ".install" subdirectory.
4. Edit /etc/sysconfig/tftp, set `TFTP_DIRECTORY="/srv/minion"`.  
  As long as the whole /srv/minion tree is accessible from NFS and tftp under the same path, you can choose to export a different path as well. This means you can also export parent directories or use bind mounts.
5. Adjust the values in `/etc/transactional-netboot.conf` as necessary.
6. Edit /etc/exports, export the directory as noted. Make sure that it is readable by all clients. Example:  
`/srv/minion 192.168.42.0/24(ro,async,no_subtree_check,no_root_squash,fsid=0)`. The `async,fsid=0` parameters are not necessary.  
Export the `.install` subdirectory as `rw,nohide,crossmnt`. Example:  
`/srv/minion/.install 192.168.42.0/24(rw,async,no_subtree_check,no_root_squash,nohide,crossmnt)`

Set up a minion
---------------

In this example, openSUSE Tumbleweed will be installed as "tumbleweed" minion.

Make sure that the DHCP server used for netbooting gives out IPs to the nodes.

1. Run `transactional-netboot tumbleweed --init`. It will give you a target path for the installation.
2. Boot one of the target systems with the Tumbleweed installation media.  
3. Proceed with the installation until the drive selection as usual. Ignore any warnings that no disks where discovered.
4. In the partitioning proposal, open the expert partitioner.
5. Add a new NFS mount with the local mountpoint `/` and as source hostname of the NFS server and the path `transactional-netboot` gave you.
6. Continue as usual, ignore any warnings related to booting or bootloader installation (boo#1090056)
7. After the installation is complete, run `transactional-netboot tumbleweed --setup`. If the install mountpoint is still busy, you might need to wait some time before trying again.
8. Include the file for dhcpd configuration given by `transactional-netboot` in your dhcpd configuration. If the DHCP server is running on a different server, copy it over. Set the `next-server` to the IP of the NFS/TFTP server.
9. Call `transactional-netboot tumbleweed` to open a shell in a new snapshot. In this shell you need to perform the initial configuration, explained in the next steps.
10. Edit /etc/sysconfig/bootloader, set `LOADER_TYPE="none"`.
11. Edit /etc/default/grub, set  
`GRUB_CMDLINE_LINUX_DEFAULT="rd.neednet=1 ip=dhcp"`
`GRUB_DISABLE_OS_PROBER="true"`  
`SUSE_NFS_SNAPSHOT_BOOTING="true"`  
`GRUB_DEVICE_BOOT="nfs"`  
`GRUB_FS="nfs"`
12. Write `use_fstab="yes"` into /etc/dracut.conf.d/42-nfsroot.conf
13. Follow either the guide for minions with volatile or persistent storage
14. Run `mkinitrd`
15. Leave the minion chroot with `exit`

Now you can boot the nodes using PXE.

Minion with volatile storage
----------------------------

A minion set up this way stores all changes in tmpfs.

1. Install read-only-root-fs-volatile, dracut and grub2 from obs://home:favogt:nfsroot
2. Install kernel-default from obs://home:favogt:overlay/standard

Advanced configuration: /home on overlay
----------------------------------------

1. Go into the minion chroot: `transactional-netboot tumbleweed`
2. Create `/etc/systemd/system/tmp-overlay@.service` with this content:

```
[Unit]
Description=Directories for overlay mounting of %I
Requires=tmp.mount
After=tmp.mount

[Service]
Type=simple
ExecStart=/usr/bin/mkdir -p /tmp/%I-upper /tmp/%I-work
```

3. Append a mountpoint for `/home` to `/etc/fstab`:  
`overlay /home overlay defaults,upperdir=/tmp/home-upper,workdir=/tmp/home-work,lowerdir=/home,x-systemd.requires=tmp-overlay@home.service 0 0`
4. Exit the chroot: `exit`

You can use the same mechanism for e.g. `/root` by adding a line in `/etc/fstab`.

Minion with persistent storage
------------------------------

A minion with persistent storage has /var mounted from a local device.

1. Edit /etc/fstab, add entries for the minion's /var and /tmp:
```
/dev/vda1 /var ext4 defaults 0 0
tmpfs /tmp tmpfs defaults,nosuid,nodev 0 0
```
2. Install transactional-netboot-persistent and read-only-root-fs
3. Create /etc/transactional-netboot/create-varpart.sh (executable) which creates and copies over /var contents. Example:

```
#!/bin/bash

set -euo pipefail

PARTITION=/dev/vda1

if [ -e $PARTITION ]; then
        echo "Partition already there."
        return 0
fi

DISK=/dev/vda

cat <<EOF | fdisk $DISK
g
n
1


p
w
EOF

partprobe $DISK
mkfs.ext4 $PARTITION
mount $PARTITION /mnt
rsync -aAXH /var/ /mnt/
sync
umount /mnt
```

Minion with /home on a persistent overlay
-----------------------------------------

1. Go into the minion chroot: `transactional-netboot tumbleweed`
2. Create `/etc/systemd/system/var-overlay@.service` with this content:

```
[Unit]
Description=Directories for overlay mounting of %I
Requires=var.mount
After=var.mount

[Service]
Type=simple
ExecStart=/usr/bin/mkdir -p /var/lib/overlay/%I /var/lib/overlay/work-%I
```

3. Append a mountpoint for `/home` to `/etc/fstab`:  
`overlay /home overlay defaults,upperdir=/var/lib/overlay/home,workdir=/var/lib/overlay/work-home,lowerdir=/home,x-systemd.requires=var-overlay@home.service 0 0`
4. Exit the chroot: `exit`

You can use the same mechanism for e.g. `/root` by adding a line in `/etc/fstab`.
