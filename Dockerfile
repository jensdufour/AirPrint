# Stage 1: Extract PPD/driver files from .deb packages
FROM debian:bookworm-slim AS ppd-extractor
COPY PPD/ /tmp/PPD/
RUN mkdir -p /output && \
	for deb in /tmp/PPD/*.deb; do \
	dpkg-deb -x "$deb" /output/ 2>/dev/null || true; \
	done

# Stage 2: Alpine runtime
FROM alpine:3.21

RUN apk add --no-cache \
	cups \
	cups-filters \
	avahi \
	dbus \
	inotify-tools \
	python3 \
	py3-cups \
	shadow \
	gcompat \
	libstdc++ \
	libgcc

ENV CUPSADMIN=admin \
	CUPSPASSWORD=password

# Copy extracted driver files from Debian stage
COPY --from=ppd-extractor /output/ /

EXPOSE 631
VOLUME /config /services

HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
	CMD cupsd -t || exit 1

COPY cupsd.conf /etc/cups/cupsd.conf
COPY scripts/ /opt/airprint/
RUN chmod +x /opt/airprint/*

CMD ["/opt/airprint/run_cups.sh"]
