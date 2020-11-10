# Intro
This Ubuntu-based Docker image runs a CUPS instance that is meant as an AirPrint
Based upon [quadportnick/docker-cups-airprint](https://github.com/quadportnick/docker-cups-airprint)
We are using the "host" networking mode to easily passthrough the ports for printing. This can be changed to manually mapping all the ports.
Be aware that mapping ports and the usage of "host" networking mode is not supported.
If you have additional questions about this, don't hesitate to contact me.

**IF YOU NEED ADDITIONAL DRIVERS ADDED, PLEASE CREATE AN ISSUE**

## Compose
Creating a container is often more desirable than directly running it:
```
  airprint:
    image: firilith/airprint:latest
    container_name: airprint
    network_mode: host
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=Europe/Brussels
      - CUPSADMIN= #optional
      - CUPSPASSWORD= #optional
    volumes:
      - /media/config/airprint/services:/services
      - /media/config/airprint:/config
      - /var/run/dbus:/var/run/dbus
    restart: unless-stopped
```

## Create
Creating a container is often more desirable than directly running it:
```
$ docker create \
       --name=cups \
       --restart=always \
       --net=host \
       -v /config/airprint:/config \
       -v /config/airprint/services:/services \
       -e CUPSADMIN="admin" \
       -e CUPSPASSWORD="password" \
       tigerj/cups-airprint
```
Follow this with `docker start` and your cups/airprint printer is running:
```
$ docker start cups
```
To stop the container simply run:
```
$ docker stop cups
```
To remove the conainer simply run:
```
$ docker rm cups
```

### Parameters
* `--name`: gives the container a name making it easier to work with/on (e.g.
  `cups`)
* `--restart`: restart policy for how to handle restarts (e.g. `always` restart)
* `--net`: network to join (e.g. the `host` network)
* `-v ~/airprint_data/config:/config`: where the persistent printer configs
   will be stored
* `-v ~/airprint_data/services:/services`: where the Avahi service files will
   be generated
* `-e CUPSADMIN`: the CUPS admin user you want created
* `-e CUPSPASSWORD`: the password for the CUPS admin user

## Using
CUPS will be configurable at http://localhost:631 using the
CUPSADMIN/CUPSPASSWORD when you do something administrative.

If the `/services` volume isn't mapping to `/etc/avahi/services` then you will
have to manually copy the .service files to that path at the command line.

```
$ docker exec -it airprint /bin/bash
$ cp /services/* /etc/avahi/services/
$ /etc/init.d/dbus restart
$ /etc/init.d/avahi-daemon restart
$ exit
$ exit
```
## Notes
* CUPS doesn't write out `printers.conf` immediately when making changes even
though they're live in CUPS. Therefore it will take a few moments before the
services files update
* Don't stop the container immediately if you intend to have a persistent
configuration for this same reason
