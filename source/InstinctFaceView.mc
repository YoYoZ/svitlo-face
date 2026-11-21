import Toybox.Activity;
import Toybox.ActivityMonitor;
import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.Position;
import Toybox.SensorHistory;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.UserProfile;
import Toybox.WatchUi;
import Toybox.Weather;

// Retro world-time LCD face for Instinct 2 (176x176 round MIP + top-right subscreen).
class InstinctFaceView extends WatchUi.WatchFace {
    const W = Graphics.COLOR_WHITE;
    const B = Graphics.COLOR_BLACK;
    const T = Graphics.COLOR_TRANSPARENT;

    const DAYS = ["", "SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"];
    const WX = ["CLEAR", "PTCLD", "CLOUD", "RAIN", "SNOW", "WINDY", "STORM", "MIX", "FOG", "HAZE",
                "HAIL", "SHWR", "TSTRM", "PRECP", "DRZL", "RAIN!", "SNOW", "SNOW!", "SLEET", "SLEET", "CLOUD"];

    // layout (see README for the map of the screen)
    // Time spans the full width now that seconds are gone. Left edge x=8 lines up with the
    // outage bar and the date row: 8..40 45..77 [colon 83..87] 93..125 130..162.
    // Vertical rhythm with breathing room around the digits:
    //   date row 64..84 | temp 78..92 (clear of the round window's bezel, lowest at y~74)
    //   | gap | time 97..145 | gap | bottom row 151..165 (the flat bottom edge has room)
    const TIME_X = 8; const TIME_Y = 97; const TIME_H = 48; const DIG_W = 30; const DIG_T = 8;
    const DIG_GAP = 8; const MIN_X = 93; const COLON_X = 83;

    var sub = null;            // subscreen BoundingBox
    var subCx = 0; var subCy = 0; var subR = 0;
    var zones = null;          // [z1..z5 start, max] bpm from the user profile
    var zonesMin = -1;         // minute they were last read
    var awake = true;

    function initialize() {
        WatchFace.initialize();
    }

    function onLayout(dc as Dc) as Void {
        if (WatchUi has :getSubscreen) {
            sub = WatchUi.getSubscreen();
        }
        if (sub != null) {
            subCx = sub.x + sub.width / 2;
            subCy = sub.y + sub.height / 2;
            subR = sub.width / 2;
        } else {
            // No round window and real hands (Crossover): no digital clock either. The rows
            // spread over the whole round screen, centred, with heart rate as its own row:
            //   panel 18..41 | bar 48..58 (wider)
            //   temp  (hands' pivot)  battery     on the centre line, y 81..95
            //   date row 104..124 (centred) | heart rate + AQI 134..148
            var cx = dc.getWidth() / 2;
            PY = 18;
            PX = cx - PW / 2;
            TL_W = 120; TL_Y = 48;
            TL_X = cx - TL_W / 2;
            DATE_Y = 104; DATE_DX = cx - 53 - 8;          // row is 106 px wide from x 8
            TEMP_Y = cx - 7;
            BOT_Y = 134; BOT_L = 32; BOT_R = 144;         // pulled in from the round edge
        }
    }
    const PIVOT_L = 70; const PIVOT_R = 106;   // Crossover: clear of the hands' centre cap
    var DATE_DX = 0;   // shifts the date row / alert badge right (centred without the window)
    var BOT_L = 26; var BOT_R = 150;
    var TEMP_Y = 78;   // below the round window's bezel; on the date text line without one
    var DATE_Y = 64;   // date row / alert badge box top
    var BOT_Y = 151;   // AQI + battery row

    function onUpdate(dc as Dc) as Void {
        dc.clearClip();
        dc.setColor(W, B);
        dc.clear();
        dc.setColor(W, T);

        var now = Time.now();
        var clock = System.getClockTime();
        var info = Gregorian.info(now, Time.FORMAT_SHORT);
        var settings = System.getDeviceSettings();
        var loc = getLocation();

        var p = powerState(now);
        drawStatusPanel(dc, p, now);
        drawTimeline(dc, now);
        drawDateRow(dc, info, settings);
        if (sub != null) { drawTime(dc, clock, settings); }   // Crossover: real hands tell the time
        drawBottom(dc, settings);
        drawSubscreen(dc, clock.min, p);
    }

    // ---------------- panels ----------------

    // top-left pane = HOME POWER (from the inverter, refreshed every 5 min)
    //   normal : [GRID] 236V      / 96% 410W
    //   volts  : [GRID] [VLO 198]  (lit = error)
    //   outage : [OUT 1:23]       / 96% ~9:13   (outage duration / SOC / runtime left)
    //   no data: PWR ??           / AGE 25M or NO PHONE
    // Big readable words, voltage only when it's wrong:
    //   PWR ON                      (plain)
    //   [OFF  1:23 / 96%]           (inverted; outage duration + battery)
    //   [LOW  VOLT / 198]  [HI ...] (inverted; bad grid voltage)
    //   PWR ?? / reason             (no data)
    // Stale data (>15 min) -> dotted frame instead of solid.
    // subscreen box is x113..175,y0..62 but its physical bezel hides ~12px more -> stay left of x~100
    // as wide as fits: the octagon's cut corner clips anything left of x~12 at this height
    // PX / TL_X / TEMP_Y move to the centre on watches without the round window (Crossover)
    var PX = 12; var PY = 15; const PW = 87; const PH = 23;

    // One line, all at the big size ({/} = arrow down/up):
    //   PWR ON    outlined          grid fine
    //   OFF 1:23  inverted          outage for 1h23 (home battery % moves to the round window)
    //   {198V     inverted          grid voltage too low ( } = too high)
    //   PWR ??    dotted outline    no data
    function drawStatusPanel(dc as Dc, p as Dictionary, now) as Void {
        var bad = configProblem();
        if (bad != null) {
            frame(dc, true);
            panelText(dc, bad);
            return;
        }
        if (p[:mode] == :none) {
            frame(dc, true);
            panelText(dc, "PWR ??");
            return;
        }
        var v = p[:v] == null ? -1 : p[:v].toNumber();
        var lo = Application.Properties.getValue("VoltLow");
        var hi = Application.Properties.getValue("VoltHigh");

        if (p[:mode] == :out) {
            var mins = p[:since] == null ? 0 : (now.value() - p[:since]) / 60;
            alertPanel(dc, "OFF " + (mins < 600 ? hm(mins) : (mins / 60) + "H"));
        } else if (v >= 0 && lo != null && v < lo) {
            alertPanel(dc, "{" + v + "V");
        } else if (v >= 0 && hi != null && v > hi) {
            alertPanel(dc, "}" + v + "V");
        } else {
            frame(dc, p[:old]);
            panelText(dc, "PWR ON");
        }
    }

    // Settings hints from the last reply: nothing set at all -> SET UP; the server flags
    // bad fields in "e" (s supplier, q queue, sb SvitloBot channel, a alert place).
    function configProblem() as String? {
        var d = Application.Storage.getValue("pwr");
        if (!(d instanceof Dictionary)) { return null; }
        if (d["cfg"] == false) { return "SET UP"; }
        var e = d["e"];
        if (!(e instanceof String)) { return null; }
        e = "," + e + ",";
        if (e.find(",s,") != null) { return "SET S"; }
        if (e.find(",q,") != null) { return "SET Q"; }
        if (e.find(",sb,") != null) { return "SET SB"; }
        if (e.find(",a,") != null) { return "SET A"; }
        return null;
    }

    function panelText(dc as Dc, s as String) as Void {
        Lcd.text(dc, s, PX + (PW - Lcd.textWidth(s, 2)) / 2, PY + 5, 2);
    }

    // inverted panel = something's wrong
    function alertPanel(dc as Dc, s as String) as Void {
        dc.setColor(W, T);
        dc.fillRoundedRectangle(PX, PY, PW, PH, 3);
        dc.setColor(B, T);
        panelText(dc, s);
        dc.setColor(W, T);
    }

    function frame(dc as Dc, dotted) as Void {
        if (dotted != true) {
            dc.drawRoundedRectangle(PX, PY, PW, PH, 3);
            return;
        }
        for (var x = PX + 2; x < PX + PW - 2; x += 3) {
            dc.drawPoint(x, PY); dc.drawPoint(x, PY + PH - 1);
        }
        for (var y = PY + 2; y < PY + PH - 2; y += 3) {
            dc.drawPoint(PX, y); dc.drawPoint(PX + PW - 1, y);
        }
    }

    function hm(mins as Number) as String {
        return (mins / 60).toString() + ":" + (mins % 60).format("%02d");
    }

    // ---------------- outage timeline (replaces the world map) ----------------
    // 24h strip: -6h .. now .. +18h.  hatched = planned DTEK window, solid = actual outage,
    // triangle under the bar = now, tick under the bar = midnight. Text line = next planned window.
    // 6-hour window: 3 h back, now in the middle, 3 h ahead. Left edge = clock's left edge.
    var TL_X = 8; var TL_Y = 42; var TL_W = 92; const TL_H = 10;
    const TL_BACK = 3 * 3600; const TL_SPAN = 6 * 3600;

    function drawTimeline(dc as Dc, now) as Void {
        if (Application.Properties.getValue("ShowTimeline") == false) { return; }
        var n = now.value();
        var t0 = n - TL_BACK;
        var d = Application.Storage.getValue("pwr");
        if (DEMO != 0) {
            d = {"pl" => [[n - 2 * 3600 - 1800, n - 3600], [n + 3600, n + 5 * 3600]],
                 "fa" => [[n - 2 * 3600, n - 3600 - 1200]],
                 "nx" => [n + 3600, n + 5 * 3600], "sv" => "ok", "kc" => 200};
        }
        dc.setColor(W, T);
        if (d instanceof Dictionary && d["em"] == true) {
            // emergency outages today: the schedule doesn't apply -> dotted outline
            for (var x = TL_X; x < TL_X + TL_W; x += 2) { dc.drawPoint(x, TL_Y); dc.drawPoint(x, TL_Y + TL_H - 1); }
            for (var y = TL_Y; y < TL_Y + TL_H; y += 2) { dc.drawPoint(TL_X, y); dc.drawPoint(TL_X + TL_W - 1, y); }
        } else {
            dc.drawRectangle(TL_X, TL_Y, TL_W, TL_H);
        }

        if (d instanceof Dictionary) {
            var pl = d["pl"]; var fa = d["fa"];
            if (pl instanceof Array) {
                for (var i = 0; i < pl.size(); i++) { hatch(dc, tx(pl[i][0], t0), tx(pl[i][1], t0)); }
            }
            if (fa instanceof Array) {
                for (var i = 0; i < fa.size(); i++) { solid(dc, tx(fa[i][0], t0), tx(fa[i][1], t0)); }
            }
            if (d["og"] == true && d["os"] != null) { solid(dc, tx(d["os"], t0), tx(n, t0)); }
        }
        // hourly ticks under the bar (midnight gets a longer one)
        var h0 = (t0 / 3600 + 1) * 3600;
        for (var h = h0; h < t0 + TL_SPAN; h += 3600) {
            var hx = tx(h, t0);
            var midnight = Gregorian.info(new Time.Moment(h), Time.FORMAT_SHORT).hour == 0;
            dc.drawLine(hx, TL_Y + TL_H, hx, TL_Y + TL_H + (midnight ? 4 : 2));
        }
        // now marker
        var nx = tx(n, t0);
        dc.fillPolygon([[nx, TL_Y + TL_H + 1], [nx - 3, TL_Y + TL_H + 4], [nx + 3, TL_Y + TL_H + 4]]);
        // (no text line under the bar any more: the bar itself shows the plan)
    }

    function tx(t, t0) as Number {
        var x = TL_X + 1 + ((t - t0) * (TL_W - 2) / TL_SPAN);
        if (x < TL_X + 1) { x = TL_X + 1; } else if (x > TL_X + TL_W - 1) { x = TL_X + TL_W - 1; }
        return x.toNumber();
    }

    function solid(dc as Dc, xa as Number, xb as Number) as Void {
        if (xb > xa) { dc.fillRectangle(xa, TL_Y + 1, xb - xa, TL_H - 2); }
    }

    // diagonal hatch, every 3 px (cheaper and higher-contrast than a checker)
    function hatch(dc as Dc, xa as Number, xb as Number) as Void {
        if (xb <= xa) { return; }
        dc.setClip(xa, TL_Y + 1, xb - xa, TL_H - 2);
        for (var k = xa - TL_H; k < xb; k += 3) {
            dc.drawLine(k, TL_Y + TL_H - 1, k + TL_H, TL_Y);
        }
        dc.clearClip();
    }

    function scheduleText(d as Dictionary, n as Number) as String {
        var kc = d["kc"];
        if (kc == -1) { return "SCHED OFF"; }
        if (kc != null && kc != 200) { return "SCHED ERR " + kc; }
        var nxt = d["nx"];
        var s;
        if (!(nxt instanceof Array) || nxt[0] == null) {
            s = "NO PLAN";
        } else if (n >= nxt[0] && n < nxt[1]) {
            s = "PLAN TILL " + hhmm(nxt[1]);
        } else {
            s = "NEXT " + hhmm(nxt[0]) + "-" + hhmm(nxt[1]);
        }
        var sv = d["sv"];
        if (sv != null && !sv.equals("ok")) { s = "!" + s; }   // dashboard says battery may not last
        return s;
    }

    function hhmm(ts) as String {
        var i = Gregorian.info(new Time.Moment(ts), Time.FORMAT_SHORT);
        return i.hour.format("%02d") + ":" + i.min.format("%02d");
    }

    // day box + date box on the left (the subscreen bezel reaches down to y~74 on the right),
    // temperature in the small slot under the round window
    function drawDateRow(dc as Dc, info, st) as Void {
        drawWeather(dc, st);
        if (drawAlert(dc)) { return; }

        dc.drawRoundedRectangle(8 + DATE_DX, DATE_Y, 41, 20, 3);
        Lcd.textCenter(dc, DAYS[info.day_of_week], 28 + DATE_DX, DATE_Y + 3, 2);
        dc.drawRoundedRectangle(51 + DATE_DX, DATE_Y, 63, 20, 3);
        var md = info.day.format("%02d") + "." + info.month.format("%02d");   // EU: dd.mm
        Lcd.textCenter(dc, md, 82 + DATE_DX, DATE_Y + 3, 2);
    }

    // Kyiv air-raid alert takes over the date row: "RED 0:42" (city, whole), "YEL" (city,
    // partial), "OBL" (only the oblast around). Inverted when confirmed by the latest poll;
    // outlined when the last poll failed or is >20 min old (= last known, not current).
    const ALV = ["", "OBL", "YEL", "RED"];
    function drawAlert(dc as Dc) as Boolean {
        var now = Time.now().value();
        var a = Application.Storage.getValue("al");
        if (DEMO == 5) { a = [3, now - 42 * 60, 200, now]; }
        if (DEMO == 6) { a = [1, now - 5 * 60, -104, now - 30 * 60]; }
        if (!(a instanceof Array) || a[0] == null || a[0] <= 0) { return false; }
        var lv = a[0] as Number;
        var txt = ALV[lv];
        if (a[1] != null) {
            var m = (now - (a[1] as Number)) / 60;
            if (m < 0) { m = 0; }
            txt += " " + (m < 600 ? (m / 60) + ":" + (m % 60).format("%02d") : (m / 60) + "H");
        }
        var sure = a[2] == 200 && a.size() > 3 && a[3] != null && now - (a[3] as Number) < 20 * 60;
        if (sure) {
            dc.fillRoundedRectangle(8 + DATE_DX, DATE_Y, 106, 20, 3);
            dc.setColor(B, T);
            Lcd.textCenter(dc, txt, 61 + DATE_DX, DATE_Y + 3, 2);
            dc.setColor(W, T);
        } else {
            dc.drawRoundedRectangle(8 + DATE_DX, DATE_Y, 106, 20, 3);
            dc.drawRoundedRectangle(9 + DATE_DX, DATE_Y + 1, 104, 18, 3);
            Lcd.textCenter(dc, txt, 61 + DATE_DX, DATE_Y + 3, 2);
        }
        return true;
    }

    function drawTime(dc as Dc, clock, st) as Void {
        // EU: always 24h, leading zero kept (07:05)
        // Equal slots, centred on the screen. A 7-seg "1" (right segments only) is shifted
        // to the middle of its slot so 1s don't leave a hole on one side.
        var d = [clock.hour / 10, clock.hour % 10, clock.min / 10, clock.min % 10];
        var x = TIME_CX - (DIG_W * 4 + COLON_W + DIG_GAP * 2) / 2;
        for (var i = 0; i < 4; i++) {
            var dx = d[i] == 1 ? -(DIG_W - DIG_T) / 2 : 0;
            Lcd.digit(dc, x + dx, TIME_Y, DIG_W, TIME_H, DIG_T, d[i]);
            x += DIG_W;
            if (i == 0 || i == 2) { x += DIG_GAP; }
            if (i == 1) {
                dc.fillRectangle(x + DIG_GAP, TIME_Y + 12, 5, 5);
                dc.fillRectangle(x + DIG_GAP, TIME_Y + 31, 5, 5);
                x += COLON_W;
            }
        }
    }

    // 8 px between everything; 4 wide digits span 8..165
    const TIME_CX = 87; const COLON_W = DIG_GAP + 5 + DIG_GAP;
    // Kyiv air quality | watch battery, at date size (scale 1 was unreadable on the watch).
    function drawBottom(dc as Dc, st) as Void {
        var q = airQuality();
        var aq = q.length() < 3 ? "AQI " + q : "AQI" + q;    // 3-digit AQI needs the room
        var bat = System.getSystemStats().battery.toNumber().toString();
        if (sub == null) {
            // Crossover: battery right of the hands' pivot, heart rate takes its bottom slot
            Lcd.text(dc, bat + "%", PIVOT_R, TEMP_Y, 2);
            var hr = heartRateNum();
            Lcd.text(dc, "*" + (hr == null ? "--" : hr.toString()), BOT_L, BOT_Y, 2);
            Lcd.textRight(dc, aq, BOT_R, BOT_Y, 2);
            return;
        }
        // "AQI105" + "100%" would collide: drop the % sign then
        if (Lcd.textWidth(aq, 2) + Lcd.textWidth(bat + "%", 2) + 10 <= BOT_R - BOT_L) { bat += "%"; }
        Lcd.text(dc, aq, BOT_L, BOT_Y, 2);
        Lcd.textRight(dc, bat, BOT_R, BOT_Y, 2);
    }

    function bodyBattery() as String {
        if (DEMO == 7) { return "64"; }
        if ((Toybox has :SensorHistory) && (SensorHistory has :getBodyBatteryHistory)) {
            var it = SensorHistory.getBodyBatteryHistory({:period => 1});
            var s = it != null ? it.next() : null;
            if (s != null && s.data != null) { return s.data.toNumber().toString(); }
        }
        return "--";
    }

    // European AQI for Kyiv, fetched by the background service every ~15 min.
    // 0-20 good, 20-40 fair, 40-60 moderate, 60-80 poor, 80-100 very poor, 100+ extremely poor.
    function airQuality() as String {
        if (DEMO == 7) { return "42"; }
        var a = Application.Storage.getValue("aq");
        if (!(a instanceof Array) || a[0] == null) { return "--"; }
        if (Time.now().value() - (a[1] as Number) > 3 * 3600) { return "--"; }
        return a[0].toString();
    }

    // subscreen: heart-rate gauge. Arc from 12 o'clock, clockwise, full circle = max HR.
    // Ticks mark where each HR zone starts; a tick inside the filled arc is cut out in black.
    // During an outage it shows the home battery instead: ring = SOC, centre = "87%".
    function drawSubscreen(dc as Dc, min as Number, p as Dictionary) as Void {
        if (sub == null) { return; }
        if (p[:mode] == :out) { socGauge(dc, p[:soc]); return; }
        if (min != zonesMin) { zones = hrZones(); zonesMin = min; }
        var max = zones[zones.size() - 1];
        var hr = heartRateNum();
        var frac = (hr == null) ? 0.0 : hr.toFloat() / max;
        if (frac > 1.0) { frac = 1.0; }

        dc.setColor(B, B);
        dc.fillCircle(subCx, subCy, subR);
        dc.setColor(W, T);
        var r = subR - 6;
        dc.drawCircle(subCx, subCy, r);                     // empty track
        dc.setPenWidth(5);
        if (frac >= 0.995) {
            dc.drawCircle(subCx, subCy, r);
        } else if (frac > 0.01) {
            dc.drawArc(subCx, subCy, r, Graphics.ARC_CLOCKWISE, 90, 90 - (360 * frac).toNumber());
        }
        dc.setPenWidth(2);
        for (var i = 0; i < zones.size() - 1; i++) {
            var zf = zones[i].toFloat() / max;
            dc.setColor(zf <= frac ? B : W, T);
            var a = 2 * Math.PI * zf;
            var s = Math.sin(a); var c = Math.cos(a);
            dc.drawLine((subCx + (r - 4) * s).toNumber(), (subCy - (r - 4) * c).toNumber(),
                        (subCx + (r + 3) * s).toNumber(), (subCy - (r + 3) * c).toNumber());
        }
        dc.setPenWidth(1);
        dc.setColor(W, T);
        Lcd.textCenter(dc, "*", subCx, subCy - 12, 1);
        Lcd.textCenter(dc, hr == null ? "--" : hr.toString(), subCx, subCy - 2, 2);
    }

    function socGauge(dc as Dc, soc) as Void {
        var frac = soc == null ? 0.0 : soc.toFloat() / 100.0;
        if (frac > 1.0) { frac = 1.0; } else if (frac < 0.0) { frac = 0.0; }
        dc.setColor(B, B);
        dc.fillCircle(subCx, subCy, subR);
        dc.setColor(W, T);
        var r = subR - 6;
        dc.drawCircle(subCx, subCy, r);
        dc.setPenWidth(5);
        if (frac >= 0.995) {
            dc.drawCircle(subCx, subCy, r);
        } else if (frac > 0.01) {
            dc.drawArc(subCx, subCy, r, Graphics.ARC_CLOCKWISE, 90, 90 - (360 * frac).toNumber());
        }
        dc.setPenWidth(1);
        // small bolt above the number
        var x = subCx; var y = subCy - 14;
        dc.drawLine(x + 2, y, x - 2, y + 5); dc.drawLine(x - 2, y + 5, x + 2, y + 5);
        dc.drawLine(x + 2, y + 5, x - 2, y + 10);
        var s = soc == null ? "--%" : soc.toNumber().toString();
        if (soc != null && soc.toNumber() < 100) { s += "%"; }
        Lcd.textCenter(dc, s, subCx, subCy - 2, 2);
    }

    // Zone starts + max from the Garmin profile (honours a measured max HR).
    // Fallback: 220 - age, zones at 50/60/70/80/90 %.
    function hrZones() as Array<Number> {
        if (Toybox has :UserProfile) {
            var z = UserProfile.getHeartRateZones(UserProfile.HR_ZONE_SPORT_GENERIC);
            if (z != null && z.size() >= 2 && z[z.size() - 1] > 100) { return z; }
        }
        var max = 190;
        var p = (Toybox has :UserProfile) ? UserProfile.getProfile() : null;
        if (p != null && p.birthYear != null) {
            max = 220 - (Gregorian.info(Time.now(), Time.FORMAT_SHORT).year - p.birthYear);
        }
        return [max * 50 / 100, max * 60 / 100, max * 70 / 100, max * 80 / 100, max * 90 / 100, max];
    }

    // No seconds and no onPartialUpdate: the face redraws once a minute in low power.
    function onEnterSleep() as Void { awake = false; WatchUi.requestUpdate(); }
    function onExitSleep() as Void { awake = true; WatchUi.requestUpdate(); }

    // ---------------- data helpers ----------------

    // [lat, lon] in degrees, cached in storage so the map dot survives without GPS/weather
    function getLocation() {
        var ll = null;
        var ai = Activity.getActivityInfo();
        if (ai != null && ai.currentLocation != null) {
            ll = ai.currentLocation.toDegrees();
        } else if (Toybox has :Weather) {
            var c = Weather.getCurrentConditions();
            if (c != null && c.observationLocationPosition != null) {
                ll = c.observationLocationPosition.toDegrees();
            }
        }
        if (ll != null) {
            Application.Storage.setValue("loc", ll);
            // for the background AQI fetch: rounded to 0.01 deg (~1 km), written only on change
            var s = ll[0].format("%.2f") + "," + ll[1].format("%.2f");
            if (!s.equals(Application.Properties.getValue("Loc"))) { Application.Properties.setValue("Loc", s); }
            return ll;
        }
        return Application.Storage.getValue("loc");
    }

    function sunEvent(loc, now) as String {
        if (loc == null || !(Toybox has :Weather) || !(Weather has :getSunrise)) {
            return "SUN --:--";
        }
        var pos = new Position.Location({:latitude => loc[0], :longitude => loc[1], :format => :degrees});
        var rise = Weather.getSunrise(pos, now);
        var set = Weather.getSunset(pos, now);
        var tag = "^";
        var t = rise;
        if (rise != null && now.greaterThan(rise)) {
            tag = "_"; t = set;
            if (set != null && now.greaterThan(set)) {
                tag = "^"; t = Weather.getSunrise(pos, now.add(new Time.Duration(86400)));
            }
        }
        if (t == null) { return "SUN --:--"; } // polar day/night
        var ti = Gregorian.info(t, Time.FORMAT_SHORT);
        return tag + ti.hour.format("%02d") + ":" + ti.min.format("%02d");
    }

    // 9x7 pixel weather icons, one int per row, bit 8 = leftmost pixel.
    // 0 sun, 1 partly cloudy, 2 cloud, 3 rain, 4 snow, 5 storm, 6 fog, 7 wind, 8 moon
    const ICONS = [
        [0x010, 0x082, 0x038, 0x1BB, 0x038, 0x082, 0x010],
        [0x00C, 0x01E, 0x06E, 0x0F6, 0x1F8, 0x1FC, 0x0F8],
        [0x030, 0x078, 0x0FE, 0x1FF, 0x1FF, 0x0FE, 0x000],
        [0x078, 0x0FE, 0x1FF, 0x0FE, 0x000, 0x092, 0x124],
        [0x078, 0x0FE, 0x1FF, 0x0FE, 0x000, 0x111, 0x044],
        [0x078, 0x0FE, 0x1FF, 0x0FE, 0x018, 0x030, 0x040],
        [0x000, 0x1FE, 0x000, 0x0FF, 0x000, 0x1FE, 0x000],
        [0x006, 0x1F9, 0x000, 0x1FE, 0x001, 0x1E2, 0x000],
        [0x070, 0x0C0, 0x180, 0x180, 0x180, 0x0C0, 0x070]
    ];
    // Weather.CONDITION_* (0..53) -> icon
    const COND_ICON = [0, 1, 2, 3, 4, 7, 5, 4, 6, 6, 3, 3, 5, 3, 3, 3, 4, 4, 4, 4, 2, 4, 1, 1,
                       3, 3, 3, 3, 5, 6, 6, 3, 7, 6, 4, 6, 7, 7, 6, 6, 0, 7, 5, 4, 4, 3, 4, 4,
                       4, 3, 4, 4, 1, 2];

    function drawIcon(dc as Dc, i as Number, x as Number, y as Number) as Void {
        var rows = ICONS[i];
        for (var r = 0; r < 7; r++) {
            var bits = rows[r];
            for (var c = 0; c < 9; c++) {
                if ((bits & (0x100 >> c)) != 0) { dc.fillRectangle(x + c, y + r, 1, 1); }
            }
        }
    }

    // temperature + icon, centred in the slot under the round window
    function drawWeather(dc as Dc, st) as Void {
        var s = "--#"; var icon = -1;
        if (DEMO == 8) {
            s = "-3#"; icon = 4;
        } else if (Toybox has :Weather) {
            var c = Weather.getCurrentConditions();
            if (c != null && c.temperature != null) {
                var t = c.temperature;
                if (st.temperatureUnits == System.UNIT_STATUTE) { t = t * 9 / 5 + 32; }
                s = t.toNumber().toString() + "#";
                if (c.condition != null && c.condition >= 0 && c.condition < COND_ICON.size()) {
                    icon = COND_ICON[c.condition];
                    if (icon == 0 && isNight(c)) { icon = 8; }
                }
            }
        }
        // Big temperature only (scale 1 was unreadable on the real screen). y=75 keeps it
        // below the round window's bezel and above the minute digits (which start at 89).
        // The pixel icons stay in the code (ICONS/drawIcon) in case we bring them back at 2x.
        if (sub == null) { Lcd.textRight(dc, s, PIVOT_L, TEMP_Y, 2); }   // left of the hands' pivot
        else { Lcd.textCenter(dc, s, 143, TEMP_Y, 2); }
    }

    function isNight(c) as Boolean {
        var now = Time.now();
        if ((Weather has :getSunrise) && c.observationLocationPosition != null) {
            var rise = Weather.getSunrise(c.observationLocationPosition, now);
            var set = Weather.getSunset(c.observationLocationPosition, now);
            if (rise != null && set != null) {
                return now.value() < rise.value() || now.value() > set.value();
            }
        }
        var h = System.getClockTime().hour;
        return h < 6 || h >= 18;
    }

    function weatherText(st) as Array<String> {
        if (!(Toybox has :Weather)) { return ["--#", ""]; }
        var c = Weather.getCurrentConditions();
        if (c == null || c.temperature == null) { return ["--#", "NO WX"]; }
        var t = c.temperature;
        var unit = "C";
        if (st.temperatureUnits == System.UNIT_STATUTE) { t = t * 9 / 5 + 32; unit = "F"; }
        var cond = "";
        if (c.condition != null && c.condition >= 0 && c.condition < WX.size()) { cond = WX[c.condition]; }
        return [t.toNumber().toString() + "#" + unit, cond];
    }

    function heartRateNum() as Number? {
        if (DEMO == 4) { return 142; }
        var hr = null;
        var ai = Activity.getActivityInfo();
        if (ai != null) { hr = ai.currentHeartRate; }
        if (hr == null && (ActivityMonitor has :getHeartRateHistory)) {
            var it = ActivityMonitor.getHeartRateHistory(1, true);
            var s = it.next();
            if (s != null && s.heartRate != ActivityMonitor.INVALID_HR_SAMPLE) { hr = s.heartRate; }
        }
        return (hr == null || hr <= 0) ? null : hr;
    }

    // Interprets the last background result. Keeps last good reading for up to 60 min.
    // DEMO: 0 = real data, 1 = outage, 2 = low volts, 3 = high volts (for screenshots only)
    const DEMO = 0;

    function powerState(now) as Dictionary {
        if (DEMO == 1) { return {:mode => :out, :soc => 87, :since => now.value() - 83 * 60, :old => false}; }
        if (DEMO == 2) { return {:mode => :grid, :v => 198, :old => false}; }
        if (DEMO == 3) { return {:mode => :grid, :v => 261, :old => false}; }
        var raw = Application.Storage.getValue("pwr");
        if (!(raw instanceof Dictionary)) { return {:mode => :none, :why => "NO DATA"}; }
        var d = raw as Dictionary;
        var age = now.value() - (d["t"] as Number);
        var sc = d["sc"]; var oc = d["oc"];
        var haveStatus = sc == 200 && d["v"] != null;
        var haveOut = oc == 200;
        if (!haveStatus && !haveOut) {
            var why = (sc == -104 || sc == -101) ? "NO PHONE" : "ERR " + sc;
            return {:mode => :none, :why => why};
        }
        if (age > 60 * 60) { return {:mode => :none, :why => "AGE " + (age / 60) + "M"}; }
        var out = false;
        if (haveOut && d["og"] == true) { out = true; }
        else if (haveStatus && (d["v"] as Numeric) < 50) { out = true; }
        // runtime estimate: usable Wh above the 10% floor / current load
        // (5166 Wh = capacity your dashboard measured)
        var rt = d["rt"];                               // server's own estimate wins
        var soc = d["soc"]; var w = d["w"];
        if (rt == null && soc != null && w != null && w > 20) {
            var wh = (soc - 10) * 5166.0 / 100.0;
            if (wh < 0) { wh = 0; }
            rt = (wh / w * 60).toNumber();
        }
        return {
            :mode => out ? :out : :grid,
            :v => d["v"], :soc => soc, :w => w, :rt => rt, :sc => sc,
            :since => d["og"] == true ? d["os"] : null,
            :old => age > 15 * 60 || d["stale"] == true
        };
    }

    function dayOfYear(y, m, d) as Number {
        var cum = [0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334];
        var n = cum[m - 1] + d;
        if (m > 2 && ((y % 4 == 0 && y % 100 != 0) || y % 400 == 0)) { n += 1; }
        return n;
    }
}

class InstinctFaceDelegate extends WatchUi.WatchFaceDelegate {
    var view;
    function initialize(v) { WatchFaceDelegate.initialize(); view = v; }
}
