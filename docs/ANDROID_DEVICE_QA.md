# Dhker Android — Device QA Checklist

This checklist is intentionally separate from CI. A successful GitHub Actions build does not prove that device hardware, notification delivery, or real audio playback works.

## Install and first launch
- [ ] Install the APK on a supported Android phone.
- [ ] Confirm the app launches without a crash.
- [ ] Confirm Arabic text and navigation render correctly.
- [ ] Confirm the app can be reopened after force-closing it.

## Offline behavior
- [ ] Open the app once while connected, then enable airplane mode.
- [ ] Open the Quran reader and browse multiple Mushaf pages.
- [ ] Open morning, evening, sleep, and waking adhkar.
- [ ] Change theme, clock style, and selected city; close and reopen the app to confirm preferences persist.
- [ ] Confirm no core offline screen becomes blocked by a network request.

## Adhan and notifications
- [ ] Preview both bundled OGG recordings from the Adhan screen.
- [ ] Assign different sounds to at least two prayers and confirm each preview uses the selected sound.
- [ ] Grant notification and exact-alarm permissions.
- [ ] Use a short test schedule or a controlled test device time to verify notification delivery and the selected notification-channel sound.
- [ ] Restart the device and confirm scheduled prayer notifications are restored or rescheduled.
- [ ] Repeat with battery optimization enabled and disabled; record Android version and manufacturer behavior.

## Location and compass
- [ ] Select Baghdad and verify prayer times are populated.
- [ ] Select another city and confirm times update.
- [ ] Grant location permission if the compass requests it.
- [ ] Calibrate the phone compass and compare the Qibla direction with a trusted local reference.

## Record the result
Record device model, Android version, app version, install result, offline result, both audio previews, notification result, reboot result, and compass result. Do not mark a section passed until it has been observed on the device.
