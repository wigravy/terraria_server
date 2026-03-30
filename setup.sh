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

SERVER_BIN="${INSTALL_DIR}/start-tModLoaderServer.sh"

if [[ ! -f "${SERVER_BIN}" ]]; then
  echo "tModLoader server script was not found in ${INSTALL_DIR}"
  exit 1
fi

chmod +x "${INSTALL_DIR}"/*.sh || true

MODS_DIR="${HOME}/.local/share/Terraria/tModLoader/Mods"
mkdir -p "${MODS_DIR}"

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

  echo "Server mods directory: ${MODS_DIR}"
fi

if [[ -n "${OPTIONAL_CLIENT_MOD_IDS:-}" ]]; then
  echo "Optional client-only mod IDs: ${OPTIONAL_CLIENT_MOD_IDS}"
fi

echo
echo "Setup complete."
echo "Edit ${ENV_FILE} if needed, then run ./start-server.sh"
