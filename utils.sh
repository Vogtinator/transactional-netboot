# Meant to be sourced into other .sh files

# Prepare a mountpoint of a snapshot to chroot into
function prepare_chroot {
	mountpoint="$(mktemp -d)"
	mount --bind --make-private "$1" "${mountpoint}"

	mount -t devtmpfs devtmpfs "${mountpoint}/dev"
	mount -t sysfs sysfs "${mountpoint}/sys"
	mount -t proc proc "${mountpoint}/proc"
	mount -t tmpfs tmpfs  "${mountpoint}/run"
	mount -t tmpfs tmpfs  "${mountpoint}/tmp"

	mount --bind "$1/../../../.snapshots" "${mountpoint}/.snapshots"

	echo "${mountpoint}"
}

# Cleanup a mountpoint prepared by prepare_chroot
function cleanup_chroot {
	umount $1/{tmp,run,proc,sys,dev,.snapshots,} 2>/dev/null
	rmdir $1
}
