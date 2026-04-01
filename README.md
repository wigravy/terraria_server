# Terraria tModLoader Server for Ubuntu

Language:

- English: [README.md](./README.md)
- Russian: [docs/README.ru.md](./docs/README.ru.md)

Simple multiplayer server setup for `Terraria` on Ubuntu using `tModLoader`.

This repository installs and runs a dedicated `tModLoader` server with SteamCMD using the anonymous account only.

## What is in this repository

- shell scripts for setup and startup
- `.env.example` with supported server settings
- documentation for a sample mod pack

This repository does not include Terraria, `tModLoader`, mod files, or game source code.

## Requirements

- Ubuntu `22.04` or newer
- open TCP port `7777` on your router/firewall if players join over the internet

## Quick start

1. Copy the repository to your Ubuntu server.
2. Create your local config:

```bash
cp .env.example .env
```

3. Edit `.env` only if you need to change defaults.
4. Make the scripts executable:

```bash
chmod +x setup.sh start-server.sh
```

5. Run setup:

```bash
./setup.sh
```

6. Put your `.tmod` files in `server_data/Mods`.
7. If you exported mods from local tModLoader and have `install.txt`, place it in `server_data/Mods` as well.
8. If `server_data/Mods/enabled.json` does not exist, rerun `./setup.sh` once to generate it from the local `.tmod` files.
9. Start the server:

```bash
./start-server.sh
```

## Data layout

By default, all server runtime files are stored in `./server_data` next to the scripts. You can move the whole runtime tree by changing `SERVER_DATA` in `.env`.

The scripts create and use these folders under `SERVER_DATA`:

- `Worlds`
- `Mods`
- `tmodloader`
- `steamcmd`

The generated `serverconfig.txt`, `cli-argsConfig.txt`, and `banlist.txt` are also stored under `SERVER_DATA`.

## Mods

The scripts do not download mods.

Expected workflow:

- place `.tmod` files in `SERVER_DATA/Mods`
- optionally place your exported `install.txt` in the same folder
- keep your own `enabled.json` if you already exported one
- if `enabled.json` is missing, `setup.sh` creates it from the `.tmod` filenames present in `Mods`

## Updating

Run `./setup.sh` again at any time to update the installed `tModLoader` server files in `SERVER_DATA/tmodloader`.

By default, SteamCMD installs the latest public branch for the configured app ID. If you set `TMODLOADER_BRANCH`, that branch is requested instead.

## Configuration

`.env.example` contains:

- `SERVER_DATA` for the runtime root directory
- installer settings such as `TML_APP_ID`, `TMODLOADER_BRANCH`, and `MODPACK`
- all official Terraria dedicated-server config variables with defaults and comments

`worldpath` and `modpath` are intentionally not user-configurable. The scripts always keep them under `SERVER_DATA`.

## Files

- `.env.example`: template for local settings
- `setup.sh`: installs dependencies, installs or updates `tModLoader`, and creates `enabled.json` if needed
- `start-server.sh`: writes `serverconfig.txt` under `SERVER_DATA` and starts the server
- `docs/MODS.md`: grouped sample mod list
- `docs/README.ru.md`: Russian README
- `docs/MODS.ru.md`: Russian mod list

## Background run

Example with `tmux`:

```bash
tmux new -s terraria
./start-server.sh
```
