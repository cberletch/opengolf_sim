# Augusta National Golf Sim

A performant, low-poly golf simulator for Skytrak launch monitors, built with Godot 4.

## Architecture

```
Skytrak (Wine) → OpenSkyPlus2 → GSPro OpenConnect (TCP :921, JSON)
                                        ↓
                              Godot Sim (TCP server, receives shots)
```

## Quick Start

### 1. Install Godot 4

Download from [godotengine.org](https://godotengine.org/download) and extract to `/opt/godot/`.

```bash
# Add to PATH
export PATH="/opt/godot:$PATH"
```

### 2. Run the Simulator

```bash
godot --path /home/cole/repos/golf_sim
```

The sim listens on TCP port 921 for OpenConnect connections.

### 3. Test with Mock Data (no Skytrak needed)

In a separate terminal:

```bash
cd /home/cole/repos/golf_sim

# Interactive mode (press Enter to hit shots)
python3 mock_server/mock_skytrak_server.py --port 9210

# Auto mode (sends a shot every 3 seconds)
python3 mock_server/mock_skytrak_server.py --mode auto --interval 3

# Specific club
python3 mock_server/mock_skytrak_server.py --club DRIVER
```

### 4. Connect Real Skytrak

1. Start the Godot sim (listens on :921)
2. Start OpenSkyPlus2 (connects to :921)
3. Hit balls — data flows through automatically

## Project Structure

```
golf_sim/
├── project.godot              # Godot project config
├── scenes/
│   └── main.tscn              # Main scene
├── scripts/
│   ├── main.gd                # Scene orchestration
│   ├── skytrak_connector.gd   # TCP server, OpenConnect protocol
│   └── ball_flight.gd         # Physics simulation
├── data/
│   └── holes.json             # Augusta National hole data
├── mock_server/
│   ├── mock_skytrak_server.py # Mock data generator
│   └── test_openconnect.py    # Pipeline test
└── README.md
```

## OpenConnect Protocol

The sim speaks the [GSPro Open Connect v1](https://gsprogolf.com/GSProConnectV1.html) protocol:

- **TCP server** on port 921 (configurable)
- **Newline-delimited JSON**
- Receives shot data: `BallData` (Speed, VLA, HLA, Spin, Axis)
- Sends responses: `{"Code": 200}` on success

## Mock Data

The mock server generates realistic shots based on calculations from actual Skytrak CSV export data:

| Club | Ball Speed | Launch | Back Spin | Carry |
|------|-----------|--------|-----------|-------|
| Driver | 134 ± 18 mph | 14 ± 9° | 3247 ± 1733 rpm | 167 ± 71 yd |
| 7 Iron | 100 ± 10 mph | 8 ± 5° | 4496 ± 2000 rpm | 86 ± 27 yd |
| 9 Iron | 99 ± 6 mph | 23 ± 4° | 7553 ± 1503 rpm | 126 ± 13 yd |

## Performance

- **Renderer**: GL Compatibility (works on integrated graphics)
- **No shadows, no post-processing, no MSAA**
- **Low-poly meshes** with basic materials
- **60fps** on Intel HD Graphics / AMD Radeon integrated

## Next Steps

- [ ] Full Augusta National terrain generation
- [ ] Hole-by-hole gameplay
- [ ] Lie detection (fairway/rough/bunker/green)
- [ ] Wind effects
- [ ] Shot history and statistics
- [ ] Replay system
