#!/usr/bin/env bash
# Re-fetch upstream board support files (master XDC, board_files, manuals)
# into a scratch dir and print copy commands. Run from the repo root:
#   scripts/fetch_vendor_files.sh [scratch_dir]
# then diff/copy the relevant pieces into boards/<board>/ by hand - this is
# deliberately not fully automatic, so a bad upstream change can't silently
# clobber reviewed constraint files.
set -euo pipefail

SCRATCH="${1:-/tmp/fpga-lab-vendor-fetch}"
mkdir -p "$SCRATCH"
cd "$SCRATCH"

clone() {
  local url="$1" dir="$2"
  if [ -d "$dir" ]; then
    echo "== $dir already present, skipping clone (rm -rf to refresh) =="
  else
    echo "== cloning $url =="
    git clone --depth 1 "$url" "$dir"
  fi
}

clone https://github.com/Digilent/digilent-xdc.git digilent-xdc
clone https://github.com/Digilent/vivado-boards.git vivado-boards
clone https://github.com/RealDigitalOrg/RFSoC4x2-BSP.git RFSoC4x2-BSP
clone https://github.com/RealDigitalOrg/linux-blackboard.git linux-blackboard
clone https://github.com/Xilinx/RFSoC-PYNQ.git RFSoC-PYNQ

echo
echo "Fetched into: $SCRATCH"
echo
cat <<'EOF'
Relevant copy commands (adjust REPO to your checkout path):

REPO=/home/nusaqib/gitsrc/embed/fpga-lab

# Nexys4
cp "$SCRATCH/digilent-xdc/Nexys-4-Master.xdc" "$REPO/boards/nexys4/xdc/"
cp -r "$SCRATCH/vivado-boards/new/board_files/nexys4/B.1" "$REPO/boards/nexys4/board_files/nexys4/"

# RFSoC4x2
cp "$SCRATCH/RFSoC4x2-BSP/hw/constraints/"*.xdc "$REPO/boards/rfsoc4x2/xdc/"
cp -r "$SCRATCH/RFSoC4x2-BSP/board_files/rfsoc4x2/1.0" "$REPO/boards/rfsoc4x2/board_files/rfsoc4x2/"
# RF clock chip (LMK04828 + LMX2594) TICS register dumps, from the official
# PYNQ board repo - these are what the PYNQ image itself programs at boot.
cp "$SCRATCH/RFSoC-PYNQ/boards/RFSoC4x2/petalinux_bsp/meta-user/recipes-apps/xrfclk-tics/files/LMK04828_245.76.txt" \
   "$SCRATCH/RFSoC-PYNQ/boards/RFSoC4x2/petalinux_bsp/meta-user/recipes-apps/xrfclk-tics/files/LMX2594_491.52.txt" \
   "$REPO/boards/rfsoc4x2/rfclk/"

# BlackBoard (Rev. D)
cp "$SCRATCH/linux-blackboard/hw/blackboard_revd.xdc" "$REPO/boards/blackboard/xdc/BlackBoard-RevD-Master.xdc"
cp -r "$SCRATCH/linux-blackboard/board_files/rev_d" "$REPO/boards/blackboard/board_files/blackboard_d/1.2"
curl -sLo "$REPO/boards/blackboard/docs/BlackBoard_revD_Schematic.pdf" \
  https://www.realdigital.org/downloads/bfea4bfc8ec2d05539fc8e2fa9cd66aa.pdf
curl -sLo "$REPO/boards/blackboard/docs/BlackBoard_ProgrammersReference.pdf" \
  https://www.realdigital.org/downloads/c1ed80391d2b0e12abd70e08b1c7c7ab.pdf
EOF
