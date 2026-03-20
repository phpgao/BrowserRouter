#!/usr/bin/env python3
"""Update appcast.xml with a new release item."""
import argparse
import os
import xml.etree.ElementTree as ET
from datetime import datetime, timezone

def main():
    parser = argparse.ArgumentParser(description="Update appcast.xml with a new version")
    parser.add_argument("--version", required=True, help="Marketing version (e.g. 1.0.2)")
    parser.add_argument("--build", default="", help="Build number")
    parser.add_argument("--signature", required=True, help="EdDSA signature from sign_update")
    parser.add_argument("--file", required=True, help="Path to the .zip file")
    parser.add_argument("--appcast", default="appcast.xml", help="Path to appcast.xml")
    args = parser.parse_args()

    file_size = os.path.getsize(args.file)
    pub_date = datetime.now(timezone.utc).strftime("%a, %d %b %Y %H:%M:%S +0000")
    download_url = f"https://github.com/phpgao/BrowserRouter/releases/download/v{args.version}/BrowserRouter.zip"

    # Register namespaces to preserve them
    ET.register_namespace("sparkle", "http://www.andymatuschak.org/xml-namespaces/sparkle")
    ET.register_namespace("dc", "http://purl.org/dc/elements/1.1/")

    tree = ET.parse(args.appcast)
    channel = tree.find("channel")

    # Build item XML manually for better formatting
    item = ET.SubElement(channel, "item")
    ET.SubElement(item, "title").text = f"Version {args.version}"
    ET.SubElement(item, "pubDate").text = pub_date

    sparkle_ns = "http://www.andymatuschak.org/xml-namespaces/sparkle"
    version_el = ET.SubElement(item, f"{{{sparkle_ns}}}version")
    version_el.text = args.build if args.build else "1"

    short_ver = ET.SubElement(item, f"{{{sparkle_ns}}}shortVersionString")
    short_ver.text = args.version

    min_sys = ET.SubElement(item, f"{{{sparkle_ns}}}minimumSystemVersion")
    min_sys.text = "13.0"

    enclosure = ET.SubElement(item, "enclosure")
    enclosure.set("url", download_url)
    enclosure.set("type", "application/octet-stream")
    enclosure.set(f"{{{sparkle_ns}}}edSignature", args.signature)
    enclosure.set("length", str(file_size))

    ET.indent(tree, space="    ")
    tree.write(args.appcast, encoding="utf-8", xml_declaration=True)
    print(f"Updated {args.appcast} with version {args.version}")

if __name__ == "__main__":
    main()
