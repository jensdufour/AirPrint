#!/usr/bin/env python3

"""
Copyright (c) 2010 Timothy J Fontaine <tjfontaine@atxconsulting.com>

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
"""

import argparse
import cups
import os
import re
import sys
from urllib.parse import urlparse
from xml.etree.ElementTree import Element, ElementTree, fromstring, tostring

XML_TEMPLATE = """\
<service-group>
<name replace-wildcards="yes"></name>
<service>
<type>_ipp._tcp</type>
<subtype>_universal._sub._ipp._tcp</subtype>
<port>631</port>
<txt-record>txtvers=1</txt-record>
<txt-record>qtotal=1</txt-record>
<txt-record>Transparent=T</txt-record>
<txt-record>URF=none</txt-record>
</service>
</service-group>"""

DOCUMENT_TYPES = {
    'application/pdf': True,
    'application/postscript': True,
    'application/vnd.cups-raster': True,
    'application/octet-stream': True,
    'image/urf': True,
    'image/png': True,
    'image/tiff': True,
    'image/jpeg': True,
    'image/gif': True,
    'text/plain': True,
    'text/html': True,
    'image/x-xwindowdump': False,
    'image/x-xpixmap': False,
    'image/x-xbitmap': False,
    'image/x-sun-raster': False,
    'image/x-sgi-rgb': False,
    'image/x-portable-pixmap': False,
    'image/x-portable-graymap': False,
    'image/x-portable-bitmap': False,
    'image/x-portable-anymap': False,
    'application/x-shell': False,
    'application/x-perl': False,
    'application/x-csource': False,
    'application/x-cshell': False,
}


class AirPrintGenerate:
    def __init__(self, host=None, user=None, port=None, verbose=False,
                 directory=None, prefix='AirPrint-', adminurl=False):
        self.host = host
        self.user = user
        self.port = port
        self.verbose = verbose
        self.directory = directory
        self.prefix = prefix
        self.adminurl = adminurl

        if self.user:
            cups.setUser(self.user)

    def generate(self):
        if self.host:
            conn = cups.Connection(self.host, self.port or 631)
        else:
            conn = cups.Connection()

        for p, v in conn.getPrinters().items():
            if not v['printer-is-shared']:
                continue

            attrs = conn.getPrinterAttributes(p)
            uri = urlparse(v['printer-uri-supported'])

            root = fromstring(XML_TEMPLATE)
            tree = ElementTree(root)

            name_el = tree.find('name')
            if name_el is None:
                continue
            name_el.text = f'AirPrint {p} @ %h'

            service = tree.find('service')
            if service is None:
                continue

            port_el = service.find('port')
            if port_el is None:
                continue
            port_el.text = str(uri.port or self.port or cups.getPort())

            rp = uri.path
            re_match = re.match(r'^//(.*):(\d+)(/.*)', rp)
            if re_match:
                rp = re_match.group(3)
            rp = re.sub(r'^/+', '', rp)

            for key, value in [
                ('rp', rp),
                ('note', v['printer-info']),
                ('product', '(GPL Ghostscript)'),
                ('printer-state', str(v['printer-state'])),
                ('printer-type', hex(v['printer-type'])),
            ]:
                el = Element('txt-record')
                el.text = f'{key}={value}'
                service.append(el)

            fmts = []
            defer = []
            for a in attrs['document-format-supported']:
                if a in DOCUMENT_TYPES:
                    if DOCUMENT_TYPES[a]:
                        fmts.append(a)
                else:
                    defer.append(a)

            if 'image/urf' not in fmts:
                sys.stderr.write(
                    f'image/urf is not in mime types, {p} may not be '
                    f'available on iOS 6+{os.linesep}'
                )

            fmts_str = ','.join(fmts + defer)
            dropped = []
            while len(f'pdl={fmts_str}') >= 255:
                fmts_str, drop = fmts_str.rsplit(',', 1)
                dropped.append(drop)

            if dropped and self.verbose:
                sys.stderr.write(
                    f'{p} Losing support for: {",".join(dropped)}{os.linesep}'
                )

            pdl = Element('txt-record')
            pdl.text = f'pdl={fmts_str}'
            service.append(pdl)

            if self.adminurl:
                admin = Element('txt-record')
                admin.text = f'adminurl={v["printer-uri-supported"]}'
                service.append(admin)

            fname = f'{self.prefix}{p}.service'
            if self.directory:
                fname = os.path.join(self.directory, fname)

            root_el = tree.getroot()
            if root_el is None:
                continue
            with open(fname, 'w', encoding='utf-8') as f:
                xmlstr = tostring(root_el, encoding='unicode')
                f.write('<?xml version="1.0" encoding="UTF-8"?>\n')
                f.write('<!DOCTYPE service-group SYSTEM "avahi-service.dtd">\n')
                f.write(xmlstr)
                f.write('\n')

            if self.verbose:
                sys.stderr.write(f'Created: {fname}{os.linesep}')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(
        description='Generate AirPrint Avahi service files'
    )
    parser.add_argument('-H', '--host', dest='hostname',
                        help='Hostname of CUPS server')
    parser.add_argument('-P', '--port', type=int, dest='port',
                        help='Port number of CUPS server')
    parser.add_argument('-u', '--user', dest='username',
                        help='Username to authenticate with against CUPS')
    parser.add_argument('-d', '--directory', dest='directory',
                        help='Directory to create service files')
    parser.add_argument('-v', '--verbose', action='store_true',
                        help='Print debugging information to STDERR')
    parser.add_argument('-p', '--prefix', default='AirPrint-',
                        help='Prefix all files with this string')
    parser.add_argument('-a', '--admin', action='store_true', dest='adminurl',
                        help='Include the printer URI as the adminurl')

    args = parser.parse_args()

    from getpass import getpass
    cups.setPasswordCB(getpass)

    if args.directory and not os.path.exists(args.directory):
        os.makedirs(args.directory)

    AirPrintGenerate(
        user=args.username,
        host=args.hostname,
        port=args.port,
        verbose=args.verbose,
        directory=args.directory,
        prefix=args.prefix,
        adminurl=args.adminurl,
    ).generate()
