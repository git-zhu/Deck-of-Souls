#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
《老头牌：褪色者的牌局》—— 艾尔登法环风格 2D 美术素材程序化生成器
===============================================================
路线：程序化生成 + 传统图像处理（PIL/Pillow + numpy，超采样抗锯齿）
用法：python tools/generate_assets.py   （可重复运行，覆盖 assets/*.png）
输出：
    assets/card_frame.png        256x340  卡牌边框（石板底 + 金色描边 + 四角符文 + 顶部宝石）
    assets/card_frame_edge.png   256x340  纯边框叠加层（透明底）
    assets/bg_title_vignette.png 1280x720 标题屏暗角 + 中央金色辉光 + 符文点缀（透明底）
    assets/panel_ornament.png    256x64   面板顶部金色符文分隔饰条
    assets/intent_attack.png     64x64    敌人意图：攻击（红剑）
    assets/intent_block.png      64x64    敌人意图：护甲（青盾）
    assets/intent_buff.png       64x64    敌人意图：增益（紫箭/菱形）
    assets/intent_debuff.png     64x64    敌人意图：减益（绿菱形）
    assets/icon_flask.png        48x48    圣杯瓶图标（绿瓶 + 金边）
    assets/icon_soul.png         48x48    卢恩/灵魂图标（金色菱形符文）
"""

from __future__ import annotations

import math
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS = os.path.join(ROOT, "assets")
SS = 4  # 超采样倍数（绘制 4x 后 LANCZOS 缩小，抗锯齿）

# ---------------- 调色板 ----------------
GOLD      = (224, 192, 108)    # #e0c06c 主金
GOLD_BRT  = (232, 198, 106)    # #e8c66a 亮金
GOLD_DK   = (201, 162, 39)     # #c9a227 暗金
GOLD_PALE = (240, 218, 152)
DARK      = (22, 19, 15)       # #16130f
DARK2     = (36, 32, 24)       # #242018
DARK3     = (56, 49, 36)
PLATINUM  = (232, 230, 224)    # 白金色描边
RED       = (176, 52, 48)
RED_LT    = (216, 88, 76)
RED_DK    = (112, 32, 30)
CYAN      = (84, 166, 196)
CYAN_LT   = (136, 208, 230)
CYAN_DK   = (44, 104, 130)
PURPLE    = (156, 96, 208)
PURPLE_LT = (196, 142, 234)
PURPLE_DK = (84, 52, 118)
GREEN     = (108, 186, 96)
GREEN_LT  = (150, 218, 134)
GREEN_DK  = (50, 112, 46)
FLASK_G    = (66, 150, 90)
FLASK_G_DK = (38, 100, 62)
FLASK_G_LT = (118, 206, 140)

# 简易符文笔画（归一化坐标，y 向下，范围约 [-1, 1]）
RUNES = [
    # 1 双叉竖纹
    [((0.0, -0.8), (0.0, 0.8)), ((-0.35, -0.8), (0.35, 0.8)), ((0.35, -0.8), (-0.35, 0.8))],
    # 2 菱形 + 十字
    [((-0.6, 0.0), (0.0, -0.7), (0.6, 0.0), (0.0, 0.7), (-0.6, 0.0)),
     ((-0.6, 0.0), (0.6, 0.0)), ((0.0, -0.7), (0.0, 0.7))],
    # 3 竖纹 + 双支
    [((0.0, -0.8), (0.0, 0.8)), ((0.0, -0.35), (0.7, -0.5)), ((0.0, 0.15), (0.7, 0.0)), ((0.0, 0.65), (0.7, 0.5))],
    # 4 斜线 + 钩
    [((-0.6, 0.7), (0.6, -0.7)), ((0.6, -0.7), (0.6, 0.2)), ((0.6, 0.2), (0.78, 0.42))],
    # 5 X + 横杠
    [((-0.6, -0.7), (0.6, 0.7)), ((0.6, -0.7), (-0.6, 0.7)), ((-0.6, 0.0), (0.6, 0.0))],
    # 6 三道人字纹
    [((-0.6, -0.45), (0.0, -0.75), (0.6, -0.45)), ((-0.6, 0.05), (0.0, -0.25), (0.6, 0.05)),
     ((-0.6, 0.55), (0.0, 0.25), (0.6, 0.55))],
    # 7 丁字 + 底横
    [((-0.6, -0.75), (0.6, -0.75)), ((0.0, -0.75), (0.0, 0.6)), ((-0.5, 0.75), (0.5, 0.75))],
    # 8 菱形环
    [((-0.55, 0.0), (0.0, -0.55), (0.55, 0.0), (0.0, 0.55), (-0.55, 0.0))],
    # 9 波浪
    [((-0.7, -0.6), (0.0, -0.2), (-0.4, 0.4), (0.5, 0.8))],
]


# ---------------- 基础工具 ----------------
def canvas(w, h, bg=(0, 0, 0, 0)):
    im = Image.new("RGBA", (w, h), bg)
    return im, ImageDraw.Draw(im)


def downscale(im, size):
    return im.resize(size, Image.Resampling.LANCZOS)


def glow(im, cx, cy, r, color, alpha, blur=None):
    """在 im 上叠加一个高斯模糊光晕。"""
    g = Image.new("RGBA", im.size, (0, 0, 0, 0))
    gd = ImageDraw.Draw(g)
    gd.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(*color, alpha))
    g = g.filter(ImageFilter.GaussianBlur(blur if blur is not None else r * 0.5))
    im.alpha_composite(g)


def outlined_poly(d, pts, fill, outline, ow):
    """带描边的多边形：先画宽描边线环，再填内部。"""
    d.line(pts + [pts[0]], fill=outline, width=ow * 2, joint="curve")
    d.polygon(pts, fill=fill)


def draw_rune(d, cx, cy, size, strokes, color, width, angle=0):
    """按归一化笔画绘制符文，可旋转。"""
    a = math.radians(angle)
    ca, sa = math.cos(a), math.sin(a)
    for stroke in strokes:
        pts = []
        for (px, py) in stroke:
            rx = px * ca - py * sa
            ry = px * sa + py * ca
            pts.append((cx + rx * size, cy + ry * size))
        d.line(pts, fill=color, width=width, joint="curve")


def radial_glow_arr(w, h, cx, cy, rx, ry, color, peak):
    """返回一个 RGBA numpy 数组：椭圆高斯光晕。"""
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    g = np.exp(-(((xx - cx) / rx) ** 2 + ((yy - cy) / ry) ** 2))
    arr = np.zeros((h, w, 4), np.float32)
    arr[..., 0] = color[0]
    arr[..., 1] = color[1]
    arr[..., 2] = color[2]
    arr[..., 3] = g * peak
    return np.clip(arr, 0, 255).astype(np.uint8)


def save(im, name):
    path = os.path.join(ASSETS, name)
    os.makedirs(ASSETS, exist_ok=True)
    im.save(path)
    print("  [ok] %-28s %4dx%-4d  %6d bytes" % (name, im.size[0], im.size[1], os.path.getsize(path)))


# ============================================================
# 1 & 2. 卡牌边框（共享装饰绘制，仅底座不同）
# ============================================================
def stone_base(w, h, radius, inset, seed=7):
    """石板/羊皮深色底：径向渐变 + 噪点 + 金粉，圆角透明蒙版。
    inset/radius 与外层金线描边的外缘几何一致，保证边框像素下方始终有底座。"""
    rng = np.random.default_rng(seed)
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    d = np.sqrt(((xx - w / 2) / (w * 0.5)) ** 2 + ((yy - h / 2) / (h * 0.5)) ** 2)
    t = np.clip(d, 0, 1)
    arr = np.zeros((h, w, 3), np.float32)
    for c in range(3):
        arr[..., c] = DARK2[c] + (DARK[c] - DARK2[c]) * (t ** 1.2)
    arr += rng.normal(0, 4.2, (h, w, 3))
    # 横向柔和纹理带
    bands = rng.normal(0, 2.2, (h, 1, 3))
    arr += bands * 0.35
    arr = np.clip(arr, 0, 255)
    img = Image.fromarray(arr.astype(np.uint8), "RGB").convert("RGBA")
    # 金粉
    dust = rng.random((h, w))
    dy, dx = np.where(dust < 0.0014)
    dd = ImageDraw.Draw(img)
    for i in range(len(dx)):
        g = int(rng.integers(170, 235))
        al = int(rng.integers(26, 80))
        rr = int(rng.integers(1, 3))
        dd.ellipse([dx[i] - rr, dy[i] - rr, dx[i] + rr, dy[i] + rr],
                   fill=(g, max(0, g - 26), 92, al))
    # 圆角蒙版（最后应用，保证角落透明干净）
    mask = Image.new("L", (w, h), 0)
    md = ImageDraw.Draw(mask)
    md.rounded_rectangle([inset, inset, w - 1 - inset, h - 1 - inset], radius=radius, fill=255)
    img.putalpha(mask)
    return img


def top_gem(im, d, w, s):
    """顶部宝石（金菱形 + 刻面 + 光晕 + 爪托）。"""
    cx = w / 2
    glow(im, cx, 17 * s, 26 * s, GOLD_BRT, 60, blur=14 * s)
    pts = [(cx, 5 * s), (cx + 13 * s, 15 * s), (cx, 33 * s), (cx - 13 * s, 15 * s)]
    d.polygon(pts, fill=GOLD_DK)
    d.line(pts + [pts[0]], fill=GOLD_BRT, width=int(1.6 * s), joint="curve")
    # 台面
    d.polygon([(cx - 7 * s, 14 * s), (cx, 10 * s), (cx + 7 * s, 14 * s), (cx, 17 * s)], fill=GOLD_BRT)
    # 刻面线
    d.line([(cx, 15 * s), (cx - 12 * s, 15 * s)], fill=GOLD_DK, width=s)
    d.line([(cx, 15 * s), (cx + 12 * s, 15 * s)], fill=GOLD_DK, width=s)
    d.line([(cx, 17 * s), (cx, 31 * s)], fill=(232, 198, 106, 170), width=s)
    # 爪托
    d.line([(cx - 13 * s, 15 * s), (cx - 17 * s, 13 * s)], fill=GOLD, width=int(1.6 * s))
    d.line([(cx + 13 * s, 15 * s), (cx + 17 * s, 13 * s)], fill=GOLD, width=int(1.6 * s))
    # 闪光点
    d.ellipse([cx - 3 * s, 26 * s, cx + 3 * s, 32 * s], fill=(240, 218, 152, 170))


def corner_flourish(d, w, h, s, dx, dy, k):
    """四角符文装饰：角宝石 + 45° 辐射短线 + 边线点缀。"""
    def P(x, y):
        return (w / 2 + dx * (x - w / 2), h / 2 + dy * (y - h / 2))

    # 内角菱形宝石（位于内圈线拐角处）
    cx0, cy0 = P(20.5 * s, 20.5 * s)
    sz = 2.6 * s
    d.polygon([(cx0, cy0 - sz), (cx0 + sz, cy0), (cx0, cy0 + sz), (cx0 - sz, cy0)],
              fill=GOLD_BRT, outline=GOLD_DK)
    # 指向角落的短线
    ax, ay = P(13.5 * s, 13.5 * s)
    d.line([(cx0, cy0), (ax, ay)], fill=GOLD_DK, width=int(1.6 * s))
    # 指向卡心的短线
    bx, by = P(28 * s, 28 * s)
    d.line([(cx0, cy0), (bx, by)], fill=(201, 162, 39, 190), width=int(1.2 * s))
    # 角落小圆点
    r2 = 1.6 * s
    d.ellipse([ax - r2, ay - r2, ax + r2, ay + r2], fill=GOLD_DK)
    # 外圈线上沿直边的点缀点
    ex, ey = P(34 * s, 4 * s)
    d.ellipse([ex - 1.3 * s, ey - 1.3 * s, ex + 1.3 * s, ey + 1.3 * s], fill=(201, 162, 39, 200))
    ex2, ey2 = P(4 * s, 34 * s)
    d.ellipse([ex2 - 1.3 * s, ey2 - 1.3 * s, ex2 + 1.3 * s, ey2 + 1.3 * s], fill=(201, 162, 39, 200))


def draw_frame_decor(im, d, w, h, s):
    """边框装饰（金色三层描边 + 四角符文 + 顶部宝石）。"""
    o = int(4 * s)
    d.rounded_rectangle([o, o, w - o, h - o], radius=int(22 * s), outline=GOLD_DK, width=int(2 * s))
    m = int(11 * s)
    d.rounded_rectangle([m, m, w - m, h - m], radius=int(16 * s), outline=GOLD, width=int(2.5 * s))
    i_ = int(17 * s)
    d.rounded_rectangle([i_, i_, w - i_, h - i_], radius=int(12 * s), outline=(232, 198, 106, 150), width=s)
    # 内阴影（增加层次）
    d.rounded_rectangle([int(21 * s), int(21 * s), w - int(21 * s), h - int(21 * s)],
                        radius=int(10 * s), outline=(0, 0, 0, 80), width=int(2 * s))
    # 四角（TL, TR, BR, BL）
    for k, (dx, dy) in enumerate([(1, 1), (-1, 1), (-1, -1), (1, -1)]):
        corner_flourish(d, w, h, s, dx, dy, k)
    top_gem(im, d, w, s)


def card_frame(with_base):
    w, h = 256 * SS, 340 * SS
    # 外线: inset=4s, width=2s, radius=22s -> 外缘 inset=3s, radius=23s；
    # 底座蒙版取 inset=2s/radius=24s（与边框同圆心 26s），完全覆盖金线描边
    im = stone_base(w, h, 24 * SS, 2 * SS) if with_base else Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    draw_frame_decor(im, d, w, h, SS)
    return downscale(im, (256, 340))


# ============================================================
# 3. 标题屏暗角 + 金色辉光 + 符文点缀
# ============================================================
def bg_title_vignette():
    w, h = 1280, 720
    im, d = canvas(w, h)
    cx, cy = w / 2, h * 0.46
    rng = np.random.default_rng(21)

    # 1) 微光底纹（低频噪点暖金斑）
    noise = rng.normal(0.5, 0.22, (h, w))
    ni = Image.fromarray((np.clip(noise, 0, 1) * 255).astype(np.uint8), "L")
    ni = ni.filter(ImageFilter.GaussianBlur(26))
    n = np.asarray(ni, np.float32) / 255.0
    spots = np.clip((n - 0.56) / 0.44, 0, 1)
    tex = np.zeros((h, w, 4), np.float32)
    tex[..., 0] = GOLD[0]
    tex[..., 1] = GOLD[1]
    tex[..., 2] = GOLD[2]
    tex[..., 3] = spots * 20
    im.alpha_composite(Image.fromarray(np.clip(tex, 0, 255).astype(np.uint8), "RGBA"))
    # 细颗粒微光
    fg = rng.normal(0.5, 0.2, (h, w))
    fi = Image.fromarray((np.clip(fg, 0, 1) * 255).astype(np.uint8), "L").filter(ImageFilter.GaussianBlur(5))
    fn = np.asarray(fi, np.float32) / 255.0
    fspots = np.clip((fn - 0.62) / 0.38, 0, 1)
    ftex = np.zeros((h, w, 4), np.float32)
    ftex[..., 0] = GOLD_BRT[0]
    ftex[..., 1] = GOLD_BRT[1]
    ftex[..., 2] = GOLD_BRT[2]
    ftex[..., 3] = fspots * 12
    im.alpha_composite(Image.fromarray(np.clip(ftex, 0, 255).astype(np.uint8), "RGBA"))

    # 2) 中央金色辉光（两层）
    im.alpha_composite(Image.fromarray(radial_glow_arr(w, h, cx, cy, w * 0.17, h * 0.16, GOLD_BRT, 96), "RGBA"))
    im.alpha_composite(Image.fromarray(radial_glow_arr(w, h, cx, cy, w * 0.34, h * 0.30, GOLD, 42), "RGBA"))

    # 3) 符文环（椭圆排布）
    for i in range(10):
        ang = math.radians(i * 36 - 90)
        px = cx + 310 * math.cos(ang)
        py = cy + 168 * math.sin(ang)
        size = 20 + (i % 3) * 5
        draw_rune(d, px, py, size, RUNES[i % len(RUNES)], (232, 198, 106, 58), width=2,
                  angle=math.degrees(ang) + 90)
    # 3b) 散落小符文
    for _ in range(18):
        x = float(rng.uniform(60, w - 60))
        y = float(rng.uniform(40, h - 40))
        if ((x - cx) / 300) ** 2 + ((y - cy) / 170) ** 2 < 1.1:
            continue
        size = float(rng.uniform(9, 19))
        ang = float(rng.uniform(0, 360))
        al = int(rng.uniform(28, 68))
        draw_rune(d, x, y, size, RUNES[int(rng.integers(len(RUNES)))], (224, 192, 108, al),
                  width=2, angle=ang)

    # 4) 金色尘埃
    for _ in range(150):
        x = float(rng.uniform(0, w))
        y = float(rng.uniform(0, h))
        r = float(rng.uniform(0.6, 1.7))
        a = int(rng.uniform(12, 46))
        d.ellipse([x - r, y - r, x + r, y + r], fill=(232, 198, 106, a))

    # 5) 边缘暗角（置于最上层）
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    dd = np.sqrt(((xx - cx) / (w * 0.56)) ** 2 + ((yy - cy) / (h * 0.56)) ** 2)
    a = np.clip((dd - 0.42) / 0.78, 0, 1) ** 1.5 * 205
    vig = np.zeros((h, w, 4), np.float32)
    vig[..., 0] = 13
    vig[..., 1] = 10
    vig[..., 2] = 7
    vig[..., 3] = a
    im.alpha_composite(Image.fromarray(np.clip(vig, 0, 255).astype(np.uint8), "RGBA"))
    return im


# ============================================================
# 4. 面板顶部金色符文分隔饰条
# ============================================================
def panel_ornament():
    w, h = 256 * SS, 64 * SS
    im, d = canvas(w, h)
    cx, cy = w / 2, h / 2

    # 微暗底条（低透明度，提供分隔存在感）
    d.rounded_rectangle([0, 13 * SS, w - 1, h - 13 * SS], radius=9 * SS, fill=(28, 23, 17, 42))

    # 中央符文菱形
    big = [(cx, 14 * SS), (cx + 34 * SS, 32 * SS), (cx, 50 * SS), (cx - 34 * SS, 32 * SS)]
    d.polygon(big, fill=(38, 32, 24))
    d.line(big + [big[0]], fill=GOLD, width=int(2.2 * SS), joint="curve")
    d.line([(cx - 28 * SS, 32 * SS), (cx + 28 * SS, 32 * SS)], fill=GOLD_BRT, width=int(2 * SS))
    d.line([(cx, 20 * SS), (cx, 44 * SS)], fill=GOLD_DK, width=SS)
    d.polygon([(cx, 27 * SS), (cx + 5 * SS, 32 * SS), (cx, 37 * SS), (cx - 5 * SS, 32 * SS)], fill=GOLD_BRT)
    # 中央菱形小圆点
    d.ellipse([cx - 2.4 * SS, cy - 2.4 * SS, cx + 2.4 * SS, cy + 2.4 * SS], fill=GOLD_PALE)

    def left_side(x0, sign):
        # 左侧元素（右端镜像时 sign=-1）
        fx = cx + sign * (cx - x0)
        # 小菱形
        d.polygon([(fx - 5 * SS, cy), (fx, cy - 5 * SS), (fx + 5 * SS, cy), (fx, cy + 5 * SS)],
                  fill=GOLD_BRT, outline=GOLD_DK)
        # 横线
        xa = cx + sign * 64 * SS
        xb = cx + sign * 42 * SS
        d.line([(xa, cy), (xb, cy)], fill=GOLD, width=int(2 * SS))
        # 卷曲
        rr = 9 * SS
        cxx = cx + sign * 34 * SS
        if sign < 0:
            d.arc([cxx - rr, cy - rr, cxx + rr, cy + rr], start=270, end=450, fill=GOLD, width=int(2 * SS))
        else:
            d.arc([cxx - rr, cy - rr, cxx + rr, cy + rr], start=90, end=270, fill=GOLD, width=int(2 * SS))
        # 末端小菱形 + 指向外侧的三角
        d.polygon([(cxx - 4 * SS, cy), (cxx, cy - 4 * SS), (cxx + 4 * SS, cy), (cxx, cy + 4 * SS)],
                  fill=GOLD_DK)
        tip = cx + sign * 24 * SS
        d.polygon([(tip, cy - 6 * SS), (tip + sign * 8 * SS, cy), (tip, cy + 6 * SS)], fill=GOLD_DK)
        # 线上装饰点
        for t in (56, 48):
            tx = cx + sign * t * SS
            d.ellipse([tx - 1.6 * SS, cy - 1.6 * SS, tx + 1.6 * SS, cy + 1.6 * SS], fill=GOLD_DK)

    left_side(cx - 42 * SS, 1)
    left_side(cx + 42 * SS, -1)
    return downscale(im, (256, 64))


# ============================================================
# 5. 敌人意图小图标（64x64）
# ============================================================
def intent_icon(kind):
    w = h = 256
    im, d = canvas(w, h)
    cx, cy = 128, 124

    if kind == "attack":
        glow(im, cx, 100, 108, RED, 60, blur=44)
        # 剑刃
        blade = [(cx, 20), (cx + 25, 106), (cx + 8, 124), (cx - 8, 124), (cx - 25, 106)]
        outlined_poly(d, blade, RED, PLATINUM, 4)
        d.polygon([(cx, 20), (cx + 25, 106), (cx + 8, 124), (cx, 116)], fill=RED_LT)
        d.line([(cx, 34), (cx, 108)], fill=RED_LT, width=3)
        # 护手
        d.rounded_rectangle([cx - 42, 122, cx + 42, 146], radius=6, fill=(60, 30, 28),
                            outline=PLATINUM, width=4)
        d.rounded_rectangle([cx - 46, 124, cx - 30, 144], radius=4, fill=GOLD_DK, outline=GOLD, width=2)
        d.rounded_rectangle([cx + 30, 124, cx + 46, 144], radius=4, fill=GOLD_DK, outline=GOLD, width=2)
        # 握柄 + 缠线
        d.rectangle([cx - 10, 146, cx + 10, 172], fill=(44, 26, 22), outline=PLATINUM, width=3)
        d.line([(cx - 10, 154), (cx + 10, 154)], fill=GOLD_DK, width=3)
        d.line([(cx - 10, 162), (cx + 10, 162)], fill=GOLD_DK, width=3)
        # 尾珠
        d.ellipse([cx - 11, 174, cx + 11, 196], fill=GOLD_DK, outline=PLATINUM, width=3)
        d.ellipse([cx - 5, 178, cx + 5, 188], fill=GOLD_BRT)
    elif kind == "block":
        glow(im, cx, 100, 110, CYAN, 60, blur=44)
        # 盾形轮廓（顶弧 + 两侧收尖）
        pts = []
        for a in range(180, 361, 12):
            ang = math.radians(a)
            pts.append((cx + 44 * math.cos(ang), 62 - 18 * math.sin(ang)))
        pts += [(cx + 44, 70), (cx + 36, 102), (cx + 18, 136), (cx, 174), (cx - 18, 136),
                (cx - 36, 102), (cx - 44, 70)]
        outlined_poly(d, pts, CYAN, PLATINUM, 4)
        d.arc([cx - 44, 44, cx + 44, 80], 180, 360, fill=CYAN_LT, width=8)
        d.polygon([(cx - 34, 78), (cx - 6, 70), (cx - 2, 96), (cx - 30, 102)], fill=CYAN_LT)
        # 盾心
        d.ellipse([cx - 22, 94, cx + 22, 138], outline=PLATINUM, width=5)
        d.ellipse([cx - 9, 106, cx + 9, 124], fill=PLATINUM)
        # 铆钉
        for sx in (cx - 38, cx + 38):
            d.ellipse([sx - 3.5, 80 - 3.5, sx + 3.5, 80 + 3.5], fill=PLATINUM)
    elif kind == "buff":
        glow(im, cx, 100, 110, PURPLE, 60, blur=44)
        # 外菱形环（紫 + 白描边）
        ring = [(cx, 20), (cx + 96, 96), (cx, 172), (cx - 96, 96)]
        d.line(ring + [ring[0]], fill=PLATINUM, width=14, joint="curve")
        d.line(ring + [ring[0]], fill=PURPLE, width=7, joint="curve")
        d.polygon([(cx - 82, 96), (cx, 32), (cx + 82, 96), (cx, 160)], fill=(52, 34, 84))
        # 内箭头
        head = [(cx, 48), (cx + 46, 94), (cx - 46, 94)]
        shaft = [(cx - 16, 86), (cx + 16, 86), (cx + 16, 132), (cx - 16, 132)]
        outlined_poly(d, shaft, PURPLE, PLATINUM, 3)
        outlined_poly(d, head, PURPLE, PLATINUM, 3)
        d.polygon([(cx, 48), (cx + 46, 94), (cx + 16, 94), (cx, 74)], fill=PURPLE_LT)
    else:  # debuff
        glow(im, cx, 100, 110, GREEN, 60, blur=44)
        dia = [(cx, 26), (cx + 74, 96), (cx, 166), (cx - 74, 96)]
        outlined_poly(d, dia, GREEN, PLATINUM, 4)
        inner = [(cx, 44), (cx + 58, 96), (cx, 148), (cx - 58, 96)]
        d.line(inner + [inner[0]], fill=GREEN_DK, width=5, joint="curve")
        d.polygon([(cx, 56), (cx + 40, 96), (cx, 136), (cx - 40, 96)], fill=(70, 140, 62))
        d.ellipse([cx - 6, 90, cx + 6, 102], fill=GREEN_LT, outline=PLATINUM, width=2)
    return downscale(im, (64, 64))


# ============================================================
# 6 & 7. 小图标（48x48）
# ============================================================
def icon_flask():
    w = h = 192
    im, d = canvas(w, h)
    cx, cy = 96, 100
    glow(im, cx, 110, 74, FLASK_G, 55, blur=32)

    # 瓶身（圆腹 + 细颈）
    d.ellipse([cx - 40, 88, cx + 40, 168], fill=FLASK_G)
    d.polygon([(cx - 12, 46), (cx + 12, 46), (cx + 14, 92), (cx - 14, 92)], fill=FLASK_G)
    # 右/下暗部
    d.ellipse([cx + 8, 98, cx + 40, 166], fill=FLASK_G_DK)
    d.polygon([(cx + 8, 98), (cx + 14, 92), (cx + 14, 46), (cx + 12, 46)], fill=FLASK_G_DK)
    # 玻璃高光
    d.ellipse([cx - 30, 104, cx - 12, 144], fill=FLASK_G_LT)
    d.ellipse([cx - 26, 112, cx - 18, 136], fill=(255, 255, 255, 150))
    # 金色轮廓
    d.ellipse([cx - 40, 88, cx + 40, 168], outline=GOLD_DK, width=4)
    d.line([(cx - 12, 46), (cx - 14, 92)], fill=GOLD_DK, width=4)
    d.line([(cx + 12, 46), (cx + 14, 92)], fill=GOLD_DK, width=4)
    # 瓶颈金环 + 瓶口金边
    d.rounded_rectangle([cx - 14, 62, cx + 14, 72], radius=2, fill=GOLD, outline=GOLD_DK, width=2)
    d.rounded_rectangle([cx - 13, 40, cx + 13, 50], radius=3, fill=GOLD, outline=GOLD_DK, width=2)
    # 顶部亮斑（药液反光）
    d.ellipse([cx - 4, 33, cx + 4, 41], fill=GOLD_BRT)
    return downscale(im, (48, 48))


def icon_soul():
    w = h = 192
    im, d = canvas(w, h)
    cx, cy = 96, 96
    glow(im, cx, cy, 82, GOLD, 70, blur=36)

    # 双环（外暗金粗环 + 内金细环）
    d.ellipse([cx - 58, cy - 66, cx + 58, cy + 66], outline=GOLD_DK, width=6)
    d.ellipse([cx - 46, cy - 54, cx + 46, cy + 54], outline=GOLD, width=3)
    # 中横杆
    d.line([(cx - 58, cy), (cx + 58, cy)], fill=GOLD_BRT, width=7)
    for sx in (cx - 58, cx + 58):
        d.polygon([(sx, cy - 5), (sx + 5, cy), (sx, cy + 5), (sx - 5, cy)], fill=GOLD_BRT)
    # 中心菱形
    d.polygon([(cx, cy - 9), (cx + 9, cy), (cx, cy + 9), (cx - 9, cy)], fill=GOLD_BRT, outline=GOLD_DK)
    # 顶部小菱形 + 底部短竖线
    d.polygon([(cx, cy - 72), (cx + 6, cy - 64), (cx, cy - 56), (cx - 6, cy - 64)], fill=GOLD)
    d.line([(cx, cy + 9), (cx, cy + 30)], fill=GOLD_DK, width=4)
    # 光泽
    d.ellipse([cx - 34, cy - 46, cx - 16, cy - 20], fill=(240, 218, 152, 110))
    return downscale(im, (48, 48))


# ============================================================
def main():
    os.makedirs(ASSETS, exist_ok=True)
    print("生成法环风美术素材 -> %s" % ASSETS)

    print("\n[卡牌边框]")
    save(card_frame(with_base=True), "card_frame.png")
    save(card_frame(with_base=False), "card_frame_edge.png")

    print("\n[标题屏背景叠加]")
    save(bg_title_vignette(), "bg_title_vignette.png")

    print("\n[面板饰条]")
    save(panel_ornament(), "panel_ornament.png")

    print("\n[敌人意图图标]")
    save(intent_icon("attack"), "intent_attack.png")
    save(intent_icon("block"), "intent_block.png")
    save(intent_icon("buff"), "intent_buff.png")
    save(intent_icon("debuff"), "intent_debuff.png")

    print("\n[小图标]")
    save(icon_flask(), "icon_flask.png")
    save(icon_soul(), "icon_soul.png")

    print("\n全部完成。")


if __name__ == "__main__":
    main()
