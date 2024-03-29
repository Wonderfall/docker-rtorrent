# docker-rtorrent

⚠️**Obsolete**: it has been a fun ride, albeit a short one. Flood and jesec's fork of rtorrent are not getting maintenance updates nowadays, so I decided to make the switch to qBittorrent. I still thank jesec for his work. Given this situation, I don't have an interest in maintaining this project anymore. Going forward, you are on your own if you want to keep using this image, or you can switch to something else. Take care!

<p align="center"><a target="_blank"><img height="128" src="https://raw.githubusercontent.com/wonderfall/docker-rtorrent/main/.github/assets/docker-rtorrent.png"></a></p>
<p align="center"><i>Distroless Docker/OCI image of jesec's rtorrent with unrar tools.</i></p>

## Why?
The existing images don't provide a way to automatically unpack RAR releases, and if we're using distroless, we have to statically build a bunch of things.

## Usage
Sample configuration files are provided in this repository. I use rTorrent with [Flood](https://github.com/jesec/flood), and [Traefik](https://github.com/traefik/traefik) as the reverse proxy (but the choice of the reverse proxy configuration is yours).

Automated builds are available in the GitHub Container Registry. To pull the image:

```
docker pull ghcr.io/wonderfall/rtorrent:0.9.8
```

Builds are also signed by [cosign](https://github.com/sigstore/cosign). To check the signature:

```
COSIGN_EXPERIMENTAL=true cosign verify ghcr.io/wonderfall/rtorrent:0.9.8
```

You should read and adapt `.rtorrent.rc` to your needs (though it provides an already decent configuration), and put it in the volume that is indicated by the `HOME` environment variable. By default, `HOME` is `/config` and the image is running with UID/GID `1000`: that means you should create a directory on the host, put the configuration file there, and change permissions accordingly with `chown -R UID:GID /path/to/host/volume`.

Comment the last line if you don't want RARs to be unpacked, but then you should prefer [a more simple image](https://github.com/jesec/rtorrent).

## Extending functionality
You may want to use common tools such as `mv` or `mkdir` for automation purposes. Those aren't available by default, but can easily be added on top of the current image. For instance, you can write your own Dockerfile like this:

```Dockerfile
FROM ghcr.io/wonderfall/rtorrent
COPY --from=gcr.io/distroless/static:debug /busybox/mv /bin/mv
COPY --from=gcr.io/distroless/static:debug /busybox/mkdir /bin/mkdir
```

## Security
- The `Dockerfile` is defaulting to the non-privileged `1000:1000` user. It contains only the necessary dependencies thanks to the [distroless](https://github.com/GoogleContainerTools/distroless) project from Google. This results in a very small image with low attack surface.
- The sample `docker-compose.yml` is optimized for security: the container filesystem will be read-only except of course for the mounted volumes. Furthermore, all capabilities are dropped since we don't need them and privilege escalation is made harder.
- The default `.rtorrent.rc` uses unix sockets by default for the RPC interface, making the connection with Flood seamless. You can use a SCGI port as well, but it should only be exposed within a network shared with Flood (accessible via `rtorrent:5000`), and never published to other containers or on the host.
- I highly recommend running both rTorrent and Flood in [gVisor](https://gvisor.dev/). I've never experienced a single issue with them running in gVisor, and you'll get a strong isolation boundary. Note that by default, gVisor doesn't support mounting unix sockets on the host, so you'll probably have to use the SCGI port approach (or set the [flag](https://github.com/google/gvisor/blob/1a7f7a5c9290bdeb4aacaaa20353b017618d8679/runsc/config/flags.go#L80)).
- This image is scheduled to be built every week. You should probably pull a newer image and recreate the container from time to time to ensure all dependencies stay up-to-date.
