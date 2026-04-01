#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/.env"

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "Missing ${ENV_FILE}"
  echo "Create it from ${SCRIPT_DIR}/.env.example"
  exit 1
fi

set -a
source "${ENV_FILE}"
set +a

SERVER_DATA="${SERVER_DATA:-server_data}"
if [[ "${SERVER_DATA}" != /* ]]; then
  SERVER_DATA="${SCRIPT_DIR}/${SERVER_DATA}"
fi
STEAMCMD_DIR="${SERVER_DATA}/steamcmd"
TML_DIR="${SERVER_DATA}/tmodloader"
MODS_DIR="${SERVER_DATA}/Mods"
WORLDS_DIR="${SERVER_DATA}/Worlds"

resolve_tml_root() {
  local base_dir="$1"
  local candidate

  for candidate in \
    "${base_dir}" \
    "${base_dir}/tModLoader" \
    "${base_dir}/steamapps/common/tModLoader"
  do
    if [[ -f "${candidate}/start-tModLoaderServer.sh" ]]; then
      printf '%s\n' "${candidate}"
      return 0
    fi
  done

  return 1
}

sudo dpkg --add-architecture i386
sudo apt-get update
sudo apt-get install -y curl wget tar unzip lib32gcc-s1 ca-certificates tmux

mkdir -p "${SERVER_DATA}" "${STEAMCMD_DIR}" "${TML_DIR}" "${MODS_DIR}" "${WORLDS_DIR}"

if [[ ! -x "${STEAMCMD_DIR}/steamcmd.sh" ]]; then
  wget -O /tmp/steamcmd_linux.tar.gz https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz
  tar -xzf /tmp/steamcmd_linux.tar.gz -C "${STEAMCMD_DIR}"
fi

APP_UPDATE_ARGS=("${TML_APP_ID}")
if [[ -n "${TMODLOADER_BRANCH:-}" ]]; then
  APP_UPDATE_ARGS+=("-beta" "${TMODLOADER_BRANCH}")
fi
APP_UPDATE_ARGS+=("validate")

"${STEAMCMD_DIR}/steamcmd.sh" \
  +force_install_dir "${TML_DIR}" \
  +login anonymous \
  +app_update "${APP_UPDATE_ARGS[@]}" \
  +quit

if ! TML_ROOT="$(resolve_tml_root "${TML_DIR}")"; then
  echo "tModLoader server script was not found under ${TML_DIR}"
  echo "Checked:"
  echo "  ${TML_DIR}"
  echo "  ${TML_DIR}/tModLoader"
  echo "  ${TML_DIR}/steamapps/common/tModLoader"
  exit 1
fi

chmod +x "${TML_ROOT}"/*.sh || true

ENABLED_FILE="${MODS_DIR}/enabled.json"

if [[ -f "${ENABLED_FILE}" ]]; then
  echo "Using existing ${ENABLED_FILE}"
else
  declare -a ENABLED_MODS=()

  while IFS= read -r mod_file; do
    mod_name="$(basename "${mod_file}" .tmod)"
    if [[ -n "${mod_name}" ]]; then
      ENABLED_MODS+=("${mod_name}")
    fi
  done < <(find "${MODS_DIR}" -maxdepth 1 -type f -name '*.tmod' | sort)

  if (( ${#ENABLED_MODS[@]} > 0 )); then
    {
      echo "["
      for i in "${!ENABLED_MODS[@]}"; do
        separator=","
        if [[ "${i}" -eq $((${#ENABLED_MODS[@]} - 1)) ]]; then
          separator=""
        fi
        printf '  "%s"%s\n' "${ENABLED_MODS[$i]}" "${separator}"
      done
      echo "]"
    } > "${ENABLED_FILE}"

    echo "Created ${ENABLED_FILE} from local .tmod files."
  else
    echo "No .tmod files found in ${MODS_DIR}; enabled.json was not created."
  fi
fi

echo
echo "Server data directory: ${SERVER_DATA}"
echo "SteamCMD directory: ${STEAMCMD_DIR}"
echo "tModLoader install directory: ${TML_ROOT}"
echo "Mods directory: ${MODS_DIR}"
echo "Worlds directory: ${WORLDS_DIR}"
echo
echo "Setup complete."
echo "Place your mods and install.txt in ${MODS_DIR} if needed, then run ./start-server.sh"
