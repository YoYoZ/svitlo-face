import Toybox.Graphics;
import Toybox.Lang;

// Retro LCD drawing primitives: slanted 7-segment digits + 5x7 dot-matrix text.
module Lcd {
    // bit order: a=1 b=2 c=4 d=8 e=16 f=32 g=64
    const SEG_MASKS = [0x3F, 0x06, 0x5B, 0x4F, 0x66, 0x6D, 0x7D, 0x07, 0x7F, 0x6F];
    const SKEW = 0.0;   // was 0.12 (Casio-style slant); upright reads better on the real MIP screen

    // Draw one 7-seg digit in box (x,y,w,h), stroke t. digit -1 = blank.
    function digit(dc as Dc, x as Number, y as Number, w as Number, h as Number, t as Number, d as Number) as Void {
        if (d < 0 || d > 9) { return; }
        var m = SEG_MASKS[d];
        var g = 1;
        var ht = t / 2.0;
        var xl = x + ht;
        var xr = x + w - ht;
        var yt = y + ht;
        var ym = y + h / 2.0;
        var yb = y + h - ht;
        var base = y + h;
        // No top bar (1, 4) / no bottom bar (1, 4, 7): the verticals would stop ~5 px short
        // of the other digits' edges, so stretch them to the full height to line up.
        var top = (m & 1) ? yt + g : y.toFloat();
        var bot = (m & 8) ? yb - g : (y + h).toFloat();
        if (m & 1)  { hseg(dc, xl + g, xr - g, yt, ht, base); }
        if (m & 2)  { vseg(dc, xr, top, ym - g, ht, base); }
        if (m & 4)  { vseg(dc, xr, ym + g, bot, ht, base); }
        if (m & 8)  { hseg(dc, xl + g, xr - g, yb, ht, base); }
        if (m & 16) { vseg(dc, xl, ym + g, bot, ht, base); }
        if (m & 32) { vseg(dc, xl, top, ym - g, ht, base); }
        if (m & 64) { hseg(dc, xl + g, xr - g, ym, ht, base); }
    }

    function hseg(dc as Dc, x0 as Float, x1 as Float, cy as Float, ht as Float, base as Number) as Void {
        dc.fillPolygon([
            p(x0, cy, base), p(x0 + ht, cy - ht, base), p(x1 - ht, cy - ht, base),
            p(x1, cy, base), p(x1 - ht, cy + ht, base), p(x0 + ht, cy + ht, base)
        ]);
    }

    function vseg(dc as Dc, cx as Float, y0 as Float, y1 as Float, ht as Float, base as Number) as Void {
        dc.fillPolygon([
            p(cx, y0, base), p(cx + ht, y0 + ht, base), p(cx + ht, y1 - ht, base),
            p(cx, y1, base), p(cx - ht, y1 - ht, base), p(cx - ht, y0 + ht, base)
        ]);
    }

    // italic transform: lean right going up
    function p(px as Float, py as Float, base as Number) as [Numeric, Numeric] {
        return [(px + (base - py) * SKEW + 0.5).toNumber(), (py + 0.5).toNumber()];
    }

    // two-digit number with optional blank leading zero
    function twoDigits(dc as Dc, x as Number, y as Number, w as Number, h as Number, t as Number, gap as Number, v as Number, blankLead as Boolean) as Void {
        var tens = v / 10;
        digit(dc, x, y, w, h, t, (blankLead && tens == 0) ? -1 : tens);
        digit(dc, x + w + gap, y, w, h, t, v % 10);
    }

    // ---- big text (scale 2): stroke font ----
    // The 5x7 dot font blown up 2x turns every diagonal into 2-px stairs (the "Minecraft"
    // look). Same 5x7 grid, but drawn as 2-px strokes between grid points: diagonals step
    // by 1 px, corners are chamfered like the clock's segments. Cell 10x14, advance 12.
    // Glyph = polylines of "xy" grid digit pairs (x 0..4, y 0..6), separated by spaces.
    const SCHARS = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ%#-?!/+&~{}";
    const SGLYPHS = [
        "103041453616050110", "112026 1636", "01103041420646",
        "0110304142334445361605 1333", "36300444", "40000003334445361605",
        "30100105163645443303", "0040412426",
        "130201103041423313 1304051636454433", "16364541301001021343",
        "060110304146 0343", "003041423303 334445360600", "4130100105163645",
        "00304145360600", "40000646 0333", "400006 0333", "41301001051636454323",
        "0006 4046 0343", "1030 2026 1636", "1040 3035261605", "0006 4004 2246",
        "000646", "0600234046", "06004640", "103041453616050110", "06003041423303",
        "103041453616050110 2446", "06003041423303 2346", "413010010213334445361605",
        "0040 2026", "000516364540", "0003264340", "0006234640", "0046 4006",
        "0023 4023 2326", "00400646",
        "0010110100 3545463635 4006",   // %
        "0020220200",                   // # = degree ring
        "1333",                         // -
        "011030414224 2626",            // ?
        "2024 2626",                    // !
        "4006",                         // /
        "2125 0343",                    // +
        "30133316",                     // & = bolt (power)
        "30133316 0046",                // ~ = bolt struck out (power off)
        "2026 042644",                  // { = arrow down (volts low)
        "2026 022042"                   // } = arrow up (volts high)
    ];
    const NARROW = ":. ";               // half-width cells

    function stroke(dc as Dc, s as String, x as Number, y as Number) as Void {
        s = s.toUpper();
        var cx = x;
        for (var i = 0; i < s.length(); i++) {
            var ch = s.substring(i, i + 1);
            if (NARROW.find(ch) != null) {
                if (ch.equals(":")) { dc.fillRectangle(cx + 1, y + 4, 2, 2); dc.fillRectangle(cx + 1, y + 8, 2, 2); }
                else if (ch.equals(".")) { dc.fillRectangle(cx + 1, y + 12, 2, 2); }
                cx += 6;
                continue;
            }
            var idx = SCHARS.find(ch);
            if (idx != null) { glyph(dc, SGLYPHS[idx], cx, y); }
            cx += 12;
        }
    }

    function glyph(dc as Dc, g as String, x as Number, y as Number) as Void {
        var a = g.toCharArray();
        var pen = false; var px = 0; var py = 0;
        var i = 0;
        while (i < a.size()) {
            if (a[i].toNumber() == 32) { pen = false; i++; continue; }
            var nx = x + (a[i].toNumber() - 48) * 2;
            var ny = y + (a[i + 1].toNumber() - 48) * 2;
            if (pen) { seg(dc, px, py, nx, ny); } else { dc.fillRectangle(nx, ny, 2, 2); }
            pen = true; px = nx; py = ny;
            i += 2;
        }
    }

    // 2x2 brush from (x0,y0) to (x1,y1)
    function seg(dc as Dc, x0 as Number, y0 as Number, x1 as Number, y1 as Number) as Void {
        if (x0 == x1) { dc.fillRectangle(x0, y0 < y1 ? y0 : y1, 2, (y1 - y0).abs() + 2); return; }
        if (y0 == y1) { dc.fillRectangle(x0 < x1 ? x0 : x1, y0, (x1 - x0).abs() + 2, 2); return; }
        dc.drawLine(x0, y0, x1, y1);         dc.drawLine(x0 + 1, y0, x1 + 1, y1);
        dc.drawLine(x0, y0 + 1, x1, y1 + 1); dc.drawLine(x0 + 1, y0 + 1, x1 + 1, y1 + 1);
        dc.fillRectangle(x0, y0, 2, 2);      dc.fillRectangle(x1, y1, 2, 2);
    }

    // ---- 5x7 dot matrix text (scale 1; scale 2 goes to the stroke font) ----
    function textWidth(s as String, scale as Number) as Number {
        var n = s.length();
        if (n == 0) { return 0; }
        if (scale != 2) { return (n * 6 - 1) * scale; }
        var w = 0;
        for (var i = 0; i < n; i++) { w += NARROW.find(s.substring(i, i + 1)) != null ? 6 : 12; }
        return w - 2;
    }

    function text(dc as Dc, s as String, x as Number, y as Number, scale as Number) as Void {
        if (scale == 2) { stroke(dc, s, x, y); return; }
        s = s.toUpper();
        var cx = x;
        for (var i = 0; i < s.length(); i++) {
            var idx = DotFont.CHARS.find(s.substring(i, i + 1));
            if (idx != null) {
                var o = idx * 7;
                for (var r = 0; r < 7; r++) {
                    var row = DotFont.GLYPHS[o + r];
                    if (row == 0) { continue; }
                    for (var c = 0; c < 5; c++) {
                        if ((row >> (4 - c)) & 1) {
                            dc.fillRectangle(cx + c * scale, y + r * scale, scale, scale);
                        }
                    }
                }
            }
            cx += 6 * scale;
        }
    }

    function textRight(dc as Dc, s as String, xr as Number, y as Number, scale as Number) as Void {
        text(dc, s, xr - textWidth(s, scale), y, scale);
    }

    function textCenter(dc as Dc, s as String, cx as Number, y as Number, scale as Number) as Void {
        text(dc, s, cx - textWidth(s, scale) / 2, y, scale);
    }

    // inverted "chip": white box, black text (lit LCD badge)
    function chip(dc as Dc, s as String, x as Number, y as Number, on as Boolean) as Number {
        var w = textWidth(s, 1) + 4;
        if (on) {
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(x, y, w, 11, 2);
            dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
            text(dc, s, x + 2, y + 2, 1);
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        } else {
            dc.drawRoundedRectangle(x, y, w, 11, 2);
            text(dc, s, x + 2, y + 2, 1);
        }
        return w;
    }
}
