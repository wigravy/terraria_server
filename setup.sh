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

STEAMCMD_DIR="${STEAMCMD_DIR:-${SCRIPT_DIR}/steamcmd}"
INSTALL_DIR="${INSTALL_DIR:-${SCRIPT_DIR}/tmodloader}"
DATA_DIR="${DATA_DIR:-${SCRIPT_DIR}/server_data}"

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

if [[ "${USE_STEAM_LOGIN:-false}" == "true" ]]; then
  if [[ -z "${STEAM_USERNAME:-}" || -z "${STEAM_PASSWORD:-}" ]]; then
    echo "STEAM_USERNAME and STEAM_PASSWORD must be set when USE_STEAM_LOGIN=true"
    exit 1
  fi
fi

sudo dpkg --add-architecture i386
sudo apt-get update
sudo apt-get install -y curl wget tar unzip lib32gcc-s1 ca-certificates tmux

mkdir -p "${STEAMCMD_DIR}" "${INSTALL_DIR}"

if [[ ! -x "${STEAMCMD_DIR}/steamcmd.sh" ]]; then
  wget -O /tmp/steamcmd_linux.tar.gz https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz
  tar -xzf /tmp/steamcmd_linux.tar.gz -C "${STEAMCMD_DIR}"
fi

LOGIN_ARGS=("anonymous")
if [[ "${USE_STEAM_LOGIN:-false}" == "true" ]]; then
  LOGIN_ARGS=("${STEAM_USERNAME}" "${STEAM_PASSWORD}")
fi

"${STEAMCMD_DIR}/steamcmd.sh" \
  +force_install_dir "${INSTALL_DIR}" \
  +login "${LOGIN_ARGS[@]}" \
  +app_update "${TML_APP_ID}" \
  +quit

if ! TML_ROOT="$(resolve_tml_root "${INSTALL_DIR}")"; then
  echo "tModLoader server script was not found under ${INSTALL_DIR}"
  echo "Checked:"
  echo "  ${INSTALL_DIR}"
  echo "  ${INSTALL_DIR}/tModLoader"
  echo "  ${INSTALL_DIR}/steamapps/common/tModLoader"
  exit 1
fi

SERVER_BIN="${TML_ROOT}/start-tModLoaderServer.sh"

if [[ ! -f "${SERVER_BIN}" ]]; then
  echo "tModLoader server script was not found in ${TML_ROOT}"
  exit 1
fi

chmod +x "${TML_ROOT}"/*.sh || true

MODS_DIR="${DATA_DIR}/Mods"
WORLD_DIR="${DATA_DIR}/Worlds"
mkdir -p "${DATA_DIR}" "${MODS_DIR}" "${WORLD_DIR}"

if [[ -n "${WORKSHOP_MOD_IDS:-}" ]]; then
  INSTALL_TXT="${MODS_DIR}/install.txt"
  : > "${INSTALL_TXT}"

  IFS=',' read -r -a MOD_IDS <<< "${WORKSHOP_MOD_IDS}"
  for mod_id in "${MOD_IDS[@]}"; do
    trimmed_mod_id="$(echo "${mod_id}" | xargs)"
    if [[ -n "${trimmed_mod_id}" ]]; then
      echo "${trimmed_mod_id}" >> "${INSTALL_TXT}"
    fi
  done

  echo "Prepared ${INSTALL_TXT} with server mod IDs."

  if [[ "${DOWNLOAD_WORKSHOP_MODS:-true}" == "true" ]]; then
    for mod_id in "${MOD_IDS[@]}"; do
      trimmed_mod_id="$(echo "${mod_id}" | xargs)"
      [[ -z "${trimmed_mod_id}" ]] && continue

      echo "Downloading workshop mod ${trimmed_mod_id}"
      if ! "${STEAMCMD_DIR}/steamcmd.sh" +login "${LOGIN_ARGS[@]}" +workshop_download_item "${TML_APP_ID}" "${trimmed_mod_id}" +quit; then
        echo "Workshop download failed for ${trimmed_mod_id}. The server can still use install.txt or client sync."
        continue
      fi

      workshop_path="${STEAMCMD_DIR}/steamapps/workshop/content/${TML_APP_ID}/${trimmed_mod_id}"
      if compgen -G "${workshop_path}/*.tmod" > /dev/null; then
        cp "${workshop_path}"/*.tmod "${MODS_DIR}/"
      else
        echo "No .tmod files found in ${workshop_path}"
      fi
    done
  fi

  echo "Server data directory: ${DATA_DIR}"
  echo "tModLoader install directory: ${TML_ROOT}"
  echo "Server mods directory: ${MODS_DIR}"
fi

ENABLED_FILE="${MODS_DIR}/enabled.json"
declare -a ENABLED_MODS=()

if [[ -n "${ENABLED_MOD_NAMES:-}" ]]; then
  IFS=',' read -r -a RAW_ENABLED_MODS <<< "${ENABLED_MOD_NAMES}"
  for mod_name in "${RAW_ENABLED_MODS[@]}"; do
    trimmed_mod_name="$(echo "${mod_name}" | xargs)"
    if [[ -n "${trimmed_mod_name}" ]]; then
      ENABLED_MODS+=("${trimmed_mod_name}")
    fi
  done
else
  while IFS= read -r mod_file; do
    mod_name="$(basename "${mod_file}" .tmod)"
    if [[ -n "${mod_name}" ]]; then
      ENABLED_MODS+=("${mod_name}")
    fi
  done < <(find "${MODS_DIR}" -maxdepth 1 -type f -name '*.tmod' | sort)
fi

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

  echo "Prepared ${ENABLED_FILE} with ${#ENABLED_MODS[@]} enabled mods."
else
  echo "No enabled mods were detected."
  echo "Set ENABLED_MOD_NAMES in ${ENV_FILE} if workshop downloads do not produce local .tmod files."
fi

if [[ -n "${OPTIONAL_CLIENT_MOD_IDS:-}" ]]; then
  echo "Optional client-only mod IDs: ${OPTIONAL_CLIENT_MOD_IDS}"
fi

echo
echo "Setup complete."
echo "Edit ${ENV_FILE} if needed, then run ./start-server.sh"
