extends Node
## SkytrakConnector - TCP server that listens for OpenConnect protocol connections.
## Acts as the "GSPro" server on port 921, receiving shot data from a launch monitor bridge.

signal shot_received(shot_data: Dictionary)
signal player_info_received(player_data: Dictionary)
signal connection_status_changed(connected: bool, client_info: String)

@export var listen_port: int = 9210
const BUFFER_SIZE: int = 4096

var tcp_server: TCPServer
var client_peer: StreamPeerTCP
var buffer: String = ""
var _shot_number: int = 0

func _ready() -> void:
	tcp_server = TCPServer.new()
	var err = tcp_server.listen(listen_port)
	if err != OK:
		push_error("[SkytrakConnector] Failed to listen on port %d: %s" % [listen_port, err])
		emit_signal("connection_status_changed", false, "Port %d unavailable" % listen_port)
	else:
		print("[SkytrakConnector] Listening on port %d (OpenConnect protocol)" % listen_port)
		emit_signal("connection_status_changed", true, "Listening on :%d" % listen_port)

func _process(_delta: float) -> void:
	if tcp_server == null:
		return

	# Check for new connections
	if tcp_server.is_connection_available():
		client_peer = tcp_server.take_connection()
		print("[SkytrakConnector] Client connected from %s" % str(client_peer.get_connected_host()))
		emit_signal("connection_status_changed", true, "Client connected")
		buffer = ""

	# Read data from client
	if client_peer and client_peer.get_status() == StreamPeerTCP.STATUS_CONNECTED:
		var available = client_peer.get_available_bytes()
		if available > 0:
			var data = client_peer.get_data(available)
			if data[0] == OK:
				buffer += data[1].get_string_from_utf8()
				_process_buffer()
			else:
				print("[SkytrakConnector] Error reading data: %s" % data[0])

func _process_buffer() -> void:
	while buffer.contains("\n"):
		var line: String = buffer.get_slice("\n", 0)
		buffer = buffer.substr(buffer.find("\n") + 1)
		line = line.strip_edges()
		if line.is_empty():
			continue
		_parse_message(line)

func _parse_message(line: String) -> void:
	var json = JSON.new()
	var err = json.parse(line)
	if err != OK:
		print("[SkytrakConnector] JSON parse error: %s" % json.get_error_message())
		return

	var msg: Dictionary = json.data

	# Check if it's a shot (has BallData)
	if msg.has("BallData"):
		_shot_number += 1
		msg["ShotNumber"] = _shot_number
		print("[SkytrakConnector] Shot #%d received:" % _shot_number)
		var bd: Dictionary = msg["BallData"]
		print("  Speed=%.1f VLA=%.1f HLA=%.1f" % [bd.get("Speed", 0), bd.get("VLA", 0), bd.get("HLA", 0)])
		print("  Spin=%.0f Axis=%.1f Carry=%.1f" % [bd.get("TotalSpin", 0), bd.get("SpinAxis", 0), bd.get("CarryDistance", 0)])
		emit_signal("shot_received", msg)
		_send_response(200, "Shot received")

	# Check if it's a player info message
	elif msg.has("Code") and msg["Code"] == 201:
		print("[SkytrakConnector] Player info: %s" % str(msg.get("Player", {})))
		emit_signal("player_info_received", msg.get("Player", {}))

func _send_response(code: int, message_text: String) -> void:
	if client_peer and client_peer.get_status() == StreamPeerTCP.STATUS_CONNECTED:
		var response := {"Code": code, "Message": message_text}
		var json_str := JSON.stringify(response) + "\n"
		client_peer.put_data(json_str.to_utf8_buffer())

func _exit_tree() -> void:
	if client_peer:
		client_peer.disconnect_from_host()
	if tcp_server:
		tcp_server.stop()
