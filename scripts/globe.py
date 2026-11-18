#!/usr/bin/env python3
"""Makes the dotted globe for the tour: evenly spread points on the sphere, kept where there is
land, each with the ISO code of its country.

    curl -L -o countries.geojson \
      https://raw.githubusercontent.com/nvkelso/natural-earth-vector/master/geojson/ne_110m_admin_0_countries.geojson
    python3 -I scripts/globe.py countries.geojson Resources/Tour/globe.json

Natural Earth is public domain (naturalearthdata.com). Only the generated dots are committed.
The globe only shows roughly where MaskCopy works; it is not a map.
"""
import json
import math
import sys

POINTS = 14000
# Too small for the 1:110m outlines; one dot each so the globe still lights them.
EXTRA = {"SG": (1.35, 103.82), "HK": (22.32, 114.17)}


def inside(lon, lat, ring):
    hit = False
    j = len(ring) - 1
    for i in range(len(ring)):
        xi, yi = ring[i][0], ring[i][1]
        xj, yj = ring[j][0], ring[j][1]
        if (yi > lat) != (yj > lat) and lon < (xj - xi) * (lat - yi) / (yj - yi) + xi:
            hit = not hit
        j = i
    return hit


def main(src, dst):
    countries = []
    for f in json.load(open(src))["features"]:
        p = f["properties"]
        code = p.get("ISO_A2_EH") or p.get("ISO_A2")
        if not code or code == "-99":
            continue
        g = f["geometry"]
        polys = g["coordinates"] if g["type"] == "MultiPolygon" else [g["coordinates"]]
        boxes = []
        for poly in polys:
            xs = [pt[0] for pt in poly[0]]
            ys = [pt[1] for pt in poly[0]]
            boxes.append((min(xs), max(xs), min(ys), max(ys), poly))
        countries.append((code, boxes))

    dots = []
    golden = math.pi * (3 - math.sqrt(5))
    for i in range(POINTS):
        y = 1 - (i + 0.5) / POINTS * 2
        r = math.sqrt(1 - y * y)
        theta = golden * i
        lat = math.degrees(math.asin(y))
        lon = math.degrees(math.atan2(r * math.sin(theta), r * math.cos(theta)))
        for code, boxes in countries:
            found = False
            for x0, x1, y0, y1, poly in boxes:
                if x0 <= lon <= x1 and y0 <= lat <= y1 and inside(lon, lat, poly[0]) \
                        and not any(inside(lon, lat, hole) for hole in poly[1:]):
                    found = True
                    break
            if found:
                dots.append([round(lat, 1), round(lon, 1), code])
                break
    present = {d[2] for d in dots}
    for code, (lat, lon) in EXTRA.items():
        if code not in present:
            dots.append([lat, lon, code])
    json.dump(dots, open(dst, "w"), separators=(",", ":"))
    print(f"{len(dots)} land dots, {len(present)} countries")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
