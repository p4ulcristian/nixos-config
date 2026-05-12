#!/bin/bash
cd /Users/paul/pxe/http

echo "Starting HTTP server on port 8080..."
python3 -m http.server 8080 &
HTTP_PID=$!

echo "Starting dnsmasq..."
sudo nix-shell -p dnsmasq --run 'dnsmasq -d -C /Users/paul/pxe/dnsmasq.conf'

# When dnsmasq exits, kill HTTP server
kill $HTTP_PID 2>/dev/null
