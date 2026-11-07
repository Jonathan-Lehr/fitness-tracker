# Regenerates the app icon PNGs from vector art.
#   python3 -m venv .venv && .venv/bin/pip install cairosvg pillow && .venv/bin/python Design/make_app_icon.py
# iOS: 1024 full-bleed RGB (no alpha). macOS: the same art inside an 824/1024 rounded-rect body
# with a drop shadow, rendered from vector at every size (16–512 pt @1x/@2x).
# Art mirrors the weekly summary chart: five full-height grey tracks with blue values on columns
# 1/3/5 (85/70/100%), white background, light baseline; chart 800x648 centred at y=510.
import io, json, os
import cairosvg
from PIL import Image, ImageChops, ImageDraw, ImageFilter

BAR_W, GAP, N = 128, 40, 5
CHART_W = N * BAR_W + (N - 1) * GAP            # 800
CHART_H = 648                                   # 90% of the original 720 plot height
CENTER_Y = 510
TOP, BOTTOM = CENTER_Y - CHART_H / 2, CENTER_Y + CHART_H / 2
X0 = (1024 - CHART_W) / 2
BAR_R = 18
FILLS = [0.85, None, 0.70, None, 1.0]           # blue value per column; None = empty (track only)
TRACK, BASELINE, BASELINE_W, BASELINE_EXT = '#F2F2F4', '#CDCDD2', 6.5, 24
DEFS = """<defs><linearGradient id="b" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#22A8FF"/><stop offset="1" stop-color="#008AFF"/></linearGradient></defs>"""

def bar(x, y, fill):
    r = BAR_R
    return (f'<path d="M{x},{BOTTOM} V{y + r} Q{x},{y} {x + r},{y} H{x + BAR_W - r} '
            f'Q{x + BAR_W},{y} {x + BAR_W},{y + r} V{BOTTOM} Z" fill="{fill}"/>')

def chart():
    out = ''
    for i, v in enumerate(FILLS):
        x = X0 + i * (BAR_W + GAP)
        out += bar(x, TOP, TRACK)
        if v is not None:
            out += bar(x, BOTTOM - CHART_H * v, 'url(#b)')
    return out + (f'<rect x="{X0 - BASELINE_EXT}" y="{BOTTOM - BASELINE_W / 2}" width="{CHART_W + 2 * BASELINE_EXT}" '
                  f'height="{BASELINE_W}" rx="{BASELINE_W / 2}" fill="{BASELINE}"/>')

def svg_doc(body, background=True):
    bg = '<rect width="1024" height="1024" fill="#FFFFFF"/>' if background else ''
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">{DEFS}{bg}{body}</svg>'

def render(doc, size):
    png = cairosvg.svg2png(bytestring=doc.encode(), output_width=size, output_height=size)
    return Image.open(io.BytesIO(png)).convert('RGBA')

def art(size):
    """Full-bleed art at `size` px: white background, grey tracks, blue values, baseline."""
    return render(svg_doc(chart()), size)

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
        f.write(svg_doc(chart()) + '\n')
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
