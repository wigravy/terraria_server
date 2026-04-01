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
SERVER_ROOT=""
SERVER_SCRIPT=""
CONFIG_FILE="${SERVER_DATA}/serverconfig.txt"

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

if ! SERVER_ROOT="$(resolve_tml_root "${TML_DIR}")"; then
  echo "Missing tModLoader server install under ${TML_DIR}"
  echo "Checked:"
  echo "  ${TML_DIR}"
  echo "  ${TML_DIR}/tModLoader"
  echo "  ${TML_DIR}/steamapps/common/tModLoader"
  echo "Run ./setup.sh first."
  exit 1
fi

SERVER_SCRIPT="${SERVER_ROOT}/start-tModLoaderServer.sh"
WORLD_FILE="${WORLDS_DIR}/${WORLD_NAME}.wld"
BANLIST_PATH="${SERVER_DATA}/banlist.txt"
CLI_ARGS_FILE="${SERVER_DATA}/cli-argsConfig.txt"

mkdir -p "${SERVER_DATA}" "${STEAMCMD_DIR}" "${TML_DIR}" "${MODS_DIR}" "${WORLDS_DIR}"

cat > "${CONFIG_FILE}" <<EOF
world=${WORLD_FILE}
autocreate=${WORLD_SIZE}
seed=${WORLD_SEED}
worldname=${WORLD_NAME}
difficulty=${WORLD_DIFFICULTY}
maxplayers=${MAX_PLAYERS}
port=${PORT}
password=${PASSWORD}
motd=${MOTD}
worldpath=${WORLDS_DIR}
banlist=${BANLIST_PATH}
secure=${SECURE}
language=${LANGUAGE}
upnp=${UPNP}
npcstream=${NPCSTREAM}
priority=${PRIORITY}
journeypermission_time_setfrozen=${JOURNEYPERMISSION_TIME_SETFROZEN}
journeypermission_time_setdawn=${JOURNEYPERMISSION_TIME_SETDAWN}
journeypermission_time_setnoon=${JOURNEYPERMISSION_TIME_SETNOON}
journeypermission_time_setdusk=${JOURNEYPERMISSION_TIME_SETDUSK}
journeypermission_time_setmidnight=${JOURNEYPERMISSION_TIME_SETMIDNIGHT}
journeypermission_godmode=${JOURNEYPERMISSION_GODMODE}
journeypermission_wind_setstrength=${JOURNEYPERMISSION_WIND_SETSTRENGTH}
journeypermission_rain_setstrength=${JOURNEYPERMISSION_RAIN_SETSTRENGTH}
journeypermission_time_setspeed=${JOURNEYPERMISSION_TIME_SETSPEED}
journeypermission_rain_setfrozen=${JOURNEYPERMISSION_RAIN_SETFROZEN}
journeypermission_wind_setfrozen=${JOURNEYPERMISSION_WIND_SETFROZEN}
journeypermission_increaseplacementrange=${JOURNEYPERMISSION_INCREASEPLACEMENTRANGE}
journeypermission_setdifficulty=${JOURNEYPERMISSION_SETDIFFICULTY}
journeypermission_biomespread_setfrozen=${JOURNEYPERMISSION_BIOMESPREAD_SETFROZEN}
journeypermission_setspawnrate=${JOURNEYPERMISSION_SETSPAWNRATE}
modpath=${MODS_DIR}
EOF

cat > "${CLI_ARGS_FILE}" <<EOF
-tmlsavedirectory ${SERVER_DATA}
-modpath ${MODS_DIR}
EOF

if [[ ! -x "${SERVER_SCRIPT}" ]]; then
  echo "Missing or non-executable ${SERVER_SCRIPT}"
  echo "Run ./setup.sh first."
  exit 1
fi

chmod +x "${SERVER_SCRIPT}"

SERVER_ARGS=(
  -tmlsavedirectory "${SERVER_DATA}"
  -modpath "${MODS_DIR}"
  -config "${CONFIG_FILE}"
)

if [[ -n "${MODPACK:-}" ]]; then
  SERVER_ARGS+=(-modpack "${MODPACK}")
fi

echo "Starting ${SERVER_NAME} on port ${PORT}"
echo "World: ${WORLD_NAME}"
echo "Server data directory: ${SERVER_DATA}"

exec "${SERVER_SCRIPT}" "${SERVER_ARGS[@]}"
