#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VIP_ROOT="${VIP_ROOT:-$(cd "${SCRIPT_DIR}/../.." && pwd)}"
CORE="akerlund::vip_axi4s_agent_example_py:0"

# FuseSoC/Edalize's generated Verilator makefile calls `cocotb-config`
# directly. Add the common Python script locations, but do not second-guess the
# user's active environment.
if [ -n "${VIRTUAL_ENV:-}" ] && [ -d "${VIRTUAL_ENV}/bin" ]; then
  export PATH="${VIRTUAL_ENV}/bin:$PATH"
fi
if [ -x "$HOME/.local/bin/cocotb-config" ]; then
  export PATH="$HOME/.local/bin:$PATH"
fi
if [ -d "$HOME/.local/bin" ]; then
  export PATH="$HOME/.local/bin:$PATH"
fi

# Prefer the user-built Verilator when present.
if [ -x "$HOME/.local/verilator/bin/verilator" ]; then
  export PATH="$HOME/.local/verilator/bin:$PATH"
fi

export VIP_ROOT
export PYTHONPATH="${SCRIPT_DIR}/tb:${SCRIPT_DIR}${PYTHONPATH:+:$PYTHONPATH}"

if [ "${DEBUG_RUN_FUSESOC:-0}" = "1" ]; then
  echo "Using PATH=${PATH}"
  echo "python=$(command -v python || true)"
  echo "python3=$(command -v python3 || true)"
  echo "pip=$(command -v pip || true)"
  echo "fusesoc=$(command -v fusesoc || true)"
  echo "verilator=$(command -v verilator || true)"
  echo "cocotb-config=$(command -v cocotb-config || true)"
fi

if ! command -v cocotb-config >/dev/null 2>&1; then
  echo "ERROR: cocotb-config is not on PATH." >&2
  echo "       Activate/install cocotb in the same environment used to run this script." >&2
  echo "       For example: python -m pip install cocotb" >&2
  exit 1
fi

COCOTB_LIB_DIR="$(cocotb-config --lib-dir)"
export LD_LIBRARY_PATH="${COCOTB_LIB_DIR}${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
COCOTB_PYTHON="$(cocotb-config --python-bin)"
if [ "${DEBUG_RUN_FUSESOC:-0}" = "1" ]; then
  echo "cocotb-lib-dir=${COCOTB_LIB_DIR}"
  echo "cocotb-python=${COCOTB_PYTHON}"
fi

if ! "${COCOTB_PYTHON}" -c 'import pyuvm' >/dev/null 2>&1; then
  echo "ERROR: pyuvm is not installed in cocotb's Python environment:" >&2
  echo "       ${COCOTB_PYTHON}" >&2
  echo "       Install it with:" >&2
  echo "       ${COCOTB_PYTHON} -m pip install --user pyuvm==4.0.1" >&2
  exit 1
fi

if [ "$#" -eq 0 ]; then
  fusesoc --cores-root "${VIP_ROOT}" run --target sim "$CORE"
else
  fusesoc --cores-root "${VIP_ROOT}" run "$@" "$CORE"
fi
