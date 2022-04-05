# docker-rtorrent

<p align="center"><a target="_blank"><img height="128" src="https://raw.githubusercontent.com/wonderfall/docker-rtorrent/main/.github/assets/docker-rtorrent.png"></a></p>
<p align="center"><i>Distroless Docker/OCI image of jesec's rtorrent with unrar tools.</i></p>

## Why?
The existing images don't provide a way to automatically unpack RAR releases, and if we're using distroless, we have to statically build a bunch of things.

## Usage
Sample configuration files are provided in this repository. I use rTorrent with [Flood](https://github.com/jesec/flood), and [Traefik](https://github.com/traefik/traefik) as the reverse proxy (but the choice of the reverse proxy configuration is yours).

You should read and adapt `.rtorrent.rc` to your needs (though it provides an already decent configuration), and put it in the volume that is indicated by the `HOME` environment variable. By default, `HOME` is `/config` and the image is running with UID/GID `1000`: that means you should create a directory on the host, put the configuration file there, and change permissions accordingly with `chown -R UID:GID /path/to/host/volume`.

Comment the last line if you don't want RARs to be unpacked, but then you should prefer [a more simple image](https://github.com/jesec/rtorrent).

## Security
- The `Dockerfile` is defaulting to the non-privileged `1000:1000` user. It contains only the necessary dependencies thanks to the [distroless](https://github.com/GoogleContainerTools/distroless) project from Google. This results in a very small image with low attack surface.
- The sample `docker-compose.yml` is optimized for security: the container filesystem will be read-only except of course for the mounted volumes. Furthermore, all capabilities are dropped since we don't need them and privilege escalation is made harder.
- The default `.rtorrent.rc` uses unix sockets by default for the RPC interface, making the connection with Flood seamless. You can use a SCGI port as well, but it should only be exposed within a network shared with Flood (accessible via `rtorrent:5000`), and never published to other containers or on the host.
- I highly recommend running both rTorrent and Flood in [gVisor](https://gvisor.dev/). I've never experienced a single issue with them running in gVisor, and you'll get a strong isolation. Note that by default, gVisor doesn't support unix sockets, so you'll probably have to use the SCGI port approach.
