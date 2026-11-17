"""Pick an accent color from cover art: the most vivid dominant hue, pushed bright enough to glow."""
import colorsys

from PySide6.QtCore import Qt
from PySide6.QtGui import QImage

from .sources.common import session

FALLBACK = "#e9e6ff"


def accent_from_url(url):
    if not url:
        return FALLBACK
    r = session.get(url, timeout=12)
    if r.status_code == 404 and "/hq720.jpg" in url:
        r = session.get(url.replace("/hq720.jpg", "/mqdefault.jpg"), timeout=12)
    r.raise_for_status()
    img = QImage.fromData(r.content)
    return accent_from_image(img)


def accent_from_image(img):
    if img.isNull():
        return FALLBACK
    img = img.scaled(48, 48, Qt.IgnoreAspectRatio, Qt.SmoothTransformation).convertToFormat(QImage.Format_RGB32)
    bins = [[0.0, 0.0, 0.0, 0.0] for _ in range(24)]  # weight, r, g, b
    for y in range(img.height()):
        for x in range(img.width()):
            c = img.pixelColor(x, y)
            r, g, b = c.redF(), c.greenF(), c.blueF()
            h, s, v = colorsys.rgb_to_hsv(r, g, b)
            if v < 0.18 or s < 0.22:
                continue
            w = s * s * v
            bi = bins[int(h * 24) % 24]
            bi[0] += w
            bi[1] += r * w
            bi[2] += g * w
            bi[3] += b * w
    # merge neighbours so one hue split across two bins still wins
    scored = [(bins[i][0] + 0.5 * (bins[i - 1][0] + bins[(i + 1) % 24][0]), i) for i in range(24)]
    weight, idx = max(scored)
    if weight < 0.6:
        return FALLBACK
    w, r, g, b = bins[idx]
    if w <= 0:
        return FALLBACK
    h, s, v = colorsys.rgb_to_hsv(r / w, g / w, b / w)
    s = min(1.0, max(s, 0.55))
    v = max(v, 0.92)
    r, g, b = colorsys.hsv_to_rgb(h, s, v)
    return "#%02x%02x%02x" % (int(r * 255), int(g * 255), int(b * 255))
