#!/usr/bin/env bash
set -euo pipefail

TOPO="${1:-ml-clab-topo.yml}"
LAB_NAME="arista-evpn-vxlan-lab"

FABRIC_NODES="spine1,spine2,leaf1,leaf2,leaf3,leaf4"
MGMT_NODES="host1,host2,gnmic,prometheus,grafana,alloy,loki,redis,ntopng"

EVPN_CHECK_CONTAINERS=(
  "clab-${LAB_NAME}-spine1"
  "clab-${LAB_NAME}-spine2"
  "clab-${LAB_NAME}-leaf1"
  "clab-${LAB_NAME}-leaf2"
  "clab-${LAB_NAME}-leaf3"
  "clab-${LAB_NAME}-leaf4"
)

MAX_WAIT=300
POLL_INT=10

# ---- Colors (disable with NO_COLOR=1) ----
if [[ "${NO_COLOR:-0}" == "1" ]] || [[ ! -t 1 ]]; then
  C_RESET=""; C_RED=""; C_GREEN=""; C_YELLOW=""; C_CYAN=""; C_DIM=""; C_BOLD=""
else
  C_RESET=$'\033[0m'
  C_RED=$'\033[31m'
  C_GREEN=$'\033[32m'
  C_YELLOW=$'\033[33m'
  C_CYAN=$'\033[36m'
  C_DIM=$'\033[2m'
  C_BOLD=$'\033[1m'
fi

ts() { date +"%Y-%m-%d %H:%M:%S"; }

status_tag() {
  local s="$1"
  case "$s" in
    READY) printf "%sREADY%s" "${C_GREEN}${C_BOLD}" "${C_RESET}" ;;
    WAIT)  printf "%sWAIT%s"  "${C_YELLOW}${C_BOLD}" "${C_RESET}" ;;
    *)     printf "%s" "$s" ;;
  esac
}

# EVPN neighbor rows: neighbor IP in column 2, state in column 9
evpn_totals() {
  local c="$1"
  docker exec "$c" Cli -c "show bgp evpn summary" 2>/dev/null | awk '
    $2 ~ /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$/ {
      total++
      if ($9 != "Estab") bad++
    }
    END { printf "%d %d\n", total+0, bad+0 }
  '
}

# Build ASCII progress bar
render_bar() {
  local ready="$1" total="$2" elapsed="$3" maxwait="$4"
  local width=36
  local pct=0

  if (( total > 0 )); then
    pct=$(( ready * 100 / total ))
  fi

  local filled=$(( pct * width / 100 ))
  local empty=$(( width - filled ))

  local bar=""
  for ((i=0;i<filled;i++)); do bar+="#"; done
  for ((i=0;i<empty;i++)); do bar+="-"; done

  printf "%s[%s]%s %s%3d%%%s  %s%d/%d READY%s  %s(elapsed %ss / timeout %ss)%s" \
    "${C_CYAN}${C_BOLD}" "$bar" "${C_RESET}" \
    "${C_BOLD}" "$pct" "${C_RESET}" \
    "${C_BOLD}" "$ready" "$total" "${C_RESET}" \
    "${C_DIM}" "$elapsed" "$maxwait" "${C_RESET}"
}

# Clear line + print in-place status
print_status_line() {
  # \r return + ANSI clear entire line
  printf "\r\033[2K%s" "$1"
}

# Spinner/progress between polls (cannot kill script if rendering fails)
spinner_wait() {
  local seconds="$1" ready="$2" total="$3" start_elapsed="$4" maxwait="$5"
  local frames=( "|" "/" "-" "\\" )
  local i=0

  # Disable "exit on error" inside the spinner to avoid accidental exits
  set +e
  for ((s=seconds; s>0; s--)); do
    local shown_elapsed=$(( start_elapsed + (seconds - s) ))
    local bar
    bar="$(render_bar "$ready" "$total" "$shown_elapsed" "$maxwait" 2>/dev/null)"
    local spin="${frames[i % 4]}"
    print_status_line "${bar}  ${C_DIM}${spin} next poll in ${s}s${C_RESET}"
    ((i++))
    sleep 1
  done
  print_status_line ""
  echo
  set -e
}

echo
echo "${C_CYAN}${C_BOLD}============================================================${C_RESET}"
echo "${C_CYAN}${C_BOLD}[$(ts)] STAGED CONTAINERLAB DEPLOY${C_RESET}"
echo "${C_DIM}[$(ts)] Topology : ${TOPO}${C_RESET}"
echo "${C_DIM}[$(ts)] Lab name : ${LAB_NAME}${C_RESET}"
echo "${C_CYAN}${C_BOLD}============================================================${C_RESET}"
echo

echo "${C_CYAN}${C_BOLD}[$(ts)] ▶ Stage 1: Deploying fabric nodes${C_RESET}"
echo "${C_DIM}[$(ts)]   Nodes: ${FABRIC_NODES}${C_RESET}"
clab deploy -t "${TOPO}" --node-filter "${FABRIC_NODES}"

echo
echo "${C_CYAN}${C_BOLD}[$(ts)] ▶ Waiting for EVPN BGP to establish${C_RESET}"
echo "${C_DIM}[$(ts)]   Condition: all EVPN neighbors in state 'Estab'${C_RESET}"
echo "${C_DIM}[$(ts)]   Poll every: ${POLL_INT}s | Timeout: ${MAX_WAIT}s${C_RESET}"
echo

START_TS=$(date +%s)
ITER=1
TOTAL_DEVICES="${#EVPN_CHECK_CONTAINERS[@]}"

while true; do
  NOW=$(date +%s)
  ELAPSED=$(( NOW - START_TS ))

  READY_DEVICES=0
  ALL_READY=true

  echo "${C_CYAN}${C_BOLD}[$(ts)] ── Poll #${ITER}${C_RESET}"
  printf "    %-45s %-10s %-20s\n" "NODE" "STATUS" "DETAILS"
  printf "    %-45s %-10s %-20s\n" "----" "------" "-------"

  for c in "${EVPN_CHECK_CONTAINERS[@]}"; do
    if ! docker ps --format '{{.Names}}' | grep -qx "$c"; then
      printf "    %-45s %-10b %-20s\n" "$c" "$(status_tag WAIT)" "container not running"
      ALL_READY=false
      continue
    fi

    read -r TOTAL BAD < <(evpn_totals "$c" || echo "0 999")

    if [[ "$TOTAL" -lt 1 ]]; then
      printf "    %-45s %-10b %-20s\n" "$c" "$(status_tag WAIT)" "no EVPN neighbors"
      ALL_READY=false
    elif [[ "$BAD" -gt 0 ]]; then
      printf "    %-45s %-10b %-20s\n" "$c" "$(status_tag WAIT)" "$BAD/$TOTAL not Estab"
      ALL_READY=false
    else
      printf "    %-45s %-10b %-20s\n" "$c" "$(status_tag READY)" "$TOTAL neighbors"
      ((READY_DEVICES++))
    fi
  done

  echo
  echo "    $(render_bar "$READY_DEVICES" "$TOTAL_DEVICES" "$ELAPSED" "$MAX_WAIT")"
  echo

  if $ALL_READY; then
    echo "${C_GREEN}${C_BOLD}[$(ts)] ✔ EVPN BGP established across all fabric nodes${C_RESET}"
    break
  fi

  if (( ELAPSED >= MAX_WAIT )); then
    echo "${C_RED}${C_BOLD}[$(ts)] ⚠ TIMEOUT reached (${MAX_WAIT}s)${C_RESET}"
    echo "${C_YELLOW}${C_BOLD}[$(ts)]   Proceeding with management stack deploy anyway${C_RESET}"
    break
  fi

  spinner_wait "$POLL_INT" "$READY_DEVICES" "$TOTAL_DEVICES" "$ELAPSED" "$MAX_WAIT"
  ((ITER++))
done

echo
echo "${C_CYAN}${C_BOLD}[$(ts)] ▶ Stage 2: Deploying hosts + management stack${C_RESET}"
echo "${C_DIM}[$(ts)]   Nodes: ${MGMT_NODES}${C_RESET}"
clab deploy -t "${TOPO}" --node-filter "${MGMT_NODES}"

echo
echo "${C_CYAN}${C_BOLD}============================================================${C_RESET}"
echo "${C_GREEN}${C_BOLD}[$(ts)] ✔ STAGED DEPLOY COMPLETE${C_RESET}"
echo "${C_CYAN}${C_BOLD}============================================================${C_RESET}"
echo
