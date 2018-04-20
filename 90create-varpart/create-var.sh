#!/bin/bash

# Which device contains var?
partition="$(findmnt -F /sysroot/etc/fstab /var -no SOURCE)"

# Does it exist already?
[ -e $partition ] && return 0

# No, we need to create and fill it
for i in proc sys dev tmp; do
	mount --bind /$i /sysroot/$i
done

chroot /sysroot "/etc/transactional-netboot/create-varpart.sh"
ret=$?

umount /sysroot/{tmp,dev,sys,proc}

return $ret
