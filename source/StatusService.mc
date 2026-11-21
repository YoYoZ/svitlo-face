import Toybox.Application;
import Toybox.Background;
import Toybox.Communications;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;

// Every 5 min (background, 32 KB RAM): one GET to the public API through the phone.
// The user's settings travel as query parameters; the server keeps nothing about them.
// Reply is a flat JSON of short keys (usually 100-250 B, worst case < 1.5 KB).
// A missing key means "unknown", never "no": the face shows ?? for it.
(:background)
class StatusService extends System.ServiceDelegate {
    const API = "https://toys.antonsoliaryk.link/v1/w";
    const PROVIDERS = ["", "kyiv", "dnipro-dnem", "dnipro-cek"];
    const PLACES = ["", "kyiv", "vinnytska", "volynska", "dnipropetrovska", "donetska",
        "zhytomyrska", "zakarpatska", "zaporizka", "ivano-frankivska", "kyivska",
        "kirovohradska", "luhanska", "lvivska", "mykolaivska", "odeska", "poltavska",
        "rivnenska", "sumska", "ternopilska", "kharkivska", "khersonska", "khmelnytska",
        "cherkaska", "chernivetska", "chernihivska", "crimea", "sevastopol"];
    const KEYS = ["pl", "nx", "em", "tw", "og", "os", "fa", "dc", "ak", "kt", "ao", "ot",
                  "tl", "src", "e"];

    var res = {} as Dictionary;
    var place = false;

    function initialize() {
        ServiceDelegate.initialize();
    }

    function onTemporalEvent() as Void {
        var q = {} as Dictionary;
        var s = listValue("Provider", PROVIDERS);
        if (s != null) {
            q["s"] = s;
            q["q"] = text("Queue");          // empty queue with a provider -> server says e=q
        }
        var sb = text("SvitloBot");
        if (sb.length() > 0) { q["sb"] = sb; }
        var a = listValue("AlertPlace", PLACES);
        if (a != null) { q["a"] = a; place = true; }
        res = {"t" => Time.now().value(), "cfg" => q.size() > 0};
        Communications.makeWebRequest(API, q, {
            :method => Communications.HTTP_REQUEST_METHOD_GET,
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
        }, method(:onWatch));
    }

    function onWatch(code as Number, data as Dictionary or String or Null) as Void {
        res["sc"] = code;
        if (code == 200 && data instanceof Dictionary) {
            for (var i = 0; i < KEYS.size(); i++) {
                if (data.hasKey(KEYS[i])) { res[KEYS[i]] = data[KEYS[i]]; }
            }
            // light now: known only when the SvitloBot point reported its status
            res["oc"] = data.hasKey("og") ? 200 : -1;
            res["kc"] = data.hasKey("pl") ? 200 : -1;
            // alert: 200 = fresh, -2 = place chosen but no data (keep last, shown as stale),
            // null = no place chosen (feature off)
            res["ac"] = data.hasKey("ak") ? 200 : (place ? -2 : null);
        } else if (code == -104 || code == -101) {     // no phone: keep last data, skip AQI
            res["ac"] = place ? code : null;
            Background.exit(res);
            return;
        } else {
            res["ac"] = place ? code : null;
        }
        data = null;
        afterPower();
    }

    // ---- air quality at the watch's own last position (open-meteo, keyless, ~300 B).
    // The face writes it, rounded to 0.01 deg (~1 km), into the hidden "Loc" property.
    // Upstream updates hourly, so ask only in the first 5 min of each quarter hour. ----
    const AQ_URL = "https://air-quality-api.open-meteo.com/v1/air-quality";

    function afterPower() as Void {
        var loc = text("Loc");
        var comma = loc.find(",");
        if (comma == null || System.getClockTime().min % 15 >= 5) {
            Background.exit(res);
            return;
        }
        Communications.makeWebRequest(AQ_URL, {
            "latitude" => loc.substring(0, comma), "longitude" => loc.substring(comma + 1, loc.length()),
            "current" => "european_aqi"
        }, {
            :method => Communications.HTTP_REQUEST_METHOD_GET,
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
        }, method(:onAqi));
    }

    function onAqi(code as Number, data as Dictionary or String or Null) as Void {
        if (code == 200 && data instanceof Dictionary) {
            var c = data["current"];
            if (c instanceof Dictionary && c["european_aqi"] != null) {
                res["aq"] = (c["european_aqi"] as Numeric).toNumber();
            }
        }
        Background.exit(res);
    }

    // ---- settings helpers ----
    function text(key as String) as String {
        var v = Application.Properties.getValue(key);
        return v == null ? "" : v.toString();
    }

    function listValue(key as String, ids as Array) as String? {
        var v = Application.Properties.getValue(key);
        if (!(v instanceof Number) || v <= 0 || v >= ids.size()) { return null; }
        return ids[v] as String;
    }
}
