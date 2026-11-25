#!/usr/bin/env bash
# gen_mipscore.sh -- regenerate hdl/mipscore.v (the single Verilog file the
# ultra96v2-kodiak "axi_is_the_worst" IP synthesizes) from the Kodiak SoC RTL
# (rtl/*.sv: kodiak_soc and its devices) + the superdupersparc core (the
# superdupersparc submodule), via sv2v.
#
# Run after editing any rtl/ or superdupersparc/ .sv, then synth with
# ~/fpga/ultra96v2-kodiak/rebuild_kodiak.tcl (Vivado batch).
#
# Why a build dir: convert_sv_to_v.py globs *.sv in its CWD and sv2v must also
# see the headers (machine.vh/uop.vh/rob.vh), so we copy SoC + core sources AND
# headers into one dir. hdl/ is a symlink into the IP's hdl dir.
set -eu
ROOT="$(cd "$(dirname "$0")" && pwd)"

# --- keep the superdupersparc submodule current ---------------------------------------
# This script builds mipscore.v from the core SUBMODULE working tree. A stale
# submodule pointer once silently shipped an OLD core to the FPGA (an l2.sv
# missing the UNCACHE_WB_TURNAROUND AXI fix -> Linux boot hang) while the sim
# used a newer tree -- a textbook sim/synth divergence that took a day to find.
# So: fast-forward the submodule to origin/<branch> before building, where <branch>
# is .gitmodules submodule.superdupersparc.branch (default main; a kodiak feature
# branch can pin a core feature branch). Only a TRUE
# fast-forward is taken: a pinned commit that is not an ancestor of origin/<branch>
# is used as-is, never replaced. If it has local modifications, warn and use as-is
# (never clobber WIP). Override with KODIAK_NO_SUBMODULE_UPDATE=1. The submodule SHA
# is always echoed into the build.
SUB="$ROOT/superdupersparc"
SUB_BRANCH="$(git -C "$ROOT" config -f .gitmodules submodule.superdupersparc.branch 2>/dev/null || echo main)"
if [ -e "$SUB/.git" ]; then
  if [ "${KODIAK_NO_SUBMODULE_UPDATE:-0}" = "1" ]; then
    echo "[gen_mipscore] submodule update SKIPPED (KODIAK_NO_SUBMODULE_UPDATE=1)"
  elif ! git -C "$SUB" diff --quiet 2>/dev/null || ! git -C "$SUB" diff --cached --quiet 2>/dev/null; then
    echo "[gen_mipscore] WARNING: core submodule has LOCAL changes -- using as-is, NOT updating" >&2
  else
    git -C "$SUB" fetch -q origin 2>/dev/null || echo "[gen_mipscore] WARNING: submodule fetch failed (offline?) -- using current checkout" >&2
    if [ -n "$(git -C "$SUB" rev-list -n1 HEAD..origin/$SUB_BRANCH 2>/dev/null)" ]; then
      if git -C "$SUB" merge-base --is-ancestor HEAD "origin/$SUB_BRANCH" 2>/dev/null; then
        echo "[gen_mipscore] core submodule was BEHIND origin/$SUB_BRANCH -- fast-forwarding"
        git -C "$SUB" checkout -q "origin/$SUB_BRANCH"
      else
        echo "[gen_mipscore] WARNING: core submodule is NOT an ancestor of origin/$SUB_BRANCH -- using the pinned commit as-is" >&2
      fi
    fi
  fi
  echo "[gen_mipscore] core submodule @ $(git -C "$SUB" rev-parse --short HEAD 2>/dev/null) -- $(git -C "$SUB" log -1 --format=%s 2>/dev/null | cut -c1-60)"
fi

BUILD="${BUILD:-/tmp/kodiak_mipscore_build}"
rm -rf "$BUILD"; mkdir -p "$BUILD"

cp "$ROOT"/rtl/*.sv   "$BUILD"/ 2>/dev/null || true
cp "$ROOT"/rtl/*.vh   "$BUILD"/ 2>/dev/null || true
cp "$SUB"/*.sv "$BUILD"/ 2>/dev/null || true
cp "$SUB"/*.vh "$BUILD"/ 2>/dev/null || true
cp "$SUB"/convert_sv_to_v.py "$BUILD"/

echo "[gen_mipscore] $(ls "$BUILD"/*.sv | wc -l) .sv + $(ls "$BUILD"/*.vh 2>/dev/null | wc -l) .vh -> sv2v"

# Extra sv2v -D defines, injected at build time so the core submodule's
# machine.vh can stay == origin/main.  The Kodiak configuration (ROB, schedulers,
# L2 shape, L1D miss engines) is sv2v_defines in this directory: a build that
# dropped it ran CINT95 ~20% slower (2026-11-25).  The env overrides the file:
#   SV2V_DEFINES="$(cat sv2v_defines) ENABLE_DEBUG_WATCHPOINT" ./gen_mipscore.sh
: "${SV2V_DEFINES=$(cat "$ROOT/sv2v_defines" 2>/dev/null)}"
export SV2V_DEFINES
echo "[gen_mipscore] sv2v extra defines: ${SV2V_DEFINES:-<none>}"
( cd "$BUILD" && python3 convert_sv_to_v.py )

[ -s "$BUILD/mipscore.v" ] || { echo "[gen_mipscore] ERROR: empty mipscore.v (sv2v failed?)" >&2; exit 1; }
cp "$BUILD/mipscore.v" "$ROOT"/hdl/mipscore.v
echo "[gen_mipscore] wrote hdl/mipscore.v ($(wc -c < "$ROOT"/hdl/mipscore.v) bytes)"

# Copy the canonical AXI IP wrapper files (versioned here in ip_hdl/) into the
# IP's hdl dir alongside mipscore.v. Keeping our versions in-repo means the IP
# repo's hdl/ is pure build output (mipscore.v is gitignored there) and the axi
# wrapper edits (e.g. the SCC Rx path) live under version control we actually use.
cp "$ROOT"/ip_hdl/*.v "$ROOT"/hdl/
echo "[gen_mipscore] copied $(ls "$ROOT"/ip_hdl/*.v | wc -l) AXI IP wrapper file(s) ip_hdl/ -> hdl/"
echo "[gen_mipscore] modules: $(grep -oE 'module (kodiak_soc|slavio_misc|slavio_timer|slavio_intctl|ecc_memctl|sbus_iommu|core_l1d_l1i)' "$ROOT"/hdl/mipscore.v | sort -u | tr '\n' ' ')"
