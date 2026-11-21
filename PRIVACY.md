# Svitlo Face: Privacy Policy

*Last updated: 21 November 2026*

Svitlo Face is a watch face for Garmin watches. It has no accounts, no sign-up, no ads, no
analytics and no tracking. This page lists everything that leaves your watch.

## What is sent, to whom, and why

**1. Your watch face settings → the Svitlo Face API** (`toys.antonsoliaryk.link`)
Every ~5 minutes the face asks for the current status. The request contains only the
settings you entered in Garmin Connect:

- the outage schedule supplier and your queue number,
- the СвітлоБот channel you chose,
- the air-raid alert area.

The answer is the schedule, whether the power is on at that СвітлоБот point, and the alert
status. The API does not store your settings or build any profile. Like any website, the
server and its network provider may keep standard technical logs (IP address, time, request)
for a limited time, used only to keep the service running and protect it from abuse.

**2. Your approximate location → Open-Meteo** (`open-meteo.com`)
For the air-quality reading, the face sends your location **rounded to about 1 km**
(two decimal places of latitude/longitude) to Open-Meteo's public air-quality API, at most
every 15 minutes. Nothing else is sent with it. Open-Meteo's own privacy policy applies:
https://open-meteo.com/en/terms

Both requests go through your phone's Garmin Connect app, as for every Connect IQ app.

## What is stored

Only on your watch: the last answers (to show them between updates) and the last rounded
location. The rounded location is kept in a hidden setting of the face, so it may also be
synced with the face's settings in your Garmin Connect app, like any watch face setting.
Removing the watch face deletes it.

## What is not done

- No personal data is sold, shared for advertising, or used for anything else.
- No account, name, e-mail, phone number or Garmin user ID is collected.
- Heart rate, battery and other sensor values are shown on the watch only and never sent.

## Contact

Questions or requests: open an issue at https://github.com/YoYoZ/svitlo-face/issues

---

## Українською (коротко)

Без акаунтів, реклами й аналітики. Циферблат надсилає: (1) ваші налаштування (постачальник і
черга, канал СвітлоБота, регіон тривог) на сервер Svitlo Face, щоб отримати графік, стан
світла й тривоги. Сервер їх не зберігає, лише стандартні технічні журнали (IP, час, запит)
обмежений час; (2) місцезнаходження, округлене до ~1 км, до Open-Meteo для якості повітря.
Пульс та інші дані з датчиків нікуди не надсилаються. Питання: GitHub Issues за посиланням вище.
