"""Generates map/Map.model.json (a Rojo model) for Rat Raid.

House layout (top-down, +X east, +Z north/backyard). Floor top is y = 0.4.

        z=90  ------------- picket fence --------------
              |  pool (-30,65)        RAT DEN (10,56) |
        z=35  ======= back wall (rat holes, back door) ==
              | BEDROOM        |  DINING (table)       |
        z=5   |---- door ------|       (open)          |
              | LIVING ROOM    |-- half wall --|       |
              |                |  KITCHEN (checker)    |
        z=-35 ====== front wall (front door) ===========
             x=-50            x=0                    x=50
"""
import json
import math
import os

FLOOR_Y = 0.4
WALL_H = 14.0
parts = []          # top-level children of Map
folders = {}


def rgb(r, g, b):
    return [r / 255, g / 255, b / 255]


C = {
    "wall": rgb(150, 200, 235), "wallOut": rgb(240, 240, 235), "wood": rgb(140, 85, 50),
    "floor": rgb(150, 90, 55), "white": rgb(245, 245, 245), "black": rgb(35, 35, 40),
    "granite": rgb(70, 70, 75), "cabinet": rgb(235, 235, 225), "grass": rgb(90, 170, 70),
    "fence": rgb(250, 250, 250), "dirt": rgb(110, 75, 45), "glass": rgb(190, 230, 255),
    "sofa": rgb(70, 110, 180), "red": rgb(200, 60, 60), "yellow": rgb(255, 210, 60),
    "roof": rgb(120, 60, 50), "metal": rgb(170, 175, 180), "water": rgb(70, 170, 240),
    "pink": rgb(240, 170, 190), "green": rgb(60, 140, 60), "trunk": rgb(100, 70, 40),
    "rug": rgb(200, 90, 60), "rug2": rgb(60, 160, 170), "tile": rgb(225, 225, 225),
}


def cframe(x, y, z, yaw_deg=0.0):
    c, s = math.cos(math.radians(yaw_deg)), math.sin(math.radians(yaw_deg))
    return {"CFrame": {"position": [x, y, z], "orientation": [[c, 0, s], [0, 1, 0], [-s, 0, c]]}}


def part(name, size, pos, color, material="SmoothPlastic", yaw=0.0, shape=None, cls="Part",
         transparency=0.0, collide=True, children=None, extra=None):
    props = {
        "Anchored": True,
        "Size": list(size),
        "CFrame": cframe(*pos, yaw),
        "Color": color,
        "Material": material,
        "TopSurface": "Smooth",
        "BottomSurface": "Smooth",
    }
    if shape:
        props["Shape"] = shape
    if transparency:
        props["Transparency"] = transparency
    if not collide:
        props["CanCollide"] = False
    if extra:
        props.update(extra)
    node = {"Name": name, "ClassName": cls, "Properties": props}
    if children:
        node["Children"] = children
    return node


def box(name, x1, y1, z1, x2, y2, z2, color, material="SmoothPlastic", **kw):
    """Part from min/max corners."""
    size = (abs(x2 - x1), abs(y2 - y1), abs(z2 - z1))
    pos = ((x1 + x2) / 2, (y1 + y2) / 2, (z1 + z2) / 2)
    return part(name, size, pos, color, material, **kw)


def add(folder, node):
    folders.setdefault(folder, []).append(node)
    return node


def light(rng=40, brightness=1.2, color=None):
    p = {"Range": rng, "Brightness": brightness, "Shadows": True}
    if color:
        p["Color"] = color
    return {"Name": "Light", "ClassName": "PointLight", "Properties": p}


def billboard(textv, color, size=(8, 2), offset=3, max_dist=150, always_on_top=False):
    return {
        "Name": "Sign", "ClassName": "BillboardGui",
        "Properties": {
            "Size": {"UDim2": [[0, int(size[0] * 30)], [0, int(size[1] * 30)]]},
            "StudsOffset": [0, offset, 0], "MaxDistance": max_dist, "AlwaysOnTop": always_on_top,
        },
        "Children": [{
            "Name": "Text", "ClassName": "TextLabel",
            "Properties": {
                "Size": {"UDim2": [[1, 0], [1, 0]]}, "BackgroundTransparency": 1, "Text": textv,
                "TextScaled": True, "Font": "LuckiestGuy", "TextColor3": color, "TextStrokeTransparency": 0,
            },
        }],
    }


# ---------------------------------------------------------------- walls
def wall(name, axis, fixed, a1, a2, openings=(), color=None, thick=1.0, height=WALL_H, base=FLOOR_Y, folder="House"):
    """axis 'x' = wall runs along X at z=fixed; 'z' = runs along Z at x=fixed.
    openings: (center, width, bottom, top, kind) kind in door/hole/window."""
    color = color or C["wall"]
    top = base + height
    ops = sorted(openings, key=lambda o: o[0])

    def seg(n, s1, s2, y1, y2, col=color, mat="SmoothPlastic", **kw):
        if s2 - s1 <= 0.01 or y2 - y1 <= 0.01:
            return
        if axis == "x":
            add(folder, box(n, s1, y1, fixed - thick / 2, s2, y2, fixed + thick / 2, col, mat, **kw))
        else:
            add(folder, box(n, fixed - thick / 2, y1, s1, fixed + thick / 2, y2, s2, col, mat, **kw))

    cur = a1
    for (c, w, ob, ot, kind) in ops:
        s1, s2 = c - w / 2, c + w / 2
        seg(name, cur, s1, base, top)
        seg(name + "Lintel", s1, s2, base + ot, top)
        if ob > 0:
            seg(name + "Sill", s1, s2, base, base + ob)
        if kind == "window":
            seg(name + "Glass", s1, s2, base + ob, base + ot, C["glass"], "Glass", transparency=0.55)
        cur = s2
    seg(name, cur, a2, base, top)


DOOR = lambda c, w=8: (c, w, 0, 10, "door")
HOLE = lambda c: (c, 3, 0, 3, "hole")
WINDOW = lambda c, w=8: (c, w, 4, 10, "window")


def build_house():
    # Ground and floor
    add("Ground", part("Grass", (420, 2, 420), (0, -1, 20), C["grass"], "Grass"))
    add("House", box("Floor", -50, 0, -35, 50, FLOOR_Y, 35, C["floor"], "WoodPlanks"))
    # Kitchen checkerboard (x 0..50, z -35..0)
    for i in range(10):
        for j in range(7):
            col = C["white"] if (i + j) % 2 == 0 else C["black"]
            x1, z1 = i * 5, -35 + j * 5
            add("House", box("KitchenTile", x1, FLOOR_Y, z1, x1 + 5, FLOOR_Y + 0.02, z1 + 5, col, collide=False))
    # Ceiling / roof
    add("House", box("Ceiling", -51, FLOOR_Y + WALL_H, -36, 51, FLOOR_Y + WALL_H + 1, 36, C["white"]))
    add("House", box("Roof", -53, FLOOR_Y + WALL_H + 1, -38, 53, FLOOR_Y + WALL_H + 2, 38, C["roof"], "Slate"))

    # Exterior walls
    wall("FrontWall", "x", -35, -50.5, 50.5, [WINDOW(-38), DOOR(-10), WINDOW(20, 10), WINDOW(38)], C["wallOut"])
    wall("BackWall", "x", 35, -50.5, 50.5, [HOLE(-30), WINDOW(-18), HOLE(10), DOOR(25), WINDOW(40)], C["wallOut"])
    wall("WestWall", "z", -50, -34.5, 34.5, [HOLE(-20), WINDOW(-5), WINDOW(22)], C["wallOut"])
    wall("EastWall", "z", 50, -34.5, 34.5, [WINDOW(-15), WINDOW(20, 10)], C["wallOut"])
    # Interior walls
    wall("MidWall", "z", 0, -34.5, 34.5, [HOLE(-30), DOOR(-15), DOOR(20), HOLE(30)])
    wall("BedroomWall", "x", 5, -49.5, -0.5, [HOLE(-40), DOOR(-10)], C["pink"])
    wall("KitchenHalfWall", "x", 0, 0.5, 18, [], height=5)

    # Ceiling lights
    for (x, z) in [(-25, -15), (-25, 20), (25, -15), (25, 18), (45, 0)]:
        add("House", part("CeilingLamp", (2.5, 0.4, 2.5), (x, FLOOR_Y + WALL_H - 0.2, z), C["white"], "Neon",
                          children=[light(45, 1.3, rgb(255, 240, 210))]))


food_spawns = []


def food_spot(x, surface_y, z):
    food_spawns.append(part("FoodSpawn", (1, 0.2, 1), (x, surface_y + 0.1, z), C["yellow"],
                            transparency=1, collide=False, extra={"CanQuery": False, "CanTouch": False}))


def table(name, cx, cz, w, d, h, color, folder="Furniture", top_mat="Wood"):
    """Legs + top. Returns surface y."""
    top = FLOOR_Y + h
    add(folder, box(name + "Top", cx - w / 2, top - 0.6, cz - d / 2, cx + w / 2, top, cz + d / 2, color, top_mat))
    for sx in (-1, 1):
        for sz in (-1, 1):
            lx, lz = cx + sx * (w / 2 - 0.6), cz + sz * (d / 2 - 0.6)
            add(folder, box(name + "Leg", lx - 0.3, FLOOR_Y, lz - 0.3, lx + 0.3, top - 0.6, lz + 0.3, color, top_mat))
    return top


def chair(cx, cz, yaw_back_dir):
    seat = FLOOR_Y + 2.4
    add("Furniture", box("ChairSeat", cx - 1.3, seat - 0.4, cz - 1.3, cx + 1.3, seat, cz + 1.3, C["wood"], "Wood"))
    for sx in (-1, 1):
        for sz in (-1, 1):
            lx, lz = cx + sx * 1, cz + sz * 1
            add("Furniture", box("ChairLeg", lx - 0.2, FLOOR_Y, lz - 0.2, lx + 0.2, seat - 0.4, lz + 0.2, C["wood"], "Wood"))
    dx, dz = yaw_back_dir
    bx, bz = cx + dx * 1.2, cz + dz * 1.2
    hw = 1.3
    if dx != 0:
        add("Furniture", box("ChairBack", bx - 0.2, seat, cz - hw, bx + 0.2, seat + 3, cz + hw, C["wood"], "Wood"))
    else:
        add("Furniture", box("ChairBack", cx - hw, seat, bz - 0.2, cx + hw, seat + 3, bz + 0.2, C["wood"], "Wood"))


def shelf_unit(name, x1, z1, x2, z2, levels, color, front=1):
    """Staircase shelving against an X-facing wall so rats can climb it.
    front=+1 means the open side faces +X (shelf fronts at x2), -1 faces -X.
    Each higher shelf is shallower, so every shelf has an uncovered lip to jump from.
    Returns [(surface_y, food_x)] per shelf."""
    height = levels[-1] + 1.5
    add("Furniture", box(name + "Side", x1, FLOOR_Y, z1, x2, FLOOR_Y + height, z1 + 0.4, color, "Wood"))
    add("Furniture", box(name + "Side", x1, FLOOR_Y, z2 - 0.4, x2, FLOOR_Y + height, z2, color, "Wood"))
    depth = abs(x2 - x1)
    n = len(levels)
    out = []
    for k, lv in enumerate(levels):
        y = FLOOR_Y + lv
        d = depth * (n - k) / n
        if front == 1:
            sx1, sx2 = x1, x1 + d
            food_x = sx2 - 0.8
        else:
            sx1, sx2 = x2 - d, x2
            food_x = sx1 + 0.8
        add("Furniture", box(name + "Shelf", sx1, y - 0.3, z1 + 0.4, sx2, y, z2 - 0.4, color, "Wood"))
        out.append((y, food_x))
    return out


def build_kitchen():
    # Counter along east wall z -27..-3
    add("Furniture", box("Cabinets", 45, FLOOR_Y, -27, 50, FLOOR_Y + 4, -3, C["cabinet"]))
    add("Furniture", box("Countertop", 44.6, FLOOR_Y + 4, -27.2, 50, FLOOR_Y + 4.4, -2.8, C["granite"], "Granite"))
    ctop = FLOOR_Y + 4.4
    add("Furniture", box("Stove", 45.2, ctop, -15, 49.8, ctop + 0.1, -10, C["black"]))
    for bz in (-14, -11):
        add("Furniture", part("Burner", (0.2, 1.6, 1.6), (47.5, ctop + 0.15, bz), C["red"], "Neon",
                              shape="Cylinder", extra={"CFrame": {"CFrame": {"position": [47.5, ctop + 0.15, bz],
                                                                             "orientation": [[0, -1, 0], [1, 0, 0], [0, 0, 1]]}}}))
    add("Furniture", box("Microwave", 46, ctop, -7, 49.5, ctop + 2.2, -4, C["black"]))
    for z in (-21, -17, -8):
        food_spot(47.3, ctop, z)
    food_spot(47.8, ctop + 2.2, -5.5)  # on microwave
    # Fridge SE corner
    add("Furniture", box("Fridge", 44, FLOOR_Y, -34.5, 50, FLOOR_Y + 11, -28.5, C["white"], "Metal"))
    add("Furniture", box("FridgeHandle", 43.7, FLOOR_Y + 5, -30, 44, FLOOR_Y + 9, -29.6, C["metal"], "Metal"))
    # Cereal box on the counter = stepping stone up to the fridge top
    add("Furniture", box("CerealBox", 46, ctop, -26.5, 49, ctop + 3.6, -24.8, C["yellow"]))
    food_spot(47, FLOOR_Y + 11, -31.5)
    # Island with stools (steps for rats)
    add("Furniture", box("Island", 18, FLOOR_Y, -18, 32, FLOOR_Y + 4, -12, C["cabinet"]))
    add("Furniture", box("IslandTop", 17.5, FLOOR_Y + 4, -18.5, 32.5, FLOOR_Y + 4.4, -11.5, C["granite"], "Granite"))
    for x in (20, 25, 30):
        add("Furniture", part("Stool", (2.6, 2.2, 2.2), (x, FLOOR_Y + 1.1, -9.5), C["red"],
                              shape="Cylinder", extra={"CFrame": {"CFrame": {"position": [x, FLOOR_Y + 1.3, -9.5],
                                                                             "orientation": [[0, -1, 0], [1, 0, 0], [0, 0, 1]]}}}))
    food_spot(21, FLOOR_Y + 4.4, -15)
    food_spot(29, FLOOR_Y + 4.4, -15)
    # Pantry shelves near the mid wall
    sh = shelf_unit("Pantry", 0.5, -10, 6.5, -1.5, [2, 4.5, 7, 9.5], C["wood"], front=1)
    food_spot(sh[1][1], sh[1][0], -9)
    food_spot(sh[3][1], sh[3][0], -6)
    # Trash can
    add("Furniture", part("TrashCan", (3, 2.4, 2.4), (8, FLOOR_Y + 1.5, -32), C["metal"], "Metal",
                          shape="Cylinder", extra={"CFrame": {"CFrame": {"position": [8, FLOOR_Y + 1.5, -32],
                                                                         "orientation": [[0, -1, 0], [1, 0, 0], [0, 0, 1]]}}}))
    food_spot(11, FLOOR_Y, -31)  # dropped snack on the floor


def build_dining():
    top = table("DiningTable", 28, 18, 16, 8, 4, C["wood"])
    for x in (22, 28, 34):
        chair(x, 12, (0, -1))
        chair(x, 24, (0, 1))
    for (x, z) in [(22, 18), (28, 17), (34, 19)]:
        food_spot(x, top, z)
    add("Furniture", box("DiningRug", 16, FLOOR_Y, 10, 40, FLOOR_Y + 0.05, 26, C["rug2"], "Fabric", collide=False))
    # China cabinet against east wall
    sh = shelf_unit("ChinaCabinet", 45, 6, 49.5, 16, [3, 5.5, 8], C["wood"], front=-1)
    food_spot(sh[2][1], sh[2][0], 11)


def build_living():
    # Sofa facing north along front wall
    add("Furniture", box("SofaBase", -38, FLOOR_Y, -33, -22, FLOOR_Y + 2.2, -28, C["sofa"], "Fabric"))
    add("Furniture", box("SofaBack", -38, FLOOR_Y + 2.2, -33.5, -22, FLOOR_Y + 5, -32, C["sofa"], "Fabric"))
    add("Furniture", box("SofaArm", -39, FLOOR_Y, -33, -38, FLOOR_Y + 3.4, -28, C["sofa"], "Fabric"))
    add("Furniture", box("SofaArm", -22, FLOOR_Y, -33, -21, FLOOR_Y + 3.4, -28, C["sofa"], "Fabric"))
    top = table("CoffeeTable", -30, -21, 8, 4, 2.2, C["wood"])
    food_spot(-30, top, -21)
    add("Furniture", box("LivingRug", -42, FLOOR_Y, -27, -18, FLOOR_Y + 0.05, -13, C["rug"], "Fabric", collide=False))
    # TV stand against bedroom wall
    add("Furniture", box("TVStand", -37, FLOOR_Y, 1.5, -23, FLOOR_Y + 3, 4.4, C["wood"], "Wood"))
    add("Furniture", box("TV", -35, FLOOR_Y + 3, 3.4, -25, FLOOR_Y + 9, 3.9, C["black"]))
    food_spot(-36, FLOOR_Y + 3, 2.4)
    # Bookshelf on west wall (climbable)
    sh = shelf_unit("Bookshelf", -49.5, -16, -44.5, -8, [2.5, 5, 7.5, 10], C["wood"], front=1)
    food_spot(sh[3][1], sh[3][0], -12)
    # Grandfather clock
    add("Furniture", box("Clock", -49.4, FLOOR_Y, 0, -47.4, FLOOR_Y + 10, 3, C["wood"], "Wood"))


def build_bedroom():
    add("Furniture", box("BedFrame", -42, FLOOR_Y, 18, -30, FLOOR_Y + 2, 34, C["wood"], "Wood"))
    add("Furniture", box("Mattress", -41.8, FLOOR_Y + 2, 18.2, -30.2, FLOOR_Y + 3.4, 33, C["white"], "Fabric"))
    add("Furniture", box("Blanket", -41.9, FLOOR_Y + 3.4, 18.1, -30.1, FLOOR_Y + 3.6, 28, C["red"], "Fabric"))
    add("Furniture", box("Headboard", -42, FLOOR_Y, 33, -30, FLOOR_Y + 7, 34.4, C["wood"], "Wood"))
    food_spot(-36, FLOOR_Y + 3.6, 22)
    add("Furniture", box("Nightstand", -29, FLOOR_Y, 30.5, -25, FLOOR_Y + 3, 34.4, C["wood"], "Wood"))
    food_spot(-27, FLOOR_Y + 3, 32.5)
    add("Furniture", box("Dresser", -14, FLOOR_Y, 31, -4, FLOOR_Y + 4.2, 34.4, C["white"]))
    food_spot(-9, FLOOR_Y + 4.2, 32.7)


def build_cage():
    cx, cz = 30, -30
    kids = []
    kids.append(box("CageBase", cx - 3, FLOOR_Y, cz - 3, cx + 3, FLOOR_Y + 0.4, cz + 3, C["metal"], "Metal"))
    kids.append(box("CageTop", cx - 3, FLOOR_Y + 5, cz - 3, cx + 3, FLOOR_Y + 5.4, cz + 3, C["metal"], "Metal"))
    for i in range(7):
        t = -3 + i
        for (bx, bz) in [(cx + t, cz - 3), (cx + t, cz + 3), (cx - 3, cz + t), (cx + 3, cz + t)]:
            kids.append(box("Bar", bx - 0.1, FLOOR_Y + 0.4, bz - 0.1, bx + 0.1, FLOOR_Y + 5, bz + 0.1, C["metal"], "Metal"))
    kids.append(part("CageSpot", (1, 1, 1), (cx, FLOOR_Y + 1.5, cz), C["yellow"], transparency=1, collide=False,
                     extra={"CanQuery": False, "CanTouch": False},
                     children=[billboard("RAT CAGE", rgb(255, 90, 90), (6, 1.5), 4.5, 120)]))
    kids.append(part("CageExit", (1, 1, 1), (cx - 6, FLOOR_Y + 1, cz + 6), C["yellow"], transparency=1,
                     collide=False, extra={"CanQuery": False, "CanTouch": False}))
    parts.append({"Name": "Cage", "ClassName": "Model", "Children": kids})


def build_backyard():
    # Back porch step
    add("Yard", box("Porch", 15, 0, 35.5, 35, FLOOR_Y, 42, C["wood"], "WoodPlanks"))
    # Picket fence x -60..60, z 36..90 (house closes the south side)
    def fence_line(x1, z1, x2, z2):
        length = math.hypot(x2 - x1, z2 - z1)
        n = int(length / 2)
        for i in range(n + 1):
            t = i / max(n, 1)
            x, z = x1 + (x2 - x1) * t, z1 + (z2 - z1) * t
            add("Yard", part("Picket", (0.8, 4.5, 0.4), (x, 2.25, z), C["fence"], yaw=0 if z1 == z2 else 90))
        add("Yard", box("Rail", min(x1, x2) - 0.2, 2.6, min(z1, z2) - 0.2, max(x1, x2) + 0.2, 3.1, max(z1, z2) + 0.2,
                        C["fence"]))
    fence_line(-60, 90, 60, 90)
    fence_line(-60, 36, -60, 90)
    fence_line(60, 36, 60, 90)
    fence_line(-60, 36, -50, 36)
    fence_line(50, 36, 60, 36)

    # Pool
    add("Yard", box("PoolEdge", -46, 0, 54, -14, 0.6, 56, C["tile"]))
    add("Yard", box("PoolEdge", -46, 0, 76, -14, 0.6, 78, C["tile"]))
    add("Yard", box("PoolEdge", -46, 0, 56, -44, 0.6, 76, C["tile"]))
    add("Yard", box("PoolEdge", -16, 0, 56, -14, 0.6, 76, C["tile"]))
    add("Yard", box("PoolWater", -44, 0, 56, -16, 0.35, 76, C["water"], "Glass", transparency=0.25, collide=False))

    # Trees outside the fence
    for (x, z) in [(-75, 50), (-80, 80), (-70, 105), (-30, 108), (10, 110), (45, 106), (78, 92), (80, 60), (76, 30),
                   (-78, 20), (80, -10), (-80, -20)]:
        add("Scenery", part("Trunk", (8, 2, 2), (x, 4, z), C["trunk"], "Wood", shape="Cylinder",
                            extra={"CFrame": {"CFrame": {"position": [x, 4, z],
                                                         "orientation": [[0, -1, 0], [1, 0, 0], [0, 0, 1]]}}}))
        add("Scenery", part("Leaves", (11, 11, 11), (x, 11, z), C["green"], "Grass", shape="Ball"))

    # Path to the front door
    add("Scenery", box("FrontPath", -14, 0, -60, -6, 0.1, -35, C["tile"], "Concrete"))


def build_den():
    """Rat den: a log pile with rat-sized gaps homeowners can't fit through."""
    x1, x2, z1, z2 = 4.0, 16.0, 50.0, 62.0
    h = 3.0
    log = C["dirt"]
    # South wall with entrance at x=10, east wall with entrance at z=56, west and north solid
    wall("DenWall", "x", z1, x1, x2, [(10, 3, 0, 2.6, "hole")], log, thick=1, height=h, base=0, folder="Den")
    wall("DenWall", "x", z2, x1, x2, [], log, thick=1, height=h, base=0, folder="Den")
    wall("DenWall", "z", x1, z1, z2, [], log, thick=1, height=h, base=0, folder="Den")
    wall("DenWall", "z", x2, z1, z2, [(56, 3, 0, 2.6, "hole")], log, thick=1, height=h, base=0, folder="Den")
    add("Den", box("DenRoof", x1 - 1, h, z1 - 1, x2 + 1, h + 0.8, z2 + 1, C["dirt"], "Wood"))
    add("Den", part("DirtMound", (10, 10, 10), (10, 0, 67), C["dirt"], "Ground", shape="Ball"))
    add("Den", box("DenFloor", x1 + 0.5, 0, z1 + 0.5, x2 - 0.5, 0.15, z2 - 0.5, C["yellow"], "Fabric", collide=False))
    zone = part("DenZone", (11, 6, 11), (10, 3, 56), C["yellow"], transparency=1, collide=False,
                extra={"CanQuery": False}, children=[light(16, 2, rgb(255, 220, 120))])
    sign = part("DenSignPost", (0.5, 6, 0.5), (10, 3, 47), C["wood"], "Wood",
                children=[billboard("RAT DEN", rgb(255, 217, 59), (8, 2), 4.5, 250)])
    den_folder = folders.pop("Den")
    parts.append({"Name": "RatDen", "ClassName": "Model", "Children": den_folder + [zone, sign]})


def build_lobby():
    y = 120.0
    kids = [
        box("LobbyFloor", -30, y - 2, -170, 30, y, -130, C["floor"], "WoodPlanks"),
        box("LobbyWall", -31, y, -171, 31, y + 12, -170, C["wall"]),
        box("LobbyWall", -31, y, -130, 31, y + 12, -129, C["wall"]),
        box("LobbyWall", -31, y, -170, -30, y + 12, -130, C["wall"]),
        box("LobbyWall", 30, y, -170, 31, y + 12, -130, C["wall"]),
        part("LobbySpawn", (10, 1, 10), (0, y + 0.5, -150), C["yellow"], cls="SpawnLocation",
             extra={"Neutral": True, "Duration": 0}),
        part("TitleBoard", (40, 10, 1), (0, y + 7, -169), C["sofa"], children=[
            billboard("RAT RAID!", rgb(255, 255, 255), (20, 4), 0, 300, False)]),
    ]
    for (x, z) in [(-15, -150), (15, -150)]:
        kids.append(part("LobbyLamp", (2, 0.5, 2), (x, y + 11.5, z), C["white"], "Neon",
                         children=[light(40, 1.5)]))
    parts.append({"Name": "Lobby", "ClassName": "Model", "Children": kids})


def build_spawns():
    def sp(name, pos):
        return part(name, (4, 0.2, 4), pos, C["yellow"], transparency=1, collide=False,
                    extra={"CanQuery": False, "CanTouch": False})
    parts.append({"Name": "Spawns", "ClassName": "Folder", "Children": [
        sp("RatSpawn", (10, 0.5, 57)),
        sp("HomeSpawn", (-25, FLOOR_Y + 0.5, -17)),
    ]})


def main():
    build_house()
    build_kitchen()
    build_dining()
    build_living()
    build_bedroom()
    build_cage()
    build_backyard()
    build_den()
    build_lobby()
    build_spawns()

    for name in ["Ground", "House", "Furniture", "Yard", "Scenery"]:
        parts.append({"Name": name, "ClassName": "Model", "Children": folders.get(name, [])})
    parts.append({"Name": "FoodSpawns", "ClassName": "Folder", "Children": food_spawns})

    root = {"ClassName": "Model", "Children": parts}
    out = os.path.join(os.path.dirname(__file__), "..", "map", "Map.model.json")
    with open(out, "w") as f:
        json.dump(root, f, indent=1)
    total = sum(len(folders.get(k, [])) for k in folders) + len(food_spawns)
    print(f"Wrote {out}: food spawns={len(food_spawns)}, parts~{total}")


if __name__ == "__main__":
    main()
