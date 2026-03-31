#!/usr/bin/env python3
"""Generate Avahi service files for CUPS shared printers to enable AirPrint."""

import argparse
import os
import socket
import sys

import cups


def build_urf(attrs):
    """Build a URF capability string from printer IPP attributes."""
    parts = []

    # Duplex
    sides = attrs.get("sides-supported", ())
    if isinstance(sides, str):
        sides = (sides,)
    has_duplex = any("two-sided" in s for s in sides)
    parts.append("DM3" if has_duplex else "DM1")

    # Color
    has_color = bool(attrs.get("color-supported", False))
    parts.append("CP1" if has_color else "CP99")

    # Resolution, bit depth, color space, quality
    parts.extend(["RS300-600", "W8"])
    if has_color:
        parts.append("SRGB24")
    parts.extend(["PQ4", "OB10", "IS1"])

    return ",".join(parts)


def service_xml(name, info, attrs, host, port):
    """Return Avahi service-group XML for one printer."""
    description = info.get("printer-info", name)
    location = info.get("printer-location", "")
    make_model = info.get("printer-make-and-model", "Unknown Printer")

    printer_uuid = attrs.get("printer-uuid", "") or info.get("printer-uuid", "")
    if printer_uuid.startswith("urn:uuid:"):
        printer_uuid = printer_uuid[9:]

    printer_type = info.get("printer-type", 0)
    printer_state = info.get("printer-state", 3)

    sides = attrs.get("sides-supported", ())
    if isinstance(sides, str):
        sides = (sides,)
    has_duplex = any("two-sided" in s for s in sides)
    has_color = bool(attrs.get("color-supported", False))

    urf = build_urf(attrs)
    pdl = (
        "application/octet-stream,"
        "application/pdf,"
        "image/jpeg,"
        "image/png,"
        "image/urf"
    )

    records = [
        ("txtvers", "1"),
        ("qtotal", "1"),
        ("rp", f"printers/{name}"),
        ("ty", description),
        ("adminurl", f"http://{host}:{port}/printers/{name}"),
        ("note", location),
        ("priority", "0"),
        ("product", f"({make_model})"),
        ("pdl", pdl),
        ("URF", urf),
        ("Color", "T" if has_color else "F"),
        ("Duplex", "T" if has_duplex else "F"),
        ("Copies", "T"),
        ("printer-state", str(printer_state)),
        ("printer-type", f"0x{printer_type:X}"),
    ]
    if printer_uuid:
        records.append(("UUID", printer_uuid))

    txt = "\n".join(
        f"      <txt-record>{k}={v}</txt-record>" for k, v in records
    )

    return f"""\
<?xml version="1.0" standalone="no"?>
<!DOCTYPE service-group SYSTEM "avahi-service.dtd">
<service-group>
  <name replace-wildcards="yes">AirPrint {description} @ %h</name>
  <service>
    <type>_ipp._tcp</type>
    <subtype>_universal._sub._ipp._tcp</subtype>
    <port>{port}</port>
{txt}
  </service>
</service-group>
"""


def main():
    parser = argparse.ArgumentParser(
        description="Generate Avahi service files for AirPrint printers"
    )
    parser.add_argument(
        "-d", "--directory",
        default="/etc/avahi/services",
        help="Output directory for .service files",
    )
    parser.add_argument(
        "-p", "--port",
        type=int,
        default=631,
        help="CUPS listening port",
    )
    args = parser.parse_args()

    host = socket.getfqdn()
    if not host or host == "localhost":
        host = socket.gethostname()

    try:
        conn = cups.Connection()
    except RuntimeError:
        print("Cannot connect to CUPS", file=sys.stderr)
        sys.exit(1)

    printers = conn.getPrinters()
    if not printers:
        print("No printers configured in CUPS")
        return

    os.makedirs(args.directory, exist_ok=True)

    for pname, pinfo in printers.items():
        if not pinfo.get("printer-is-shared", True):
            continue

        try:
            pattrs = conn.getPrinterAttributes(pname)
        except Exception:
            pattrs = {}

        xml = service_xml(pname, pinfo, pattrs, host, args.port)
        path = os.path.join(args.directory, f"AirPrint-{pname}.service")
        with open(path, "w") as fh:
            fh.write(xml)
        print(f"Generated {path}")


if __name__ == "__main__":
    main()
