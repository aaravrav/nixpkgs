import json
import os
import re
import socket
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request
from pathlib import Path


def request(url, data=None):
    req = urllib.request.Request(url, data=data)
    if data is not None:
        req.add_header("Content-Type", "application/octet-stream")
    return urllib.request.urlopen(req, timeout=5)


with tempfile.TemporaryDirectory() as directory:
    with socket.socket() as sock:
        sock.bind(("127.0.0.1", 0))
        port = sock.getsockname()[1]
    base = f"http://127.0.0.1:{port}"
    env = dict(os.environ, PORT=str(port))
    with open(Path(directory) / "server.log", "w+") as log:
        server = subprocess.Popen(
            sys.argv[1:], cwd=directory, env=env, stdout=log, stderr=log
        )
        try:
            for _ in range(100):
                if server.poll() is not None:
                    raise RuntimeError("Sola MPD exited before becoming ready")
                try:
                    with request(base) as response:
                        html = response.read().decode()
                    break
                except (urllib.error.URLError, TimeoutError):
                    time.sleep(0.1)
            else:
                raise TimeoutError("Sola MPD did not become ready")

            assert "<title>Sola MPD</title>" in html
            assets = re.findall(r'(?:src|href)="(/assets/[^"]+)"', html)
            assert assets, "No bundled frontend assets found"
            for asset in assets:
                with request(base + asset) as response:
                    assert response.status == 200
                    assert response.read()

            endpoint = base + "/api/configs/browser_state"
            with request(endpoint) as response:
                assert response.headers.get_content_type() == "application/octet-stream"
                state = response.read()
                assert state
            with request(endpoint, state) as response:
                assert response.status == 200
            with request(endpoint) as response:
                assert response.read() == state

            # Malformed protobuf must be rejected without terminating the server.
            try:
                request(endpoint, b"\xff")
            except urllib.error.HTTPError as error:
                assert error.code == 500
            else:
                raise AssertionError("Invalid configuration was accepted")
            with request(endpoint) as response:
                assert response.read() == state

            configs = list((Path(directory) / "db").glob("*.json"))
            assert configs, "Configuration was not saved in the working directory"
            for config in configs:
                json.loads(config.read_text())
            assert server.poll() is None
        finally:
            server.terminate()
            try:
                server.wait(timeout=10)
            except subprocess.TimeoutExpired:
                server.kill()
                server.wait()
            log.seek(0)
            print(log.read())
