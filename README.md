# Docksbox — DOSBox in a container, served over a browser (with sound)

A containerized DOSBox-Staging environment exposed through noVNC and a websockified audio
stream, so DOS games are playable directly from a browser. After a multi-year hiatus on the
original project, sound support has been added and the Dockerfile rebuilt around Supervisor
to manage the (now larger) set of background processes.

## Running the published image

A prebuilt multi-arch image is published on GHCR. The fastest way to try it is:

```bash
docker run --rm -p 127.0.0.1:6080:80 ghcr.io/sunsided/docksbox:latest
```

Then open <http://localhost:6080/>.

The image is also wired up in `docker-compose.yaml`, which additionally bind-mounts a local
`./games/` directory into the DOS `C:\GAMES` drive:

```bash
docker compose up
```

## Building locally

```bash
git clone https://github.com/sunsided/docksbox.git
cd docksbox
docker build -t docksbox .
docker run --rm -p 127.0.0.1:6080:80 docksbox
```

To bundle your own game data into the image, drop the files into a subdirectory at the
repo root (e.g. `wolf3d/`) and add a matching `ADD` line in the `docksbox` stage of the
`Dockerfile`, mirroring the existing `keen/` and `doom/` entries.

Alternatively, leave the image clean and supply games at runtime via the `./games`
bind mount in `docker-compose.yaml`.

## Security

The VNC server inside the container runs with `SecurityTypes=None` and is bound to
`127.0.0.1`. The only network surface is the nginx reverse proxy on port 80, which
multiplexes the noVNC websocket and audio stream. **Do not expose port 80 to a public
network without putting TLS and an authenticating proxy in front of it.** The
`docker-compose.yaml` therefore binds the published port to `127.0.0.1` by default.

## Kubernetes

Example manifests live under `k8s/manifests/`. See [`KUBERNETES.md`](KUBERNETES.md) for
deployment notes. Because each container holds a stateful VNC session, deployments are
pinned to a single replica.
