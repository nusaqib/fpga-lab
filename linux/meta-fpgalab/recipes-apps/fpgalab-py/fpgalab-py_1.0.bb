SUMMARY = "The curriculum's Python hardware tools (module 18)"
DESCRIPTION = "uio.py (UIO/devmem/device-tree helpers), blink.py, \
sdr_capture.py - installed side by side in ${bindir} so 'import uio' \
resolves via the script directory. Sources come straight from \
curriculum/18_linux_userspace_apps/py/ (see uio-regs for the idiom)."
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

FILESEXTRAPATHS:prepend := "${THISDIR}/../../../../curriculum/18_linux_userspace_apps/py:"
SRC_URI = "file://uio.py file://blink.py file://sdr_capture.py"

S = "${WORKDIR}"

RDEPENDS:${PN} = "python3"

do_install() {
    install -d ${D}${bindir}
    install -m 0644 ${S}/uio.py ${D}${bindir}/uio.py
    install -m 0755 ${S}/blink.py ${D}${bindir}/blink.py
    install -m 0755 ${S}/sdr_capture.py ${D}${bindir}/sdr_capture.py
}
