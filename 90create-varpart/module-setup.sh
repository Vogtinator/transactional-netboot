#!/bin/bash

# called by dracut
check() {
    return 0
}

# called by dracut
depends() {
    echo rootfs-block
    return 0
}

# called by dracut
install() {
    inst chroot findmnt
    inst_hook pre-pivot 00 "${moddir}/create-var.sh"
}
