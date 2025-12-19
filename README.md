# docker-ge-proton

A minimal Ubuntu-based Docker image that configures SteamCMD and GE-Proton for running Windows-only dedicated game servers on Linux.

## Features

- **Ubuntu 24.04** base image
- **SteamCMD** pre-installed for downloading game servers
- **GE-Proton** for Windows compatibility layer
- Non-root user setup for security
- Volume support for persistent game data

## Quick Start

1. Clone this repository:

   ```bash
   git clone https://github.com/xiahualiu/docker-ge-proton.git
   cd docker-ge-proton
   ```

2. Customize `compose.yaml` for your game (see [Configuration](#configuration))

3. Start the server:

   ```bash
   docker compose up -d
   ```

## Configuration

### Environment Variables

| Variable          | Required | Description                                           |
| ----------------- | -------- | ----------------------------------------------------- |
| `STEAM_APP_ID`    | Yes      | Steam App ID for the dedicated server                 |
| `GAME_EXECUTABLE` | Yes      | Path to the game executable (relative to install dir) |
| `GAME_ARGS`       | No       | Command-line arguments for the game server            |

### Build Arguments

| Argument         | Default          | Description                    |
| ---------------- | ---------------- | ------------------------------ |
| `STEAM_USER`     | `steam`          | Username for the non-root user |
| `STEAM_USER_UID` | `1000`           | UID for the steam user         |
| `STEAM_USER_GID` | `1000`           | GID for the steam group        |
| `PROTON_VERSION` | `GE-Proton10-26` | GE-Proton release version      |

### Volumes

| Container Path       | Host Path     | Description                             |
| -------------------- | ------------- | --------------------------------------- |
| `/home/steam/server` | `./game_data` | Game server installation and save files |

## Example: Enshrouded Server

```yaml
services:
  enshrouded-server:
    build:
      context: .
    image: enshrouded-server:latest
    container_name: enshrouded-server
    user: "1000:1000"
    ports:
      - "15637:15637/udp"
      - "27015:27015/udp"
    environment:
      - STEAM_APP_ID=2278520
      - GAME_EXECUTABLE=enshrouded_server.exe
    volumes:
      - ./game_data:/home/steam/server
```

## Building the Image

```bash
# Build with default settings
docker build -t ge-proton-server .

# Build with custom Proton version
docker build --build-arg PROTON_VERSION=GE-Proton10-25 -t ge-proton-server .
```

## Finding Steam App IDs

1. Visit [SteamDB](https://steamdb.info/)
2. Search for your game's **dedicated server**
3. Use the App ID from the dedicated server, not the game itself

## Troubleshooting

### Permission Issues

Ensure your volume directories have correct ownership:

```bash
sudo chown -R 1000:1000 ./game_data
```

### Server Not Starting

Check container logs:

```bash
docker compose logs -f
```

## License

[MIT License](LICENSE)

## Contributing

Contributions are welcome! Please open an issue or submit a pull request.
