#!/usr/bin/env python3
import glob
import json
import socket
import subprocess
import sys
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 8085

stats = b"{}"


def read(path):
    try:
        with open(path) as f:
            return f.read().strip()
    except OSError:
        return None


def cpu_times():
    v = list(map(int, read("/proc/stat").splitlines()[0].split()[1:]))
    idle = v[3] + v[4]
    return idle, sum(v)


def hwmon_temp(names, labels=()):
    for hw in glob.glob("/sys/class/hwmon/hwmon*"):
        if read(hw + "/name") not in names:
            continue
        temps = {}
        for f in glob.glob(hw + "/temp*_input"):
            label = read(f.replace("_input", "_label")) or ""
            temps[label] = int(read(f)) / 1000
        for l in labels:
            if l in temps:
                return temps[l]
        if temps:
            return max(temps.values())
    return None


def gpu():
    try:
        out = subprocess.run(
            ["nvidia-smi", "--query-gpu=name,utilization.gpu,temperature.gpu", "--format=csv,noheader,nounits"],
            capture_output=True, text=True, timeout=2).stdout
        name, load, temp = [x.strip() for x in out.splitlines()[0].split(",")]
        return name, float(load), float(temp)
    except (OSError, IndexError, ValueError, subprocess.TimeoutExpired):
        pass

    for dev in glob.glob("/sys/class/drm/card*/device"):
        load = read(dev + "/gpu_busy_percent")
        if load is not None:
            return "AMD GPU", float(load), hwmon_temp({"amdgpu"}, ("edge",))
    return None, None, None


def meminfo():
    m = {}
    for line in read("/proc/meminfo").splitlines():
        k, v = line.split(":")
        m[k] = int(v.split()[0]) / 1024 / 1024
    return m["MemTotal"] - m["MemAvailable"], m["MemTotal"]


def loop():
    global stats
    idle0, total0 = cpu_times()
    while True:
        time.sleep(1)
        idle, total = cpu_times()
        cpu_load = 100 * (1 - (idle - idle0) / max(total - total0, 1))
        idle0, total0 = idle, total

        gpu_name, gpu_load, gpu_temp = gpu()
        used, ram_total = meminfo()
        stats = json.dumps({
            "pc": socket.gethostname(),
            "cpuLoad": cpu_load,
            "cpuTemp": hwmon_temp({"k10temp", "coretemp", "zenpower"}, ("Tctl", "Tdie", "Package id 0")),
            "gpuName": gpu_name,
            "gpuLoad": gpu_load,
            "gpuTemp": gpu_temp,
            "ramLoad": 100 * used / ram_total,
            "ramUsed": used,
            "ramTotal": ram_total,
        }).encode()


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        body = stats
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *args):
        pass


def discovery():
    # a app manda "DESKSTATS?" em broadcast e fica com o IP de quem responder
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    s.bind(("", PORT))
    while True:
        msg, addr = s.recvfrom(64)
        if msg == b"DESKSTATS?":
            s.sendto(f"DESKSTATS {PORT} {socket.gethostname()}".encode(), addr)


def lan_ip():
    # UDP não envia nada, só serve para o sistema escolher a interface da rede
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        s.connect(("8.8.8.8", 80))
        return s.getsockname()[0]
    except OSError:
        return "?"
    finally:
        s.close()


threading.Thread(target=loop, daemon=True).start()
threading.Thread(target=discovery, daemon=True).start()
print(f"Use este ip no seu dispositivo móvel: {lan_ip()}:{PORT}")
ThreadingHTTPServer(("0.0.0.0", PORT), Handler).serve_forever()
