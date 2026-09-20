#!/usr/bin/env python3
"""Build the handbook's editable Excalidraw scenes."""
import json
import random
from pathlib import Path

HERE = Path(__file__).resolve().parent
SOURCE = HERE / "excalidraw"
SOURCE.mkdir(exist_ok=True)
random.seed(20260920)

INK = "#1e293b"
MUTED = "#475569"
BLUE = "#dbeafe"
GREEN = "#dcfce7"
PURPLE = "#ede9fe"
AMBER = "#fef3c7"
WHITE = "#ffffff"


class Scene:
    def __init__(self, name, width, height):
        self.name = name
        self.width = width
        self.height = height
        self.elements = []

    def add(self, kind, x, y, width, height, **values):
        element = {
            "id": f"e{len(self.elements) + 1}", "type": kind,
            "x": x, "y": y, "width": width, "height": height,
            "angle": 0, "strokeColor": INK,
            "backgroundColor": "transparent", "fillStyle": "solid",
            "strokeWidth": 2, "strokeStyle": "solid", "roughness": 1,
            "opacity": 100, "groupIds": [], "frameId": None,
            "roundness": None, "seed": random.randint(1, 2**30),
            "version": 1, "versionNonce": random.randint(1, 2**30),
            "isDeleted": False, "boundElements": None, "updated": 1,
            "link": None, "locked": False,
        }
        element.update(values)
        self.elements.append(element)
        return element

    def text(self, x, y, value, size=24, width=400, color=INK, align="left"):
        lines = value.split("\n")
        return self.add(
            "text", x, y, width, len(lines) * size * 1.25,
            text=value, originalText=value, fontSize=size, fontFamily=2,
            textAlign=align, verticalAlign="top", baseline=size,
            containerId=None, autoResize=True, lineHeight=1.25,
            strokeColor=color, roughness=0,
        )

    def box(self, x, y, width, height, title, body, fill=BLUE):
        self.add("rectangle", x, y, width, height,
                 backgroundColor=fill, roundness={"type": 3})
        self.text(x + 22, y + 20, title, 26, width - 44)
        self.text(x + 22, y + 62, body, 19, width - 44, MUTED)

    def arrow(self, points, label=None, label_x=0, label_y=0):
        x, y = points[0]
        relative = [[px - x, py - y] for px, py in points]
        self.add(
            "arrow", x, y,
            max(p[0] for p in relative) - min(p[0] for p in relative),
            max(p[1] for p in relative) - min(p[1] for p in relative),
            points=relative, lastCommittedPoint=None, startBinding=None,
            endBinding=None, startArrowhead=None, endArrowhead="arrow",
            elbowed=False,
        )
        if label:
            self.text(label_x, label_y, label, 17, 300, MUTED)

    def write(self, filename):
        payload = {
            "type": "excalidraw", "version": 2,
            "source": "https://excalidraw.com",
            "elements": self.elements,
            "appState": {
                "viewBackgroundColor": WHITE, "gridSize": None,
                "theme": "light", "name": self.name,
                "exportBackground": True, "exportWithDarkMode": False,
            },
            "files": {},
        }
        (SOURCE / filename).write_text(json.dumps(payload, indent=2) + "\n")


def vertical_scene(name, boxes, arrows, footer):
    scene = Scene(name, 920, 1080)
    title = name.replace(" reaches ", " reaches\n") if len(name) > 42 else name
    scene.text(45, 25, title, 30, 830)
    y = 120
    positions = []
    for title, body, fill in boxes:
        scene.box(110, y, 700, 150, title, body, fill)
        positions.append(y)
        y += 225
    for index, label in enumerate(arrows):
        start = positions[index] + 150
        scene.arrow([(460, start + 8), (460, start + 70)], label, 485, start + 28)
    scene.text(110, y - 35, footer, 18, 700, MUTED)
    return scene


vertical_scene(
    "How a private n8n request reaches the container",
    [
        ("Your browser", "An authorized device on the tailnet", PURPLE),
        ("Tailscale Serve on Mugiwara", "TLS ends here. Access stays private.", BLUE),
        ("Host loopback", "127.0.0.1:5678", AMBER),
        ("n8n container", "The application listens on port 5678", GREEN),
    ],
    ["HTTPS :8443", "HTTP on the same host", "Docker port mapping"],
    "The browser never connects directly to the container port.",
).write("n8n-network.excalidraw")

vertical_scene(
    "What survives container replacement",
    [
        ("Pinned n8n image", "Read-only application and runtime", PURPLE),
        ("Replaceable container", "Its writable layer is disposable", BLUE),
        ("Retained volume: n8n_data", "Mounted at /home/node/.n8n", GREEN),
        ("Durable application state", "Database, settings and encryption key", AMBER),
    ],
    ["creates", "reads and writes", "stores"],
    "Container recreation keeps the volume. down -v or disk loss can remove it.",
).write("container-volume.excalidraw")

vertical_scene(
    "Where your drawing becomes a backup",
    [
        ("Application container", "Delivers the editor, not a backup", BLUE),
        ("Drawing in your browser", "Browser state can be cleared or lost", PURPLE),
        ("Editable source file", ".excalidraw or .drawio", AMBER),
        ("Separate backup storage", "Copy the source, then reopen it", GREEN),
    ],
    ["loads editor code", "save to file", "copy and test"],
    "Keep the editable source even when you also export SVG or PNG.",
).write("drawing-files.excalidraw")

media = Scene("Private media stack: two traffic paths", 1540, 900)
media.text(45, 35, "Private media stack: two traffic paths", 38, 1200)
media.text(45, 88, "Blue is private administration. Green is outbound traffic through the VPN.", 20, 1200, MUTED)
media.box(45, 175, 250, 145, "Your device", "Tailnet browser", PURPLE)
media.box(375, 175, 280, 145, "Tailscale Serve", "HTTPS to host loopback", BLUE)
media.arrow([(300, 248), (370, 248)])
media.add("rectangle", 735, 125, 540, 485, backgroundColor="#ecfdf5", roundness={"type": 3}, strokeColor="#15803d", strokeWidth=3)
media.text(765, 150, "Gluetun network namespace", 30, 470, "#166534")
media.text(765, 195, "DNS, firewall and VPN tunnel", 19, 470, MUTED)
media.box(765, 250, 215, 120, "Sonarr / Radarr", "Automation", BLUE)
media.box(1030, 250, 215, 120, "Prowlarr", "Search", BLUE)
media.box(765, 420, 215, 120, "Transmission", "Downloads", AMBER)
media.box(1030, 420, 215, 120, "FlareSolverr", "Web challenges", AMBER)
media.arrow([(660, 248), (730, 248)])
media.box(1325, 300, 180, 130, "Internet", "VPN egress", GREEN)
media.arrow([(1275, 365), (1320, 365)], "VPN only", 1250, 325)
media.box(385, 700, 300, 130, "/downloads", "Shared host directory", AMBER)
media.box(800, 700, 360, 130, "/mnt/gdrive/Videos", "Media library through rclone", PURPLE)
media.arrow([(865, 545), (685, 695)], "download files", 650, 640)
media.arrow([(930, 545), (980, 695)], "import media", 940, 640)
media.write("media-stack.excalidraw")
