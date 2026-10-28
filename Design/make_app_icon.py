# Regenerates the app icon PNGs from vector art: pip install cairosvg pillow; python3 Design/make_app_icon.py
# iOS: 1024 full-bleed RGB (no alpha). macOS: 824/1024 rounded-rect body with drop shadow, 16–512 @1x/@2x.
import io, json, os, cairosvg
from PIL import Image, ImageFilter, ImageChops

ART = '''
  <defs>
    <radialGradient id="bg" cx="512" cy="300" r="900" gradientUnits="userSpaceOnUse">
      <stop offset="0" stop-color="#3A3A3C"/>
      <stop offset="0.55" stop-color="#2E2E30"/>
      <stop offset="1" stop-color="#202022"/>
    </radialGradient>
    <linearGradient id="bar" x1="0" y1="376" x2="0" y2="782" gradientUnits="userSpaceOnUse">
      <stop offset="0" stop-color="#FFB43F"/>
      <stop offset="1" stop-color="#FF7F19"/>
    </linearGradient>
    <linearGradient id="line" x1="283" y1="0" x2="738" y2="0" gradientUnits="userSpaceOnUse">
      <stop offset="0" stop-color="#7AD047"/>
      <stop offset="1" stop-color="#84DC45"/>
    </linearGradient>
  </defs>
  {BG}
  <g fill="url(#bar)">
    <rect x="280" y="586" width="105" height="196" rx="13"/>
    <rect x="460" y="504" width="105" height="278" rx="13"/>
    <rect x="640" y="376" width="105" height="406" rx="13"/>
  </g>
  <path d="M283 536 Q509.5 486 731 258" fill="none" stroke="url(#line)" stroke-width="9" stroke-linecap="round"/>
  <circle cx="738" cy="250" r="14" fill="#84DC45"/>
'''
def svg(bg=True):
    body = ART.replace('{BG}', '<rect width="1024" height="1024" fill="url(#bg)"/>' if bg else '')
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">{body}</svg>'

def render(s, size):
    return Image.open(io.BytesIO(cairosvg.svg2png(bytestring=s.encode(), output_width=size, output_height=size))).convert('RGBA')

def with_shadow(bg, fg, blur, dy, alpha):
    a = fg.split()[3].point(lambda v: int(v * alpha))
    sh = Image.new('RGBA', fg.size, (0, 0, 0, 0)); sh.putalpha(a)
    sh = sh.filter(ImageFilter.GaussianBlur(blur)); sh = ImageChops.offset(sh, 0, dy)
    out = Image.alpha_composite(bg, sh); return Image.alpha_composite(out, fg)

S = 1024
bg = render(svg(True).replace(ART.split('<g fill')[0].split('{BG}')[0], ART.split('<g fill')[0].split('{BG}')[0]), S)
# Background only, art only (art gets a subtle soft shadow like the source).
bg_only = render(svg(True).split('<g fill')[0] + '</svg>', S)
art = render(svg(False), S)
ios = with_shadow(bg_only, art, 10, 8, 0.45).convert('RGB')   # full bleed, no alpha
os.makedirs('out', exist_ok=True)  # previews/intermediates (not committed)
ios.save('out/ios-1024.png'); ios.save('preview-ios.png')
open('out/AppIcon.svg', 'w').write(svg(True))

# macOS: 824×824 rounded-rect body centred on a 1024 canvas (Apple macOS icon grid),
# corner radius ≈ 185 (22.5%), soft drop shadow beneath.
body = 824; off = (S - body) // 2; radius = 185
scale = 4  # supersample the mask for smooth corners
mask = Image.new('L', (S * scale, S * scale), 0)
from PIL import ImageDraw
ImageDraw.Draw(mask).rounded_rectangle([off * scale, off * scale, (off + body) * scale - 1, (off + body) * scale - 1],
                                       radius=radius * scale, fill=255)
mask = mask.resize((S, S), Image.LANCZOS)
tile = with_shadow(render(svg(True).split('<g fill')[0] + '</svg>', body), render(svg(False), body), 8, 6, 0.45)  # vector at body size
canvas_art = Image.new('RGBA', (S, S), (0, 0, 0, 0)); canvas_art.paste(tile, (off, off))
canvas_art.putalpha(mask)
mac = with_shadow(Image.new('RGBA', (S, S), (0, 0, 0, 0)), canvas_art, 14, 10, 0.5)
mac.save('out/mac-1024.png'); mac.save('preview-mac.png')

images = [{"idiom": "universal", "platform": "ios", "size": "1024x1024", "filename": "icon-ios-1024.png"}]
files = {"icon-ios-1024.png": ios}
for pt in (16, 32, 128, 256, 512):
    for sc in (1, 2):
        px = pt * sc; name = f"icon-mac-{pt}@{sc}x.png"
        files[name] = mac if px == 1024 else mac.resize((px, px), Image.LANCZOS)
        images.append({"idiom": "mac", "scale": f"{sc}x", "size": f"{pt}x{pt}", "filename": name})
dest = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'FitnessTracker', 'Assets.xcassets', 'AppIcon.appiconset')
for n, im in files.items(): im.save(os.path.join(dest, n), optimize=True)
json.dump({"images": images, "info": {"author": "xcode", "version": 1}}, open(os.path.join(dest, 'Contents.json'), 'w'), indent=2)
print('done')
