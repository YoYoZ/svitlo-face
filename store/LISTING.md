# Connect IQ Store listing: copy-paste text

**Title:** Svitlo Face
**Category:** Watch Faces
**Devices:** Instinct 2, Instinct 2X, Instinct 3 Solar 45mm, Instinct E 45mm, Instinct Crossover, Instinct Crossover AMOLED
**Icon:** `resources/drawables/launcher_icon.png` (62×62); the Crossover build uses
`resources-instinctcrossover/drawables/launcher_icon.png` (26×26)
**Screenshots:** this folder: `instinct2-*.png`, `instinctcrossover-*.png` (demo data only;
regenerate with `tools\storeshots.ps1`)

---

## Description (English)

A retro LCD watch face for Ukraine's power outages: the scheduled outages and whether the
power is actually on at your address, side by side, plus the air-raid alert for your area.

- PWR ON / OFF 1:23: actual power at a СвітлоБот point near you
- 6-hour bar: hatched = scheduled outage, solid = actual outage, dotted = emergency outages
- Air-raid alert for Kyiv or your oblast takes over the date row, with how long it has been on
- Heart rate, temperature, air quality (European AQI) at your location, battery

Setup (Garmin Connect app → watch face settings): pick the schedule supplier and your queue,
a СвітлоБот channel near you, and the alert area. No account, no sign-up.

NOT AN OFFICIAL WARNING SYSTEM. Data arrives every 5 minutes at best, through your phone.
Never rely on it instead of sirens or official alert apps.

Data: schedules: YASNO; electricity: СвітлоБот (svitlobot.in.ua); alerts: NEPTUN
(neptun.in.ua); air quality: Open-Meteo.
Source code: https://github.com/YoYoZ/svitlo-face

## Опис (українською)

Ретро-циферблат для відключень світла: графік відключень і реальний стан світла за вашою
адресою поруч, а також повітряна тривога для вашої області.

- PWR ON / OFF 1:23: чи є світло зараз (точка СвітлоБота поруч із вами)
- Смуга на 6 годин: штрихування — відключення за графіком, суцільне — реальне,
  пунктир — діють аварійні відключення
- Тривога для Києва або вашої області замінює рядок з датою і показує, скільки вона триває
- Пульс, температура, якість повітря (European AQI) за вашим місцезнаходженням, заряд

Налаштування (Garmin Connect → налаштування циферблата): постачальник графіка і ваша черга,
канал СвітлоБота поруч і регіон тривог. Без акаунта і реєстрації.

НЕ Є ОФІЦІЙНОЮ СИСТЕМОЮ ОПОВІЩЕННЯ. Дані оновлюються щонайбільше раз на 5 хвилин через
телефон. Не покладайтеся на них замість сирен і офіційних застосунків.

Дані: графіки — YASNO; світло — СвітлоБот (svitlobot.in.ua); тривоги — NEPTUN
(neptun.in.ua); якість повітря — Open-Meteo.

---

## Why it asks for these permissions

- **Background**: fetches the schedule / power / alert status every 5 minutes
- **Communications**: internet through the phone, for the requests above
- **Positioning**: the location for the air-quality reading, rounded to ~1 km; it is sent
  only to Open-Meteo

## Before uploading

- Back up `%USERPROFILE%\ConnectIQ\developer_key.der`: without it the app can never be updated
- Upload `bin\SvitloFace.iq` (built with `monkeyc -e -r`)
