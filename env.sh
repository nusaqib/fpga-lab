# Source this for interactive Vivado/Vitis use: `source env.sh`.
# The Makefile-driven flow does NOT need this - it sources settings64.sh
# itself per invocation (see common/mk/common.mk).
export FPGA_LAB_TOOLS_ROOT="/opt/tools/2026.1"
source "$FPGA_LAB_TOOLS_ROOT/Vivado/settings64.sh"

FPGA_LAB_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
export FPGA_LAB_ROOT
echo "fpga-lab: tools=$FPGA_LAB_TOOLS_ROOT root=$FPGA_LAB_ROOT"
