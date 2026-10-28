# Regenerates the app icon PNGs from vector art.
#   python3 -m venv .venv && .venv/bin/pip install cairosvg pillow && .venv/bin/python Design/make_app_icon.py
# iOS: 1024 full-bleed RGB (no alpha). macOS: the same art inside an 824/1024 rounded-rect body
# with a drop shadow, rendered from vector at every size (16–512 pt @1x/@2x).
# Design/AppIcon.svg is the art without the trend line's drop shadow, which is composited here
# (PIL Gaussian blur 16, opacity 0.75, offset 16 down, all in 1024-unit space).
import io, json, math, os, sys
import cairosvg
from PIL import Image, ImageChops, ImageDraw, ImageFilter

BG = '#141414'
DEFS = f'''<defs><linearGradient id="o" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#FFA21F"/><stop offset="1" stop-color="#FF6A0F"/></linearGradient>
<linearGradient id="g" x1="0" y1="1" x2="1" y2="0"><stop offset="0" stop-color="#5FD236"/><stop offset="1" stop-color="#8BEA3F"/></linearGradient>
<radialGradient id="bg" cx="0.5" cy="0.4" r="0.75"><stop offset="0" stop-color="#2A2A2A"/><stop offset="1" stop-color="{BG}"/></radialGradient></defs>'''
BOTTOM, BAR_W, BAR_XS, BAR_TOPS, BAR_R = 900, 170, [175, 427, 679], [230, 330, 100], 26
LINE_PTS = [(120, 600), (260, 500), (512, 620), (905, 330)]
LINE_W, JOIN_R = 68, 12
SHADOW_BLUR, SHADOW_OPACITY, SHADOW_DY = 16, 0.75, 16

def bars():
    return "".join(f'<rect x="{x}" y="{t}" width="{BAR_W}" height="{BOTTOM - t}" rx="{BAR_R}" fill="url(#o)"/>'
                   for x, t in zip(BAR_XS, BAR_TOPS))

def rounded_path(pts, R):
    """Polyline with each interior corner rounded by a quadratic curve R units from the vertex."""
    d = f"M{pts[0][0]:.1f},{pts[0][1]:.1f}"
    for i in range(1, len(pts) - 1):
        p0, p1, p2 = pts[i - 1], pts[i], pts[i + 1]
        def toward(a, b, r):
            L = math.dist(a, b); return (a[0] + (b[0] - a[0]) * r / L, a[1] + (b[1] - a[1]) * r / L)
        a = toward(p1, p0, R); b = toward(p1, p2, R)
        d += f" L{a[0]:.1f},{a[1]:.1f} Q{p1[0]},{p1[1]} {b[0]:.1f},{b[1]:.1f}"
    return d + f" L{pts[-1][0]},{pts[-1][1]}"

def line(color):
    return (f'<path d="{rounded_path(LINE_PTS, JOIN_R)}" fill="none" stroke="{color}" stroke-width="{LINE_W}" '
            f'stroke-linecap="butt" stroke-linejoin="round"/>')

def svg_doc(body, background=True):
    bg = '<rect width="1024" height="1024" fill="url(#bg)"/>' if background else ''
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">{DEFS}{bg}{body}</svg>'

def render(doc, size):
    png = cairosvg.svg2png(bytestring=doc.encode(), output_width=size, output_height=size)
    return Image.open(io.BytesIO(png)).convert('RGBA')

def art(size):
    """Full-bleed art at `size` px: background + bars, blurred line shadow, line."""
    s = size / 1024
    base = render(svg_doc(bars()), size)
    sil = render(svg_doc(line('#000'), background=False), size)
    a = sil.split()[3].filter(ImageFilter.GaussianBlur(SHADOW_BLUR * s)).point(lambda v: int(v * SHADOW_OPACITY))
    shadow = Image.new('RGBA', sil.size, (0, 0, 0, 0)); shadow.putalpha(a)
    shadow = shadow.transform(sil.size, Image.AFFINE, (1, 0, 0, 0, 1, -SHADOW_DY * s),
                              resample=Image.NEAREST if size == 1024 else Image.BILINEAR)
    out = Image.alpha_composite(base, shadow)
    return Image.alpha_composite(out, render(svg_doc(line('url(#g)'), background=False), size))

def mac_icon(px):
    """macOS icon at `px`: art in an 824/1024 rounded-rect body (radius 185/1024) with a drop shadow."""
    s = px / 1024
    body = round(824 * s); off = (px - body) // 2
    ss = 4
    mask = Image.new('L', (body * ss, body * ss), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, body * ss - 1, body * ss - 1], radius=185 * s * ss, fill=255)
    mask = mask.resize((body, body), Image.LANCZOS)
    tile = art(body); tile.putalpha(ImageChops.multiply(tile.split()[3], mask))
    layer = Image.new('RGBA', (px, px), (0, 0, 0, 0)); layer.paste(tile, (off, off))
    sh = Image.new('RGBA', (px, px), (0, 0, 0, 0))
    sh.putalpha(layer.split()[3].point(lambda v: int(v * 0.5)).filter(ImageFilter.GaussianBlur(max(14 * s, 0.5))))
    sh = sh.transform((px, px), Image.AFFINE, (1, 0, 0, 0, 1, -10 * s), resample=Image.BILINEAR)
    return Image.alpha_composite(sh, layer)

if __name__ == '__main__':
    here = os.path.dirname(os.path.abspath(__file__))
    dest = os.path.join(here, '..', 'FitnessTracker', 'Assets.xcassets', 'AppIcon.appiconset')
    with open(os.path.join(here, 'AppIcon.svg'), 'w') as f:
        f.write(svg_doc(bars() + line('url(#g)')) + '\n')
    images = [{"idiom": "universal", "platform": "ios", "size": "1024x1024", "filename": "icon-ios-1024.png"}]
    art(1024).convert('RGB').save(os.path.join(dest, 'icon-ios-1024.png'), optimize=True)
    for pt in (16, 32, 128, 256, 512):
        for sc in (1, 2):
            name = f"icon-mac-{pt}@{sc}x.png"
            mac_icon(pt * sc).save(os.path.join(dest, name), optimize=True)
            images.append({"idiom": "mac", "scale": f"{sc}x", "size": f"{pt}x{pt}", "filename": name})
    with open(os.path.join(dest, 'Contents.json'), 'w') as f:
        json.dump({"images": images, "info": {"author": "xcode", "version": 1}}, f, indent=2)
    print('wrote', dest)
