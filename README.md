# Svitlo Face

A retro LCD watch face for Garmin Instinct 2 (Connect IQ) for Ukraine's power outages:
the **scheduled** outages and what **actually** happened at your address, side by side,
plus the air-raid alert for your area.

> **Не є офіційною системою оповіщення.** Not an official warning system. Data arrives
> every 5 minutes at best, through your phone. Never rely on it instead of sirens or
> official alert apps.

## What it shows

```
 ┌──────────────┐  ( HR )     power now: PWR ON / OFF 1:23 / PWR ?? (unknown)
 │  PWR ON      │  (gauge)    bar: 3 h back … now ▲ … 3 h ahead
 ├──────────────┤               hatched = scheduled outage (YASNO)
 [▒▒  ███   ▒▒▒▒]               solid   = actual outage (СвітлоБот)
 [SAT][21.11]   5°            dotted bar outline = emergency outages, schedule suspended
   21:43                      date row turns into the alert when one is on:
 AQI 28    50%                  RED / YEL (city) or OBL (oblast) + how long
```

- Round window: heart rate; ring = share of your max HR, ticks = HR zones.
- Bottom: European AQI at the watch's own location (rounded to ~1 km), watch battery.
- `SET UP`, `SET Q`, `SET SB`, … in the top panel: a setting is empty or wrong.

## Settings (Garmin Connect app → watch face settings)

| Setting | What it does |
|---|---|
| Outage schedule supplier | Whose schedule to show: Київ (ДТЕК), Дніпро (ДнЕМ), Дніпро (ЦЕК) |
| Schedule queue | Your queue as `N.M` |
| СвітлоБот channel | The channel of a point on the svitlobot.in.ua map near you: actual on/off |
| Air-raid alert area | Київ (city) or an oblast |

There is no account and no sign-up. The settings are sent with every request; the server
stores nothing about you.

## Data sources

- Графіки: **YASNO**
- Electricity data by **СвітлоБот** (svitlobot.in.ua), with thanks
- Тривоги: **NEPTUN** — neptun.in.ua
- Air quality: **Open-Meteo** (open-meteo.com)

All of it is relayed by a small public API (`/v1/w`); the watch only talks to it and to
Open-Meteo.

## Building

Connect IQ SDK 9.x and a developer key (`%USERPROFILE%\ConnectIQ\developer_key.der`):

```powershell
.\build.ps1 -Run     # builds bin\InstinctFace.prg and loads it into the simulator
```
