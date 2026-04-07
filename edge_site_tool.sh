#!/usr/bin/env bash
set -u

CONFIG_FILE="$HOME/.edge_site_tool.conf"
MERGE_SCRIPT_NAME="merge_site_inventory.py"
REMOTE_USER="$USER"

# Colors
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# -----------------------------
# Helpers
# -----------------------------
pause() {
  read -rp "Press Enter to continue..."
}

warn() {
  echo
  echo "============================================================"
  echo "$1"
  echo "============================================================"
  echo
}

need_sudo() {
  if ! sudo -n true 2>/dev/null; then
    warn "This script uses sudo. You may be prompted for your password."
    sudo -v || exit 1
  fi
}

save_config() {
  cat > "$CONFIG_FILE" <<EOF
MACHINE_NAME="$MACHINE_NAME"
SITE_ID="$SITE_ID"
LOCAL_SUBNET_BASE="$LOCAL_SUBNET_BASE"
MAPPED_SUBNET="$MAPPED_SUBNET"
LOCAL_CIDR="$LOCAL_CIDR"
OUTPUT_XLSX="$OUTPUT_XLSX"
ARP_FILE="$ARP_FILE"
NMAP_XML="$NMAP_XML"
EOF
}

load_config() {
  if [[ -f "$CONFIG_FILE" ]]; then
    # shellcheck disable=SC1090
    source "$CONFIG_FILE"
    return 0
  fi
  return 1
}

show_current_config() {
  echo
  echo "Current config:"
  echo "  Machine name      : ${MACHINE_NAME:-<not set>}"
  echo "  Site ID           : ${SITE_ID:-<not set>}"
  echo "  Local subnet base : ${LOCAL_SUBNET_BASE:-<not set>}"
  echo "  Local CIDR        : ${LOCAL_CIDR:-<not set>}"
  echo "  Mapped subnet     : ${MAPPED_SUBNET:-<not set>}"
  echo "  ARP file          : ${ARP_FILE:-<not set>}"
  echo "  Nmap XML          : ${NMAP_XML:-<not set>}"
  echo "  Output XLSX       : ${OUTPUT_XLSX:-<not set>}"
  echo
}

detect_local_subnet_base() {
  local detected_ip=""
  detected_ip="$(ip -4 route get 1.1.1.1 2>/dev/null | awk '
    {
      for (i=1; i<=NF; i++) {
        if ($i == "src") {
          print $(i+1)
          exit
        }
      }
    }'
  )"

  if [[ -z "$detected_ip" ]]; then
    detected_ip="$(hostname -I 2>/dev/null | awk '{print $1}')"
  fi

  if [[ "$detected_ip" =~ ^([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})$ ]]; then
    echo "${BASH_REMATCH[1]}.${BASH_REMATCH[2]}.${BASH_REMATCH[3]}.0"
    return 0
  fi

  return 1
}

prompt_for_local_subnet_base() {
  local detected=""
  local use_detected=""
  detected="$(detect_local_subnet_base || true)"

  if [[ -n "$detected" ]]; then
    echo
    echo "Detected local subnet base: ${detected}"
    read -rp "Use this? (Y/n): " use_detected
    if [[ -z "$use_detected" || "${use_detected,,}" == "y" || "${use_detected,,}" == "yes" ]]; then
      LOCAL_SUBNET_BASE="$detected"
      return 0
    fi
  fi

  read -rp "Enter local subnet base (example: 192.168.0.0 or 10.10.10.0): " LOCAL_SUBNET_BASE
}

prompt_for_site_info() {
  echo
  read -rp "Enter machine name (example: pintail-ctb): " MACHINE_NAME
  read -rp "Enter site ID (3rd octet for mapped subnet, example: 20): " SITE_ID
  prompt_for_local_subnet_base

  if [[ -z "$MACHINE_NAME" || -z "$SITE_ID" || -z "$LOCAL_SUBNET_BASE" ]]; then
    warn "Machine name, site ID, and local subnet base are all required."
    return 1
  fi

  if ! [[ "$SITE_ID" =~ ^[0-9]{1,3}$ ]] || (( SITE_ID < 0 || SITE_ID > 255 )); then
    warn "Site ID must be a number from 0 to 255."
    return 1
  fi

  if ! [[ "$LOCAL_SUBNET_BASE" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
    warn "Local subnet base must look like 192.168.0.0"
    return 1
  fi

  MAPPED_SUBNET="10.200.${SITE_ID}.0/24"
  LOCAL_CIDR="${LOCAL_SUBNET_BASE}/24"
  ARP_FILE="${MACHINE_NAME}_devices.txt"
  NMAP_XML="${MACHINE_NAME}_services.xml"
  OUTPUT_XLSX="${MACHINE_NAME}_inventory.xlsx"

  save_config
  show_current_config
  return 0
}

ensure_config() {
  if ! load_config; then
    warn "No saved config found yet. Enter the site information now."
    prompt_for_site_info || return 1
  fi
  return 0
}

print_laptop_push_command() {
  ensure_config || return 1
  echo
  echo "Run this on your LAPTOP to copy the merge script to this edge computer:"
  echo
  echo "scp ${MERGE_SCRIPT_NAME} ${REMOTE_USER}@${MACHINE_NAME}:/home/${REMOTE_USER}/"
  echo
}

print_laptop_pull_command() {
  ensure_config || return 1
  echo
  echo "Run this on your LAPTOP to copy the finished spreadsheet back:"
  echo
  echo "scp ${REMOTE_USER}@${MACHINE_NAME}:/home/${REMOTE_USER}/${OUTPUT_XLSX} ."
  echo
}

show_auth_url_hint() {
  echo
  echo "If Tailscale prints a login/auth URL, copy it into your browser."
  echo "After the machine is added to Tailscale, come back here and press Enter."
  echo
}

show_route_approval_hint() {
  echo
  echo "Approve the advertised subnet route in the Tailscale admin console."
  echo "Mapped subnet to approve: ${MAPPED_SUBNET}"
  echo
  echo "After route approval is complete, come back here and press Enter."
  echo
}

# -----------------------------
# Option 1 - First-time setup
# -----------------------------
first_time_setup() {
  need_sudo
  prompt_for_site_info || return 1

  warn "Step 1: update / upgrade"
  sudo apt-get update && sudo apt-get upgrade -y || return 1

  warn "Step 2: install Tailscale"
  curl -fsSL https://tailscale.com/install.sh | sh || return 1

  warn "Step 3: bring Tailscale up"
  echo
  echo "Running: sudo tailscale up"
  echo
  show_auth_url_hint
  sudo tailscale up
  echo
  read -rp "Confirm the machine has been added to Tailscale (y/n): " ans
  [[ "${ans,,}" == "y" ]] || { warn "Stopping until Tailscale auth is completed."; return 1; }

  warn "Step 4: enable IP forwarding"
  sudo sed -i '/^net.ipv4.ip_forward *= */d' /etc/sysctl.conf
  sudo sed -i '/^net.ipv6.conf.all.forwarding *= */d' /etc/sysctl.conf
  echo 'net.ipv4.ip_forward = 1' | sudo tee -a /etc/sysctl.conf >/dev/null
  echo 'net.ipv6.conf.all.forwarding = 1' | sudo tee -a /etc/sysctl.conf >/dev/null
  sudo sysctl -p || return 1

  warn "Step 5: advertise mapped subnet route"
  echo
  echo "Running: sudo tailscale up --advertise-routes=${MAPPED_SUBNET}"
  echo
  sudo tailscale up --advertise-routes="${MAPPED_SUBNET}" || return 1
  show_route_approval_hint
  read -rp "Confirm the subnet route has been approved in Tailscale (y/n): " ans
  [[ "${ans,,}" == "y" ]] || { warn "Stopping until route approval is completed."; return 1; }

  warn "Step 6: install firewall persistence + scan/python tools"
  sudo apt-get update && sudo apt-get install -y \
    iptables-persistent \
    python3 \
    python3-openpyxl \
    nmap \
    arp-scan || return 1

  warn "Step 7: add NETMAP rules"
  sudo iptables -t nat -D PREROUTING -i tailscale0 -d "${MAPPED_SUBNET}" -j NETMAP --to "${LOCAL_SUBNET_BASE}/24" 2>/dev/null || true
  sudo iptables -t nat -D POSTROUTING -o tailscale0 -s "${LOCAL_SUBNET_BASE}/24" -j NETMAP --to "${MAPPED_SUBNET}" 2>/dev/null || true

  sudo iptables -t nat -A PREROUTING -i tailscale0 -d "${MAPPED_SUBNET}" -j NETMAP --to "${LOCAL_SUBNET_BASE}/24" || return 1
  sudo iptables -t nat -A POSTROUTING -o tailscale0 -s "${LOCAL_SUBNET_BASE}/24" -j NETMAP --to "${MAPPED_SUBNET}" || return 1
  sudo netfilter-persistent save || return 1

  warn "Step 8: prep arp-scan vendor files"
  sudo touch /usr/share/arp-scan/mac-vendor.txt
  sudo chmod 644 /usr/share/arp-scan/ieee-oui.txt /usr/share/arp-scan/mac-vendor.txt || true

  warn "Setup complete. Verification output below."
  show_status
}

# -----------------------------
# Option 2/3 - scans + merge
# -----------------------------
run_arp_scan() {
  warn "Running arp-scan"
  echo "Output file: ${ARP_FILE}"
  echo
  sudo arp-scan --localnet \
    --ouifile=/usr/share/arp-scan/ieee-oui.txt \
    --macfile=/usr/share/arp-scan/mac-vendor.txt \
    | tee "${ARP_FILE}"
}

run_nmap_scan() {
  warn "Running nmap service scan"
  echo "Target: ${LOCAL_CIDR}"
  echo "Output file: ${NMAP_XML}"
  echo
  sudo nmap -sS -sV --stats-every 10s "${LOCAL_CIDR}" -oX "${NMAP_XML}"
}

run_merge() {
  warn "Running merge script"
  if [[ ! -f "/home/${REMOTE_USER}/${MERGE_SCRIPT_NAME}" ]]; then
    warn "Merge script not found at /home/${REMOTE_USER}/${MERGE_SCRIPT_NAME}"
    print_laptop_push_command
    return 1
  fi

  cd "/home/${REMOTE_USER}" || return 1

  python3 "/home/${REMOTE_USER}/${MERGE_SCRIPT_NAME}" \
    "${MACHINE_NAME}" \
    "/home/${REMOTE_USER}/${ARP_FILE}" \
    "/home/${REMOTE_USER}/${NMAP_XML}" \
    --mapped-prefix "10.200.${SITE_ID}" || return 1

  if [[ -f "/home/${REMOTE_USER}/${OUTPUT_XLSX}" ]]; then
    echo
    echo "Spreadsheet created: /home/${REMOTE_USER}/${OUTPUT_XLSX}"
    return 0
  fi

  latest_xlsx="$(ls -1t /home/${REMOTE_USER}/*_inventory.xlsx 2>/dev/null | head -n 1 || true)"
  if [[ -n "${latest_xlsx}" && "${latest_xlsx}" != "/home/${REMOTE_USER}/${OUTPUT_XLSX}" ]]; then
    mv -f "${latest_xlsx}" "/home/${REMOTE_USER}/${OUTPUT_XLSX}"
    echo
    echo "Spreadsheet renamed to: /home/${REMOTE_USER}/${OUTPUT_XLSX}"
    return 0
  fi

  warn "Merge completed, but expected XLSX was not found."
  return 1
}

copy_merge_and_run_scans() {
  ensure_config || return 1

  print_laptop_push_command
  read -rp "Confirm the merge script has been copied to this machine (y/n): " ans
  [[ "${ans,,}" == "y" ]] || { warn "Stopping until merge script is copied."; return 1; }

  run_arp_scan || return 1
  run_nmap_scan || return 1
  run_merge || return 1

  print_laptop_pull_command
}

rerun_scans_only() {
  ensure_config || return 1
  run_arp_scan || return 1
  run_nmap_scan || return 1
  run_merge || return 1
  print_laptop_pull_command
}

# -----------------------------
# Option 4 - helper commands
# -----------------------------
show_helper_commands() {
  ensure_config || return 1
  show_current_config
  print_laptop_push_command
  print_laptop_pull_command
}

# -----------------------------
# Option 5 - status
# -----------------------------
show_status() {
  echo
  echo "================ STATUS / VERIFY ================"
  echo
  show_current_config

  echo "---- tailscale status ----"
  tailscale status || true
  echo

  echo "---- tailscale0 ----"
  ip addr show tailscale0 || true
  echo

  echo "---- ip route ----"
  ip route || true
  echo

  echo "---- iptables nat ----"
  sudo iptables -t nat -L -n -v || true
  echo

  echo "---- python version ----"
  python3 --version || true
  echo

  echo "---- merge script presence ----"
  if [[ -f "/home/${REMOTE_USER}/${MERGE_SCRIPT_NAME}" ]]; then
    echo "/home/${REMOTE_USER}/${MERGE_SCRIPT_NAME} found"
  else
    echo "/home/${REMOTE_USER}/${MERGE_SCRIPT_NAME} NOT found"
  fi
  echo
}

# -----------------------------
# Main menu
# -----------------------------
main_menu() {
  while true; do
    echo
    echo -e "${GREEN}============================================================${NC}"
    echo -e "${GREEN} Edge Site Tool${NC}"
    echo -e "${GREEN}============================================================${NC}"
    echo -e "${GREEN}1) First-time setup (update, tailscale, route, tools, netmap)${NC}"
    echo -e "${GREEN}2) Copy merge script + run scans + merge${NC}"
    echo -e "${GREEN}3) Re-run scans + merge only${NC}"
    echo -e "${GREEN}4) Show laptop helper commands${NC}"
    echo -e "${GREEN}5) Status / verify config${NC}"
    echo -e "${GREEN}6) Edit site info${NC}"
    echo -e "${GREEN}0) Exit${NC}"
    echo -e "${GREEN}============================================================${NC}"
    echo
    read -rp "Choose an option: " choice

    case "$choice" in
      1) first_time_setup ;;
      2) copy_merge_and_run_scans ;;
      3) rerun_scans_only ;;
      4) show_helper_commands ;;
      5) ensure_config && show_status ;;
      6) prompt_for_site_info ;;
      0) exit 0 ;;
      *) warn "Invalid option." ;;
    esac
  done
}

main_menu
