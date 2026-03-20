#!/usr/bin/env python3
"""Update appcast.xml with a new release item."""
import argparse
import os
import re
import xml.etree.ElementTree as ET
from datetime import datetime, timezone


def parse_signature(raw_signature):
    """Parse sign_update output which may be in format:
    sparkle:edSignature="BASE64" length="12345"
    or just the raw base64 string."""
    match = re.search(r'edSignature="([^"]+)"', raw_signature)
    if match:
        return match.group(1)
    # Already a plain base64 string
    return raw_signature.strip()


def main():
    parser = argparse.ArgumentParser(description="Update appcast.xml with a new version")
    parser.add_argument("--version", required=True, help="Marketing version (e.g. 1.0.2)")
    parser.add_argument("--build", default="", help="Build number (if empty, derived from version)")
    parser.add_argument("--signature", required=True, help="EdDSA signature from sign_update")
    parser.add_argument("--file", required=True, help="Path to the .zip file")
    parser.add_argument("--appcast", default="appcast.xml", help="Path to appcast.xml")
    args = parser.parse_args()

    file_size = os.path.getsize(args.file)
    pub_date = datetime.now(timezone.utc).strftime("%a, %d %b %Y %H:%M:%S +0000")
    download_url = f"https://github.com/phpgao/BrowserRouter/releases/download/v{args.version}/BrowserRouter.zip"

    # Parse the signature (sign_update may output key=value format)
    signature = parse_signature(args.signature)

    # Build number: use provided value, or convert version like "1.0.2" -> "102"
    if args.build:
        build_number = args.build
    else:
        # Convert version string to a comparable integer: 1.0.2 -> 10002
        parts = args.version.split(".")
        parts = (parts + ["0", "0", "0"])[:3]  # pad to 3 parts
        build_number = str(int(parts[0]) * 10000 + int(parts[1]) * 100 + int(parts[2]))

    # Register namespaces to preserve them
    ET.register_namespace("sparkle", "http://www.andymatuschak.org/xml-namespaces/sparkle")
    ET.register_namespace("dc", "http://purl.org/dc/elements/1.1/")

    tree = ET.parse(args.appcast)
    channel = tree.find("channel")

    # Build item XML
    item = ET.SubElement(channel, "item")
    ET.SubElement(item, "title").text = f"Version {args.version}"
    ET.SubElement(item, "pubDate").text = pub_date

    sparkle_ns = "http://www.andymatuschak.org/xml-namespaces/sparkle"
    version_el = ET.SubElement(item, f"{{{sparkle_ns}}}version")
    version_el.text = build_number

    short_ver = ET.SubElement(item, f"{{{sparkle_ns}}}shortVersionString")
    short_ver.text = args.version

    min_sys = ET.SubElement(item, f"{{{sparkle_ns}}}minimumSystemVersion")
    min_sys.text = "13.0"

    enclosure = ET.SubElement(item, "enclosure")
    enclosure.set("url", download_url)
    enclosure.set("type", "application/octet-stream")
    enclosure.set(f"{{{sparkle_ns}}}edSignature", signature)
    enclosure.set("length", str(file_size))

    ET.indent(tree, space="    ")
    tree.write(args.appcast, encoding="utf-8", xml_declaration=True)
    print(f"Updated {args.appcast} with version {args.version} (build {build_number})")


if __name__ == "__main__":
    main()
