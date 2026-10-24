#!/usr/bin/env python3
"""Inspect/apply only the Boybrowse sync A/AAAA records. Never log credentials."""
import argparse
import ipaddress
import json
import pathlib
import subprocess
import urllib.request

ZONE = "d728c55b30fac9ba3fda06ae290a482a"
DOMAIN = "boybrowse-sync.freifick.net"
API = "https://api.cloudflare.com/client/v4"

class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, *args, **kwargs):
        raise RuntimeError("Refusing a Cloudflare API redirect")

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apply", action="store_true")
    options = parser.parse_args()
    credential = (pathlib.Path.home() / ".secrets/cloudflare/api-token").read_text().strip()
    opener = urllib.request.build_opener(NoRedirect)
    def request(path, payload=None, method=None):
        req = urllib.request.Request(API + path,
            data=json.dumps(payload).encode() if payload is not None else None,
            headers={"Authorization": "Bearer " + credential, "Content-Type": "application/json"},
            method=method)
        with opener.open(req, timeout=30) as response:
            result = json.load(response)
        if not result.get("success"):
            raise RuntimeError("Cloudflare API rejected the request")
        return result
    zone = request("/zones/" + ZONE)["result"]
    if zone["name"] != "freifick.net":
        raise RuntimeError("Unexpected Cloudflare zone")
    rows = []
    page = 1
    while True:
        result = request(f"/zones/{ZONE}/dns_records?per_page=100&page={page}")
        rows.extend(result["result"])
        if page >= result["result_info"]["total_pages"]:
            break
        page += 1
    existing = [row for row in rows if row["name"] == DOMAIN]
    if any(row["type"] not in ("A", "AAAA") for row in existing):
        raise RuntimeError("Target name already has a non-address record; refusing to replace it")
    interface = json.loads(subprocess.check_output(["ip", "-j", "address", "show", "dev", "ens18"]))
    addresses = [a for link in interface for a in link["addr_info"] if a["scope"] == "global"]
    for family, kind in (("inet", "A"), ("inet6", "AAAA")):
        values = [str(ipaddress.ip_address(a["local"])) for a in addresses if a["family"] == family]
        if len(values) != 1:
            raise RuntimeError(f"Expected one global {family} address on ens18")
        content = values[0]
        records = [row for row in existing if row["type"] == kind]
        if len(records) > 1:
            raise RuntimeError(f"Duplicate {kind} records at target name")
        if records and records[0]["content"] == content and not records[0]["proxied"]:
            print(f"{DOMAIN} {kind} already matches {content} (DNS-only)")
            continue
        print(f"{'Applying' if options.apply else 'Would apply'} {DOMAIN} {kind} {content} (DNS-only)")
        if options.apply:
            payload = {"type": kind, "name": DOMAIN, "content": content, "proxied": False, "ttl": 1}
            path = f"/zones/{ZONE}/dns_records"
            if records:
                request(path + "/" + records[0]["id"], payload, "PUT")
            else:
                request(path, payload, "POST")
    print("Other DNS records were left unchanged.")

if __name__ == "__main__":
    main()
