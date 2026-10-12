#!/usr/bin/env python3
"""
Test script - verifies the OpenConnect protocol handshake and shot flow.

Starts a mock server that:
1. Listens on :921 (like GSPro would)
2. Accepts a connection from the mock Skytrak client
3. Receives shots and sends 200 OK responses

This lets you test the full pipeline without Godot running.
"""

import socket
import json
import threading
import sys
import time

# Add parent dir to path so we can import the mock server
sys.path.insert(0, "/home/cole/repos/golf_sim/mock_server")
from mock_skytrak_server import MockSkytrakServer, CLUB_STATS, generate_shot


def run_test_server(port: int = 9210):
    """Run a simple OpenConnect-compatible test server."""
    server_sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server_sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server_sock.bind(("127.0.0.1", port))
    server_sock.listen(1)
    print(f"[TestServer] Listening on 127.0.0.1:{port}")

    conn, addr = server_sock.accept()
    print(f"[TestServer] Client connected from {addr}")

    # Send player info first
    player_info = {
        "Code": 201,
        "Message": "GSPro Player Information",
        "Player": {"Handed": "RH", "Club": "DR"}
    }
    conn.sendall((json.dumps(player_info) + "\n").encode("utf-8"))
    print(f"[TestServer] Sent player info: {player_info}")

    buffer = ""
    while True:
        data = conn.recv(4096)
        if not data:
            break
        buffer += data.decode("utf-8")

        while "\n" in buffer:
            line, buffer = buffer.split("\n", 1)
            if line.strip():
                try:
                    msg = json.loads(line.strip())
                    print(f"[TestServer] Received shot #{msg.get('ShotNumber', '?')}:")
                    bd = msg.get("BallData", {})
                    print(f"  Speed={bd.get('Speed')} VLA={bd.get('VLA')} HLA={bd.get('HLA')}")
                    print(f"  Spin={bd.get('TotalSpin')} Axis={bd.get('SpinAxis')} Carry={bd.get('CarryDistance')}")

                    # Send 200 OK
                    response = {"Code": 200, "Message": "Shot received"}
                    conn.sendall((json.dumps(response) + "\n").encode("utf-8"))
                except json.JSONDecodeError as e:
                    print(f"[TestServer] Bad JSON: {e}")

    conn.close()
    server_sock.close()
    print("[TestServer] Disconnected")


if __name__ == "__main__":
    if "--server" in sys.argv:
        run_test_server()
    else:
        # Run both server and client in one process for quick testing
        import multiprocessing
        server_proc = multiprocessing.Process(target=run_test_server, daemon=True)
        server_proc.start()
        time.sleep(0.5)

        # Send a few test shots
        from mock_skytrak_server import MockSkytrakServer
        client = MockSkytrakServer(port=9210)
        if client.connect():
            for _ in range(3):
                client.send_shot()
                time.sleep(0.5)
                client.receive_response(timeout=1.0)
            client.socket.close()

        server_proc.terminate()
        print("\n[Test] Pipeline test complete!")
