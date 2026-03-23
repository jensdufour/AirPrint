# Welcome  <a href="https://hub.docker.com/r/firilith/airprint/"><img src="https://img.shields.io/docker/pulls/firilith/airprint.svg?style=flat-square&logo=docker" alt="Docker Pulls"></a>

This Alpine-based Docker image runs a CUPS instance that is meant as an AirPrint relay.
Based upon [quadportnick/docker-cups-airprint](https://github.com/quadportnick/docker-cups-airprint).

Uses host networking mode for mDNS/AirPrint discovery. Mapping ports manually is possible but not officially supported.

## Compose

```yaml
services:
  airprint:
    image: firilith/airprint:latest
    container_name: airprint
    network_mode: host
    environment:
      - TZ=Europe/Brussels
      - CUPSADMIN=admin
      - CUPSPASSWORD=password
    volumes:
      - /media/config/airprint:/config
      - /media/config/airprint/services:/services
    restart: unless-stopped
```

## Create

```
$ docker create \
       --name=cups \
       --restart=always \
       --net=host \
       -v /config/airprint:/config \
       -v /config/airprint/services:/services \
       -e CUPSADMIN="admin" \
       -e CUPSPASSWORD="password" \
       firilith/airprint
```

```
$ docker start cups
$ docker stop cups
$ docker rm cups
```

### Parameters
* `--name`: gives the container a name making it easier to work with/on
* `--restart`: restart policy for how to handle restarts (e.g. `always`)
* `--net`: network to join (e.g. the `host` network)
* `-v /config/airprint:/config`: where the persistent printer configs will be stored
* `-v /config/airprint/services:/services`: where the Avahi service files will be generated
* `-e CUPSADMIN`: the CUPS admin user you want created
* `-e CUPSPASSWORD`: the password for the CUPS admin user

## Using
CUPS will be configurable at http://localhost:631 using the
CUPSADMIN/CUPSPASSWORD when you do something administrative.

## Notes
* CUPS doesn't write out `printers.conf` immediately when making changes even
though they're live in CUPS. Therefore it will take a few moments before the
service files update
* Don't stop the container immediately if you intend to have a persistent
configuration for this same reason
