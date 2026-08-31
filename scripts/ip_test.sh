#!/usr/bin/env bash
set -eu

URL="https://raw.githubusercontent.com/LancelotRar/best-cf-ips/refs/heads/main/best-cf-ipv4.txt"
WORKDIR="${GITHUB_WORKSPACE:-.}"
cd "$WORKDIR"

# Files
RAWLIST="iplist.raw"
IPS="ips.txt"
IPTEST="IPtest.txt"
IPOUT="IP.txt"

# Fetch list
curl -fsS "$URL" -o "$RAWLIST" || { echo "Failed to fetch $URL"; exit 1; }

# Extract IPv4 addresses (simple robust regex) and dedupe
grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}' "$RAWLIST" | awk '!seen[$0]++' > "$IPS"

# Prepare output
: > "$IPTEST"

# For each IP do 10 pings and record average (ms)
while IFS= read -r ip; do
  [ -z "$ip" ] && continue
  echo "Testing $ip ..."
  # Run ping with timeout to avoid hang. Use -4 to force IPv4.
  # timeout ensures the whole ping call does not exceed ~30s.
  avg=$(timeout 30 ping -4 -c 10 -W 3 -q "$ip" 2>/dev/null | awk -F'/' 'END{print $2}')
  if [ -z "$avg" ]; then
    # unreachable or timeout -> treat as very large latency
    avg=999999
  fi
  # Save IP and avg (as number)
  printf "%s %s\n" "$ip" "$avg" >> "$IPTEST"
done < "$IPS"

# Sort by latency numeric and pick top 10 lowest
sort -k2 -n "$IPTEST" | head -n 10 | awk '{print $1}' > "$IPOUT"

echo "Done. Results written to $IPTEST and $IPOUT"
