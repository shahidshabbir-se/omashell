#!/usr/bin/env python3
"""Stream approximate Mbps to the panel using Cloudflare's speed endpoints."""
import http.client
import sys
import threading
import time
import urllib.request

if len(sys.argv) != 2 or sys.argv[1] not in ("down", "up"):
    sys.exit("Usage: speedtest.py down|up")

direction = sys.argv[1]
stop = threading.Event()
lock = threading.Lock()
total = 0
errors = []


def add(n):
    global total
    with lock:
        total += n


def worker():
    try:
        while not stop.is_set():
            if direction == "down":
                request = urllib.request.Request(
                    "https://speed.cloudflare.com/__down?bytes=25000000",
                    headers={"Cache-Control": "no-cache", "User-Agent": "curl/8.0"})
                with urllib.request.urlopen(request, timeout=8) as response:
                    while not stop.is_set():
                        chunk = response.read(65536)
                        if not chunk:
                            break
                        add(len(chunk))
            else:
                connection = http.client.HTTPSConnection("speed.cloudflare.com", timeout=8)
                payload = bytes(1024 * 1024)
                try:
                    connection.request("POST", "/__up", payload, {"Content-Type": "application/octet-stream", "User-Agent": "curl/8.0"})
                    response = connection.getresponse()
                    response.read()
                    if response.status >= 400:
                        raise RuntimeError("Upload returned HTTP %d" % response.status)
                    add(len(payload))
                finally:
                    connection.close()
    except Exception as exc:
        with lock:
            errors.append(str(exc))


threads = [threading.Thread(target=worker, daemon=True) for _ in range(4)]
for thread in threads:
    thread.start()
start = time.monotonic()
previous_time = start
previous_total = 0
for _ in range(5):
    time.sleep(1)
    now = time.monotonic()
    with lock:
        current = total
    print("%.2f" % ((current - previous_total) * 8 / (now - previous_time) / 1000000), flush=True)
    previous_time, previous_total = now, current
stop.set()
if total == 0:
    print(errors[0] if errors else "No data transferred", file=sys.stderr)
    sys.exit(1)
