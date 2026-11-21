import Toybox.Application;
import Toybox.Background;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.WatchUi;

(:background)
class InstinctFaceApp extends Application.AppBase {
    function initialize() {
        AppBase.initialize();
    }

    function getInitialView() {
        if (Toybox.System has :ServiceDelegate) {
            // 5 min is the minimum Garmin allows for temporal events
            Background.registerForTemporalEvent(new Time.Duration(5 * 60));
        }
        var v = new InstinctFaceView();
        return [v, new InstinctFaceDelegate(v)];
    }

    function getServiceDelegate() {
        return [new StatusService()];
    }

    function onBackgroundData(data) {
        if (data != null) {
            Application.Storage.setValue("pwr", data);
            if (data instanceof Dictionary) {
                trackAlert(data);
                if (data["aq"] != null) { Application.Storage.setValue("aq", [data["aq"], data["t"]]); }
            }
        }
        WatchUi.requestUpdate();
    }

    // Kyiv alert: 3 = city whole (A), 2 = city partial (P), 1 = only the oblast, 0 = clear.
    // The IoT reply has no start time, so "since" = first poll that saw it (up to 5 min late).
    // Stored as "al" = [level, since, httpCode]; unknown (error / no token) keeps level null.
    function trackAlert(d as Dictionary) as Void {
        var code = d["ac"];
        System.println("alerts: code=" + code + " city=" + d["ak"] + " oblast=" + d["ao"]
            + " ubilling=" + d["uc"] + " kt=" + d["kt"] + " ot=" + d["ot"]);
        if (code == null) { Application.Storage.deleteValue("al"); return; }   // no token: feature off
        var prev = Application.Storage.getValue("al");
        var lv = null;
        if (code == 200 && d["ak"] != null) {
            var k = d["ak"]; var o = d["ao"];
            lv = k.equals("A") ? 3 : k.equals("P") ? 2 : (o != null && !o.equals("N")) ? 1 : 0;
        }
        var wasOn = prev instanceof Array && prev[0] != null && prev[0] > 0;
        if (lv == null) {
            // request failed: keep last known level/since, mark it unconfirmed via code
            Application.Storage.setValue("al", [wasOn ? prev[0] : null, wasOn ? prev[1] : null, code, d["t"]]);
            return;
        }
        // Real start from ubilling when we got it: city alert -> city time (exact, the city is
        // one area). Oblast -> its "changed", which moves forward whenever another district
        // joins, so during one continuous alert we keep the EARLIEST time ever seen.
        var real = lv >= 2 ? d["kt"] : (lv == 1 ? d["ot"] : null);
        var since = null;
        if (lv > 0) {
            var old = wasOn ? prev[1] : null;
            since = real != null ? real : (old != null ? old : d["t"]);
            if (old != null && (old as Number) < (since as Number)) { since = old; }
        }
        Application.Storage.setValue("al", [lv, since, code, d["t"]]);
    }

    function onSettingsChanged() {
        WatchUi.requestUpdate();
    }
}
