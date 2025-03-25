# vera-connect
A simple docker image that allows to use your Vera as a remote z-wave controller in secure and non-destructive way.

Uses ser2net and a SSH tunnel to establish the connection and make the z-wave controller device available via TCP socket. 

Inspired by [this discussion](https://community.home-assistant.io/t/using-a-vera-edge-as-a-network-attached-zwave-device-skipping-the-vera-software/30607) and [binlab/docker-sshtunnel](https://github.com/binlab/docker-sshtunnel).

Rebooting Vera will wipe out all changes set by this docker image and return the device back to normal.

Uses public key authentication. To set up Vera to accept key authentication I used [Dropbear Public Key Authentication](https://oldwiki.archive.openwrt.org/oldwiki/dropbearpublickeyauthenticationhowto) instructions, but instead of using dsa use rsa.

## Usage

There is only one environmental variable that needs to be set:

```
VERA_HOST=<host_name/ip_address>
```

Private key needs to be mapped via volume

```
path_to_private_key:/vera/id_rsa:ro
```

Docker-compose example for use with `zwave-js-ui`:

```yaml
version: '3.3'
services:
  vera-connect:
    container_name: vera-connect
    build:
      context: .
    healthcheck:
      test: nc -z localhost $$LOCAL_PORT
    environment:
      - VERA_HOST=192.168.0.123
    volumes:
      - ./id_rsa:/vera/id_rsa:ro
    expose:
      - 7676
    networks:
      - hass

  zwave-js-ui:
    container_name: zwave-js-ui
    image: zwavejs/zwave-js-ui:latest
    depends_on:
      vera-connect:
        condition: service_healthy
        restart: true
    restart: unless-stopped
    tty: true
    stop_signal: SIGINT
    environment:
      - SESSION_SECRET=mysupersecretkey
      - ZWAVEJS_EXTERNAL_CONFIG=/usr/src/app/store/.config-db
    networks:
      - hass
    volumes:
      - ./zwavejs:/usr/src/app/store
    ports:
      - 8091:8091 # port for web interface
      - 3000:3000 #

networks:
  hass:
```

In `zwave-js-ui` then connect to controller using `vera-connect:7676`
