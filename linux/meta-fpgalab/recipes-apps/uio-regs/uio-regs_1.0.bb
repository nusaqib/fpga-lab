SUMMARY = "UIO userspace driver for the curriculum's axil_regs peripheral"
DESCRIPTION = "Module 17's uio_regs, built from its single source of \
truth in curriculum/17_device_trees_and_drivers/src/ - the layer lives \
inside the repo, so FILESEXTRAPATHS can reach across to it instead of \
keeping a drifting copy here."
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

FILESEXTRAPATHS:prepend := "${THISDIR}/../../../../curriculum/17_device_trees_and_drivers/src:"
SRC_URI = "file://uio_regs.c"

S = "${WORKDIR}"

do_compile() {
    ${CC} ${CFLAGS} ${LDFLAGS} -o uio_regs uio_regs.c
}

do_install() {
    install -D -m 0755 ${S}/uio_regs ${D}${bindir}/uio_regs
}
