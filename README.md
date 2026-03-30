# Terraria tModLoader Server for Ubuntu

Language:

- English: [README.md](./README.md)
- Russian: [docs/README.ru.md](./docs/README.ru.md)

Simple multiplayer server setup for `Terraria` on Ubuntu using `tModLoader`.

This build is centered on `Calamity Mod` and a small set of supporting multiplayer mods.

Mod list:

- English: [docs/MODS.md](./docs/MODS.md)
- Russian: [docs/MODS.ru.md](./docs/MODS.ru.md)

## What is in this repository

- shell scripts for setup and startup
- config templates
- mod IDs for the server pack

This repository does not include Terraria, `tModLoader`, mod files, or game source code.

## Requirements

- Ubuntu `22.04` or newer
- `tModLoader`
- open port `7777` on your router/firewall if players join over the internet

## Server requirements

- CPU: modern 2-core CPU minimum
- RAM: `4 GB` minimum, `8 GB` recommended for a smoother modded multiplayer server
- Storage: at least `10 GB` free space for `tModLoader`, mods, and world files

## Quick start

1. Copy the repository to your Ubuntu server.
2. Create your local config:

```bash
cp .env.example .env
```

3. Edit `.env`.
4. Make the scripts executable:

```bash
chmod +x setup.sh start-server.sh
```

5. Run setup:

```bash
./setup.sh
```

6. Start the server:

```bash
./start-server.sh
```

## Configuration

Main settings in `.env`:

```dotenv
SERVER_NAME=My tModLoader Server
WORLD_NAME=modded-world
WORLD_SEED=
WORLD_SIZE=2
WORLD_DIFFICULTY=0
MAX_PLAYERS=8
PORT=7777
PASSWORD=
MOTD=Welcome to the modded server
```

Useful values:

- `WORLD_SIZE`: `1` small, `2` medium, `3` large
- `WORLD_DIFFICULTY`: `0` Classic, `1` Expert, `2` Master, `3` Journey

## World seed

`WORLD_SEED` is optional. If you leave it empty, Terraria will generate a random world.

## Mods

The server is configured with the Calamity-based multiplayer pack from [docs/MODS.md](./docs/MODS.md).

Notes:

- `Calamity Mod Extra Music` is client-only and is not installed on the server

During setup, the script:

- prepares the server mod list
- attempts to download the configured Workshop mods
- copies downloaded `.tmod` files into the server mods directory
- writes `enabled.json` so the dedicated server actually loads the installed mods

Players still need `tModLoader` on their own PC. Missing required mods can usually be downloaded when they join the server.

By default, the repository expects this layout next to the scripts:

- `./steamcmd` for SteamCMD
- `./tmodloader` for the `tModLoader` server install
- `./server_data` for `Mods`, `Worlds`, and other save data

You can override any of these with `STEAMCMD_DIR`, `INSTALL_DIR`, and `DATA_DIR` in `.env`.

If the server starts but loads with zero mods, check these files in the server data directory:

- `${DATA_DIR:-./server_data}/Mods/install.txt`
- `${DATA_DIR:-./server_data}/Mods/enabled.json`

`install.txt` contains Workshop IDs. `enabled.json` contains internal mod names such as `CalamityMod` and `MagicStorage`. Both are needed for a reliable dedicated-server setup.

The start script uses `-tmlsavedirectory` so `tModLoader` uses `DATA_DIR` exactly. This matches the official command-line behavior where `Mods` and `Worlds` are derived from the chosen tModLoader save directory.

## Files

- `.env.example`: template for local settings
- `setup.sh`: installs dependencies, downloads `tModLoader`, prepares mods
- `start-server.sh`: creates `serverconfig.txt` and starts the server
- `docs/MODS.md`: grouped mod list with descriptions
- `docs/README.ru.md`: Russian README
- `docs/MODS.ru.md`: Russian mod list

## Background run

Example with `tmux`:

```bash
tmux new -s terraria
./start-server.sh
```
