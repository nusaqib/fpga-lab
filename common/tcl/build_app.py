# Generic Vitis (2026.1 unified, Python interface) bare-metal app build,
# shared by every Zynq/RFSoC software module. XSCT is disabled in 2026.1 -
# this is the scripted path now (UG1400).
#
# Usage: vitis -s build_app.py <workspace> <app_name> <xsa> <cpu> <src_dir>
#   cpu: ps7_cortexa9_0 (BlackBoard) | psu_cortexa53_0 (RFSoC4x2)
#
# Strategy notes:
#  - The platform (BSP) is regenerated from the XSA every time - it is a
#    build artifact, never edited by hand.
#  - The app component is created from the known-good hello_world template,
#    then the template source is replaced with the module's src/ files
#    (deterministic across releases; template ids for "empty" apps have
#    moved around between versions, hello_world has not).

import os
import shutil
import sys

import vitis

ws, app_name, xsa, cpu, src_dir = sys.argv[1:6]
ws = os.path.abspath(ws)
xsa = os.path.abspath(xsa)
src_dir = os.path.abspath(src_dir)
plat_name = f"{app_name}_plat"
domain = f"standalone_{cpu}"

# Fresh workspace each run - it lives under _out/, fully disposable.
if os.path.isdir(ws):
    shutil.rmtree(ws)

client = vitis.create_client(workspace=ws)

plat = client.create_platform_component(
    name=plat_name, hw_design=xsa, os="standalone", cpu=cpu)
plat.build()
xpfm = os.path.join(ws, plat_name, "export", plat_name, f"{plat_name}.xpfm")

app = client.create_app_component(
    name=app_name, platform=xpfm, domain=domain, template="hello_world")

# Swap template sources for the module's own (keep lscript.ld and the
# generated platform glue). Two places must agree: the files on disk AND
# the USER_COMPILE_SOURCES list in UserConfig.cmake - the generated
# CMakeLists compiles exactly what that list names, so deleting
# helloworld.c without updating it fails at add_executable with no
# sources (found out the hard way).
app_src = os.path.join(ws, app_name, "src")
os.remove(os.path.join(app_src, "helloworld.c"))
ours = []
for f in sorted(os.listdir(src_dir)):
    if f.endswith((".c", ".h")):
        shutil.copy2(os.path.join(src_dir, f), app_src)
        if f.endswith(".c"):
            ours.append(f)

ucfg_path = os.path.join(app_src, "UserConfig.cmake")
with open(ucfg_path) as fh:
    ucfg = fh.read()
src_list = "\n".join(f'"{f}"' for f in ours + ["platform.c"])
import re
ucfg, n = re.subn(r"set\(USER_COMPILE_SOURCES.*?\)",
                  f"set(USER_COMPILE_SOURCES\n{src_list}\n)",
                  ucfg, count=1, flags=re.DOTALL)
if n != 1:
    raise SystemExit("ERROR: USER_COMPILE_SOURCES block not found in UserConfig.cmake")
with open(ucfg_path, "w") as fh:
    fh.write(ucfg)

app.build()

elf = os.path.join(ws, app_name, "build", f"{app_name}.elf")
if not os.path.isfile(elf):
    raise SystemExit(f"ERROR: expected ELF not found: {elf}")
print(f"ELF OK: {elf}")
