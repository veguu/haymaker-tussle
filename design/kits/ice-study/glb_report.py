"""What is really inside a GLB (numpy only): per mesh, its attributes, triangle count, bounds and the range of
every COLOR_n set. Use it after every export: the file, not the .blend, is what Roblox gets.
  python.exe glb_report.py <file.glb>
"""
import json
import struct
import sys

import numpy as np

COMPONENT = {5120: np.int8, 5121: np.uint8, 5122: np.int16, 5123: np.uint16, 5125: np.uint32, 5126: np.float32}
WIDTH = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}


def read(path):
    data = open(path, "rb").read()
    magic, version, length = struct.unpack_from("<4sII", data, 0)
    assert magic == b"glTF", "not a GLB"
    offset, doc, blob = 12, None, b""
    while offset < length:
        size, kind = struct.unpack_from("<I4s", data, offset)
        chunk = data[offset + 8:offset + 8 + size]
        if kind == b"JSON":
            doc = json.loads(chunk)
        elif kind == b"BIN\x00":
            blob = chunk
        offset += 8 + size
    return doc, blob


def accessor(doc, blob, index):
    acc = doc["accessors"][index]
    view = doc["bufferViews"][acc["bufferView"]]
    dtype = np.dtype(COMPONENT[acc["componentType"]])
    width = WIDTH[acc["type"]]
    start = view.get("byteOffset", 0) + acc.get("byteOffset", 0)
    stride = view.get("byteStride", 0)
    count = acc["count"]
    if stride and stride != dtype.itemsize * width:
        rows = [np.frombuffer(blob, dtype, width, start + i * stride) for i in range(count)]
        arr = np.array(rows)
    else:
        arr = np.frombuffer(blob, dtype, count * width, start).reshape(count, width)
    arr = arr.astype(np.float64)
    if acc.get("normalized"):
        arr = arr / np.iinfo(dtype).max
    return arr


def report(path):
    doc, blob = read(path)
    out = {}
    for node in doc.get("nodes", []):
        if "mesh" not in node:
            continue
        mesh = doc["meshes"][node["mesh"]]
        row = {"node": {k: node[k] for k in ("translation", "rotation", "scale") if k in node}, "primitives": len(mesh["primitives"])}
        for prim in mesh["primitives"]:
            attrs = prim["attributes"]
            pos = accessor(doc, blob, attrs["POSITION"])
            row["attributes"] = sorted(attrs)
            row["verts"] = len(pos)
            row["tris"] = (doc["accessors"][prim["indices"]]["count"] // 3) if "indices" in prim else len(pos) // 3
            row["min"] = [round(float(v), 4) for v in pos.min(0)]
            row["max"] = [round(float(v), 4) for v in pos.max(0)]
            for key in sorted(attrs):
                if key.startswith("COLOR_"):
                    col = accessor(doc, blob, attrs[key])[:, :3]
                    row[key] = {"type": doc["accessors"][attrs[key]]["componentType"],
                                "min": [round(float(v), 3) for v in col.min(0)], "max": [round(float(v), 3) for v in col.max(0)],
                                "mean": [round(float(v), 3) for v in col.mean(0)]}
        out[node.get("name", "?")] = row
    return out


if __name__ == "__main__":
    print(json.dumps(report(sys.argv[1]), indent=1))
