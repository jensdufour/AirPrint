# Stage 1: Extract Canon UFR II V6.20 driver from Canon CDN
FROM debian:bookworm-slim AS driver-extractor
RUN apt-get update -qq && apt-get install -y -qq curl ca-certificates && \
	mkdir -p /tmp/canon /output && \
	curl -fsSL -L "http://gdlp01.c-wss.com/gds/8/0100007658/47/linux-UFRII-drv-v620-m17n-20.tar.gz" \
	-o /tmp/canon/driver.tar.gz && \
	tar -xzf /tmp/canon/driver.tar.gz -C /tmp/canon && \
	DEB=$(find /tmp/canon -path '*/x64/Debian/*.deb' -type f | head -1) && \
	dpkg-deb -x "$DEB" /output/ && \
	rm -rf /tmp/canon

# Stage 2: Alpine runtime
FROM alpine:3.21

RUN apk add --no-cache \
	cups \
	cups-filters \
	avahi \
	dbus \
	inotify-tools \
	python3 \
	py3-pip \
	cups-dev \
	python3-dev \
	gcc \
	musl-dev \
	shadow \
	gcompat \
	libstdc++ \
	libgcc \
	ghostscript \
	&& pip3 install --break-system-packages pycups \
	&& apk del --no-cache cups-dev python3-dev gcc musl-dev py3-pip

ENV CUPSADMIN=admin \
	CUPSPASSWORD=password

# Copy Canon UFR II driver files
COPY --from=driver-extractor /output/ /

EXPOSE 631
VOLUME /config /services

HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
	CMD cupsd -t || exit 1

COPY cupsd.conf /etc/cups/cupsd.conf
COPY scripts/ /opt/airprint/
RUN chmod +x /opt/airprint/*

CMD ["/opt/airprint/run_cups.sh"]
