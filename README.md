# docker-vdr

Docker image for a **headless VDR recording server** – based on Debian 13
("trixie") with **VDR 2.6.9** from the official Debian packages.

This branch (`2.6`) replaces the legacy build (Ubuntu 18.04 / VDR 2.4.0,
circa 2020). It is a complete rewrite: instead of relying on distribution
packages from 2020 plus manual in-container tweaks, the image now builds
cleanly from current sources and includes a proper start script.

## What's inside
   Component | Source | Notes |
 |---|---|---|
 | VDR 2.6.9 | Debian package (`vdr`) | |
 | epgsearch | Debian package | Search timers, EPG search |
 | streamdev (server) | Debian package | Streaming via VTP/HTTP, port 3000 |
 | live | Debian package (`vdr-plugin-live` 3.5.0) | Web UI on port 8008. Not built from Git: upstream code is incompatible with cxxtools 3.x, the Debian package is maintained and newer |
 | restfulapi | Source build ([yavdr fork](https://github.com/yavdr/vdr-plugin-restfulapi), actively maintained) | REST API on port 8002, serves the bundled web app |
 | ddci2 | Source build ([jasmin-j](https://github.com/jasmin-j/vdr-plugin-ddci2)) | Digital Devices standalone CI support |
 | dummydevice | Source build ([flensrocker fork](https://github.com/flensrocker/vdr-plugin-dummydevice)) | Headless operation: no output device, tuner stays free for recordings |
 | vnsiserver | Source build ([vdr-projects](https://github.com/vdr-projects/vdr-plugin-vnsiserver)) | Kodi/VNSI clients, port 34890 |
 | svdrposd, svdrpservice | Source build ([vdr-projects](https://github.com/vdr-projects)) | SVDRP OSD/service access on port 6419 |

Omitted on purpose: satip, eepg, xmltv2vdr, robotv, iptv, wirbelscan, femon,
vdradmin-am.

### Build quirks worth knowing

- **Debian trixie splits streamdev** into `vdr-plugin-streamdev-server` and
  `-client`; only the server is needed.
- Several plugin Makefiles set their own `CXXFLAGS` without `-fPIC` (which
  `vdr.pc` does not provide in trixie), so linking the shared library fails.
  The Dockerfile appends `-fPIC` to the relevant Makefile lines via `sed`.
- The plugin list in the start script is **intentionally hardcoded**. VDR's
  `conf.d/` mechanism is not used for plugin selection.

## Ports
 | Port | Purpose |
 |---|---|
 | 6419 | SVDRP (remote control, OSD service) |
 | 8002 | restfulapi (REST API + web app) |
 | 8008 | live (web UI) |
 | 3000 | streamdev server (VTP/HTTP streaming) |
 | 2004 | streamdev HTTP streaming |
 | 34890 | vnsiserver (Kodi) |

## Build

```bash
git clone https://github.com/sneakyx/docker-vdr.git
cd docker-vdr
git checkout 2.6
docker build -t sneaky/vdr:2.6 --build-arg BUILD_DATE=$(date -I) .
```

## Run

The container expects a DVB device to be passed through. Adjust the volume
paths to your setup:

```yaml
services:
  vdr:
    image: sneaky/vdr:2.6
    container_name: vdr-server
    restart: unless-stopped
    devices:
      - /dev/dvb:/dev/dvb
    volumes:
      - /path/to/recordings:/srv/vdr/video
      - /path/to/vdr-config:/etc/vdr
      - /path/to/vdr-data:/var/lib/vdr
    ports:
      - "2004:2004"
      - "3000:3000"
      - "6419:6419"
      - "8001:8001"
      - "8002:8002"
      - "8008:8008"
      - "34890:34890"
```

### Volumes
 | Container path | Content |
 |---|---|
 | `/srv/vdr/video` | Recordings |
 | `/etc/vdr` | Plugin configuration (`conf.d/`, `plugins/`) |
 | `/var/lib/vdr` | VDR data (`setup.conf`, `channels.conf`, `svdrphosts.conf`) |

On first start, if `/var/lib/vdr/svdrphosts.conf` does not exist, a default
is copied from `/etc/drafts/` inside the image (localhost, common local
networks, Docker bridge). Adjust it to your network.

### Health check

The image ships a `HEALTHCHECK` that probes the restfulapi on port 8002.
If that port answers, the VDR is up.

## License

VDR and its plugins are GPL-licensed; this repository only contains build
files. See the individual plugin repositories for their licenses.
