FROM debian:buster-slim

ENV DEBIAN_FRONTEND noninteractive apt-get -q -y install postfix

# Install the packages we need. Avahi will be included
RUN apt-get update && apt-get install -y \
	cups \
	cups-pdf \
	hplip \
	inotify-tools \
	python-cups \
	openprinting-ppds \
	printer-driver-gutenprint \
	foomatic-db \
	&& rm -rf /var/lib/apt/lists/*

# This will use port 631
EXPOSE 631

# We want a mount for these
VOLUME /config
VOLUME /services

# Install custom drivers from PPD
ADD PPD /PPD
RUN apt install /PPD/*

# Add scripts
COPY root /
RUN chmod +x /root/* 
CMD ["/root/run_cups.sh"]

# Baked-in config file changes
RUN sed -i 's/Listen localhost:631/Listen 0.0.0.0:631/' /etc/cups/cupsd.conf && \
	sed -i 's/Browsing Off/Browsing On/' /etc/cups/cupsd.conf && \
	sed -i 's/<Location \/>/<Location \/>\n  Allow All/' /etc/cups/cupsd.conf && \
	sed -i 's/<Location \/admin>/<Location \/admin>\n  Allow All\n  Require user @SYSTEM/' /etc/cups/cupsd.conf && \
	sed -i 's/<Location \/admin\/conf>/<Location \/admin\/conf>\n  Allow All/' /etc/cups/cupsd.conf && \
	echo "ServerAlias *" >> /etc/cups/cupsd.conf && \
	echo "DefaultEncryption Never" >> /etc/cups/cupsd.conf

# Create symbolic links for Avahi
RUN ln -s /services/* /etc/avahi/services/
