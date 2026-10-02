#!/usr/bin/env python3
"""Tiny software renderer for previewing the parts the game's Lua builds (no Roblox needed).

Supports Block / Ball / Cylinder (axis X) / Wedge parts and SpecialMesh spheres. Flat shading with a
key light + sky ambient, z-buffer, supersampling. Neon parts are unlit. This is a *geometry* preview:
materials, post-processing and Roblox lighting are not reproduced.
"""
import math

import numpy as np
from PIL import Image


def _unit(v):
    n = np.linalg.norm(v)
    return v / n if n > 1e-9 else v


class Scene:
    def __init__(self):
        self.tris = []  # (3x3 verts, color(3), alpha, neon)

    # ---- mesh builders (local space, then transformed) ---------------------------------
    @staticmethod
    def _box_tris(sx, sy, sz):
        x, y, z = sx / 2, sy / 2, sz / 2
        v = np.array([[-x, -y, -z], [x, -y, -z], [x, y, -z], [-x, y, -z], [-x, -y, z], [x, -y, z], [x, y, z], [-x, y, z]])
        f = [(0, 2, 1), (0, 3, 2), (4, 5, 6), (4, 6, 7), (0, 1, 5), (0, 5, 4), (3, 7, 6), (3, 6, 2), (0, 4, 7), (0, 7, 3), (1, 2, 6), (1, 6, 5)]
        return [v[list(t)] for t in f]

    @staticmethod
    def _wedge_tris(sx, sy, sz):
        # slope rises toward +Z (vertical face at +Z)
        x, y, z = sx / 2, sy / 2, sz / 2
        a = [(-x, -y, -z), (x, -y, -z), (x, -y, z), (-x, -y, z), (-x, y, z), (x, y, z)]
        a = np.array(a)
        f = [(0, 2, 1), (0, 3, 2),  # bottom
             (3, 4, 5), (3, 5, 2),  # back
             (0, 1, 5), (0, 5, 4),  # slope
             (0, 4, 3),  # left tri
             (1, 2, 5)]  # right tri
        return [a[list(t)] for t in f]

    @staticmethod
    def _cyl_tris(length, diameter, n=18):
        # axis = X
        r = diameter / 2
        h = length / 2
        out = []
        ring = [(math.cos(2 * math.pi * i / n) * r, math.sin(2 * math.pi * i / n) * r) for i in range(n + 1)]
        for i in range(n):
            (y0, z0), (y1, z1) = ring[i], ring[i + 1]
            a, b, c, d = (-h, y0, z0), (h, y0, z0), (h, y1, z1), (-h, y1, z1)
            out.append(np.array([a, b, c]))
            out.append(np.array([a, c, d]))
            out.append(np.array([(h, 0, 0), b, c]))
            out.append(np.array([(-h, 0, 0), d, a]))
        return out

    @staticmethod
    def _sphere_tris(sx, sy, sz, nu=20, nv=12):
        out = []
        pts = []
        for j in range(nv + 1):
            phi = math.pi * j / nv
            row = []
            for i in range(nu + 1):
                th = 2 * math.pi * i / nu
                row.append((math.sin(phi) * math.cos(th) * sx / 2, math.cos(phi) * sy / 2, math.sin(phi) * math.sin(th) * sz / 2))
            pts.append(row)
        for j in range(nv):
            for i in range(nu):
                a, b, c, d = pts[j][i], pts[j][i + 1], pts[j + 1][i + 1], pts[j + 1][i]
                out.append(np.array([a, c, b]))
                out.append(np.array([a, d, c]))
        return out

    def add(self, part):
        """part: dict with sh (Block/Ball/Cylinder/Wedge), mesh (None/'Sphere'), cf (12 floats), sz, col, t, neon"""
        if part.get("t", 0) >= 0.95:
            return
        px, py, pz, *r = part["cf"]
        R = np.array(r).reshape(3, 3)
        P = np.array([px, py, pz])
        sx, sy, sz = part["sz"]
        sh = part["sh"]
        if part.get("mesh") == "Sphere":
            tris = self._sphere_tris(sx, sy, sz)
        elif sh == "Ball":
            d = min(sx, sy, sz)
            tris = self._sphere_tris(d, d, d)
        elif sh == "Cylinder":
            tris = self._cyl_tris(sx, min(sy, sz))
        elif sh == "Wedge":
            tris = self._wedge_tris(sx, sy, sz)
        else:
            tris = self._box_tris(sx, sy, sz)
        alpha = 1.0 - part.get("t", 0.0)
        for t in tris:
            w = (R @ t.T).T + P
            self.tris.append((w, part["col"], alpha, part.get("neon", False)))


def look_at(eye, target, up=(0, 1, 0)):
    eye, target, up = np.array(eye, float), np.array(target, float), np.array(up, float)
    f = _unit(target - eye)
    r = _unit(np.cross(f, up))
    u = np.cross(r, f)
    return eye, r, u, f


def render(scene, eye, target, fov=40.0, size=(900, 700), bg=((30, 34, 60), (120, 130, 170)), ss=2,
           light=(0.4, 0.8, 0.5), ambient=0.42, fog=None, ortho=None):
    W, H = size[0] * ss, size[1] * ss
    eye, r, u, f = look_at(eye, target)
    aspect = W / H
    tanh = math.tan(math.radians(fov) / 2)
    # background gradient
    top, bot = np.array(bg[0], float), np.array(bg[1], float)
    t = np.linspace(0, 1, H)[:, None, None]
    img = (top * (1 - t) + bot * t) * np.ones((H, W, 3))
    img = img.astype(np.float32)
    zbuf = np.full((H, W), np.inf, np.float32)
    L = _unit(np.array(light, float))

    tris = scene.tris
    if not tris:
        return Image.fromarray(img.astype(np.uint8))
    V = np.array([t[0] for t in tris])  # N,3,3
    N = len(tris)
    rel = V - eye
    cx = rel @ r
    cy = rel @ u
    cz = rel @ f
    # normals
    e1 = V[:, 1] - V[:, 0]
    e2 = V[:, 2] - V[:, 0]
    nrm = np.cross(e1, e2)
    nl = np.linalg.norm(nrm, axis=1, keepdims=True)
    nl[nl < 1e-12] = 1
    nrm = nrm / nl
    centers = V.mean(axis=1)
    # make normal face the camera
    toeye = eye - centers
    flip = (nrm * toeye).sum(axis=1) < 0
    nrm[flip] *= -1
    lam = np.clip((nrm * L).sum(axis=1), 0, 1)
    sky = 0.5 + 0.5 * nrm[:, 1]
    cols = np.array([t[1] for t in tris], float)
    alphas = np.array([t[2] for t in tris], float)
    neon = np.array([t[3] for t in tris])
    shade = ambient * (0.6 + 0.4 * sky) + (1 - ambient) * lam
    shaded = cols * shade[:, None]
    shaded[neon] = cols[neon]
    if fog:
        dist = np.linalg.norm(centers - eye, axis=1)
        k = np.clip((dist - fog[0]) / (fog[1] - fog[0]), 0, 1)[:, None]
        shaded = shaded * (1 - k) + np.array(fog[2], float) * k
    shaded = np.clip(shaded, 0, 255)

    order = np.argsort(-cz.mean(axis=1))  # far to near
    near = 0.1
    sx = (cx / np.maximum(cz, near)) / (tanh * aspect) * (W / 2) + W / 2
    sy = H / 2 - (cy / np.maximum(cz, near)) / tanh * (H / 2)
    opaque, transparent = [], []
    for i in order:
        if (cz[i] < near).any():
            continue
        (opaque if alphas[i] >= 0.99 else transparent).append(i)

    def raster(i, blend):
        x0, x1, x2 = sx[i]
        y0, y1, y2 = sy[i]
        minx = int(max(0, math.floor(min(x0, x1, x2))))
        maxx = int(min(W - 1, math.ceil(max(x0, x1, x2))))
        miny = int(max(0, math.floor(min(y0, y1, y2))))
        maxy = int(min(H - 1, math.ceil(max(y0, y1, y2))))
        if minx > maxx or miny > maxy:
            return
        den = (y1 - y2) * (x0 - x2) + (x2 - x1) * (y0 - y2)
        if abs(den) < 1e-9:
            return
        xs = np.arange(minx, maxx + 1) + 0.5
        ys = np.arange(miny, maxy + 1) + 0.5
        X, Y = np.meshgrid(xs, ys)
        w0 = ((y1 - y2) * (X - x2) + (x2 - x1) * (Y - y2)) / den
        w1 = ((y2 - y0) * (X - x2) + (x0 - x2) * (Y - y2)) / den
        w2 = 1 - w0 - w1
        m = (w0 >= 0) & (w1 >= 0) & (w2 >= 0)
        if not m.any():
            return
        z = w0 * cz[i][0] + w1 * cz[i][1] + w2 * cz[i][2]
        zb = zbuf[miny:maxy + 1, minx:maxx + 1]
        m &= z < zb
        if not m.any():
            return
        sub = img[miny:maxy + 1, minx:maxx + 1]
        c = shaded[i].astype(np.float32)
        if blend:
            a = alphas[i]
            sub[m] = sub[m] * (1 - a) + c * a
        else:
            sub[m] = c
            zb[m] = z[m]

    for i in opaque:
        raster(i, False)
    for i in transparent:
        raster(i, True)
    im = Image.fromarray(np.clip(img, 0, 255).astype(np.uint8))
    if ss > 1:
        im = im.resize(size, Image.LANCZOS)
    return im
