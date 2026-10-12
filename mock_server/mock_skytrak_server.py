#!/usr/bin/env python3
"""
Mock Skytrak Server - Simulates Skytrak shot data via GSPro OpenConnect protocol.

Connects to a GSPro-compatible server (our Godot sim) on TCP :921 and sends
realistic shot data generated from actual Skytrak CSV export statistics.

Architecture:
    Godot Sim (TCP server, :921) <-- Mock Skytrak (this script, TCP client)

Usage:
    python3 mock_skytrak_server.py [--host 127.0.0.1] [--port 921] [--club DRIVER|7IRON|9IRON|ANY]
"""

import socket
import json
import time
import math
import random
import argparse
import threading
from dataclasses import dataclass, field
from typing import Optional


# ─── Shot statistics from real Skytrak CSV export ─────────────────────────────

@dataclass
class ClubStats:
    name: str
    ball_speed_mean: float
    ball_speed_std: float
    launch_mean: float
    launch_std: float
    backspin_mean: float
    backspin_std: float
    sidespin_mean: float
    sidespin_std: float
    side_deg_mean: float
    side_deg_std: float
    offline_mean: float
    offline_std: float
    carry_mean: float
    carry_std: float
    club_speed_mean: float
    club_speed_std: float


CLUB_STATS = {
    "DRIVER": ClubStats("DRIVER", 134.2, 17.9, 13.8, 8.6, 3247, 1733, 1040, 1090, -3.4, 5.4, 15.9, 34.8, 167.3, 71.2, 102.2, 8.6),
    "7IRON": ClubStats("7IRON", 100.0, 10.0, 8.0, 5.0, 4496, 2000, 524, 600, 1.1, 3.0, 9.0, 12.0, 86.0, 27.0, 82.0, 5.0),
    "9IRON": ClubStats("9IRON", 99.3, 6.4, 22.9, 4.0, 7553, 1503, 958, 918, 2.5, 3.8, 13.4, 14.1, 126.3, 13.0, 85.1, 3.6),
}


def clamp(val: float, lo: float, hi: float) -> float:
    return max(lo, min(hi, val))


def gauss(mean: float, std: float) -> float:
    return random.gauss(mean, std)


def generate_shot(club: ClubStats) -> dict:
    """Generate a realistic shot based on club statistics."""
    ball_speed = clamp(gauss(club.ball_speed_mean, club.ball_speed_std), 50, 180)
    launch = clamp(gauss(club.launch_mean, club.launch_std), 0.5, 45)
    backspin = clamp(gauss(club.backspin_mean, club.backspin_std), 500, 12000)
    sidespin = gauss(club.sidespin_mean, club.sidespin_std)
    side_deg = gauss(club.side_deg_mean, club.side_deg_std)
    offline = gauss(club.offline_mean, club.offline_std)
    club_speed = clamp(gauss(club.club_speed_mean, club.club_speed_std), 50, 130)

    # Compute derived values
    total_spin = math.sqrt(backspin**2 + sidespin**2)

    # HLA: horizontal launch angle (degrees, + = right, - = left)
    # Approximate from carry and offline
    carry = clamp(gauss(club.carry_mean, club.carry_std), 20, 350)
    hla = math.degrees(math.atan2(offline, carry)) if carry > 0 else 0.0

    # Spin axis: negative = draw (left-to-right for RH), positive = fade
    spin_axis = side_deg

    return {
        "DeviceID": "Skytrak Mock 1.0",
        "Units": "Yards",
        "ShotNumber": 0,  # Will be set by caller
        "APIversion": "1",
        "BallData": {
            "Speed": round(ball_speed, 1),
            "SpinAxis": round(spin_axis, 1),
            "TotalSpin": round(total_spin, 1),
            "BackSpin": round(backspin, 1),
            "SideSpin": round(sidespin, 1),
            "HLA": round(hla, 1),
            "VLA": round(launch, 1),
            "CarryDistance": round(carry, 1),
        },
        "ClubData": {
            "Speed": round(club_speed, 1),
            "AngleOfAttack": 0.0,
            "FaceToTarget": 0.0,
            "Lie": 0.0,
            "Loft": 0.0,
            "Path": 0.0,
            "SpeedAtImpact": round(club_speed, 1),
            "VerticalFaceImpact": 0.0,
            "HorizontalFaceImpact": 0.0,
            "ClosureRate": 0.0,
        },
        "ShotDataOptions": {
            "ContainsBallData": True,
            "ContainsClubData": True,
            "LaunchMonitorIsReady": True,
            "LaunchMonitorBallDetected": True,
            "IsHeartBeat": False,
        },
    }


class MockSkytrakServer:
    def __init__(self, host: str = "127.0.0.1", port: int = 921, club: str = "ANY"):
        self.host = host
        self.port = port
        self.club = club
        self.shot_number = 0
        self.running = False
        self.socket: Optional[socket.socket] = None

    def connect(self) -> bool:
        """Connect to the GSPro server."""
        try:
            self.socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            self.socket.settimeout(5.0)
            self.socket.connect((self.host, self.port))
            self.socket.settimeout(None)
            print(f"[MockSkytrak] Connected to {self.host}:{self.port}")
            return True
        except (ConnectionRefusedError, OSError) as e:
            print(f"[MockSkytrak] Connection failed: {e}")
            print(f"[MockSkytrak] Is the Godot sim running and listening on :{self.port}?")
            return False

    def send_shot(self, club_name: Optional[str] = None) -> bool:
        """Generate and send a shot to the server."""
        if not self.socket:
            print("[MockSkytrak] Not connected")
            return False

        if club_name is None:
            club_name = random.choice(list(CLUB_STATS.keys())) if self.club == "ANY" else self.club

        club = CLUB_STATS[club_name]
        shot = generate_shot(club)
        self.shot_number += 1
        shot["ShotNumber"] = self.shot_number

        try:
            msg = json.dumps(shot) + "\n"
            self.socket.sendall(msg.encode("utf-8"))
            print(f"[MockSkytrak] Sent shot #{self.shot_number} ({club_name}): "
                  f"Speed={shot['BallData']['Speed']}mph, "
                  f"Launch={shot['BallData']['VLA']}deg, "
                  f"Spin={shot['BallData']['TotalSpin']}rpm, "
                  f"Carry={shot['BallData']['CarryDistance']}yd")
            return True
        except OSError as e:
            print(f"[MockSkytrak] Send failed: {e}")
            self.running = False
            return False

    def receive_response(self, timeout: float = 2.0) -> Optional[dict]:
        """Receive a response from the server."""
        if not self.socket:
            return None
        try:
            self.socket.settimeout(timeout)
            data = self.socket.recv(4096)
            self.socket.settimeout(None)
            if not data:
                return None
            response = json.loads(data.decode("utf-8").strip())
            print(f"[MockSkytrak] Received: {response}")
            return response
        except (socket.timeout, json.JSONDecodeError):
            return None
        except OSError:
            return None

    def run_interactive(self):
        """Run in interactive mode - press Enter to send a shot, 'q' to quit."""
        if not self.connect():
            return

        self.running = True
        print(f"\n[MockSkytrak] Interactive mode. Press ENTER to hit a shot, 'q' to quit.")
        print(f"[MockSkytrak] Club: {self.club}\n")

        while self.running:
            try:
                user_input = input("> ").strip()
                if user_input.lower() == "q":
                    break
                elif user_input.upper() in CLUB_STATS:
                    self.send_shot(user_input.upper())
                elif user_input == "":
                    self.send_shot()
                elif user_input.upper() in ["DRIVER", "7IRON", "9IRON"]:
                    self.send_shot(user_input.upper())
                else:
                    print("Commands: [Enter]=random shot, DRIVER/7IRON/9IRON=specific club, q=quit")

                # Wait for response
                time.sleep(0.1)
                self.receive_response(timeout=1.0)

            except (EOFError, KeyboardInterrupt):
                break

        self.socket.close()
        print("[MockSkytrak] Disconnected")

    def run_auto(self, interval: float = 3.0, count: int = 0):
        """Run in auto mode - send shots at regular intervals."""
        if not self.connect():
            return

        self.running = True
        print(f"\n[MockSkytrak] Auto mode: sending a shot every {interval}s (0=unlimited)")
        print(f"[MockSkytrak] Press Ctrl+C to stop\n")

        sent = 0
        try:
            while self.running and (count == 0 or sent < count):
                self.send_shot()
                sent += 1
                time.sleep(interval)
                self.receive_response(timeout=1.0)
        except KeyboardInterrupt:
            pass

        self.socket.close()
        print(f"[MockSkytrak] Sent {sent} shots, disconnected")


def main():
    parser = argparse.ArgumentParser(description="Mock Skytrak Server (OpenConnect protocol)")
    parser.add_argument("--host", default="127.0.0.1", help="GSPro server host")
    parser.add_argument("--port", type=int, default=921, help="GSPro server port")
    parser.add_argument("--club", default="ANY", choices=["ANY", "DRIVER", "7IRON", "9IRON"])
    parser.add_argument("--mode", default="interactive", choices=["interactive", "auto"])
    parser.add_argument("--interval", type=float, default=3.0, help="Auto mode interval (seconds)")
    parser.add_argument("--count", type=int, default=0, help="Auto mode shot count (0=unlimited)")
    args = parser.parse_args()

    server = MockSkytrakServer(host=args.host, port=args.port, club=args.club)

    if args.mode == "interactive":
        server.run_interactive()
    else:
        server.run_auto(interval=args.interval, count=args.count)


if __name__ == "__main__":
    main()
