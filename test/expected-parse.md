# Validation set — 5 seed emails → 6 events

Seed emails (all forwarded 2026-06-15, from `yixuany@stanford.edu`):
1. Fw: Newsletter Week #0 — Stanford Summer Session 2026  *(digest → multiple)*
2. Fw: Confirmed: Stanford Photo Scavenger Hunt 2026  *(confirmation, has QR)*
3. Fw: You're Confirmed! Building a Better World: Pathways to Public Service  *(confirmation, has QR)*
4. Fw: You're Confirmed! Make Possibilities Happen | Grace Hawthorne  *(confirmation, has QR)*
5. Fw: You're Confirmed! Academic Resource Fair  *(confirmation, has QR)*

All times **America/Los_Angeles**. Confirmations 2–5 each duplicate a newsletter row → **merged**, not doubled.

| # | Event | Date | Start–End | All-day | Location | Calendar | Clean register link | QR | Source(s) |
|---|---|---|---|---|---|---|---|---|---|
| 1 | Bill due | 2026-06-20 | — | ✅ | — | 琐事 | — | — | newsletter |
| 2 | Welcome Weekend Day 1 | 2026-06-20 | — | ✅ | — | 社交-人们 | — | — | newsletter |
| 3 | Stanford Photo Scavenger Hunt | 2026-06-21 | 7:30 PM – 9:00 PM* | | Meet in the lounge | 社交-人们 | summerapply.stanford.edu/register/hssc-stanford-scav-hunt-2026 | from confirmation #2 | newsletter + confirm |
| 4 | Make Possibilities Happen \| Grace Hawthorne | 2026-06-21 | 11:00 AM – 12:30 PM | | d.school atrium | 学习-自主 | summerapply.stanford.edu/register/creator-2026 | from confirmation #4 | newsletter + confirm |
| 5 | Academic Resource Fair | 2026-06-21 | 2:00 PM – 3:00 PM | | Koret Pavilion, 564 O'Connor Ln | 学习-自主 | summerapply.stanford.edu/register/academic-resource-fair-2026 | from confirmation #5 | newsletter + confirm |
| 6 | Building a Better World: Pathways to Public Service | 2026-06-23 | 4:00 PM – 5:30 PM | | DK Room, Haas Center | 学习-自主 | summerapply.stanford.edu/register/public-service-2026 | from confirmation #3 | newsletter + confirm |

\* Scavenger Hunt: only a start time is given (7:30 PM) → end = start + 90 min default (social). Confidence medium on the end time only.

## What this exercises
- **Merge:** events 3–6 each came from two emails; QR taken from the confirmation, end-time + blurb + tidy location from the newsletter.
- **All-day:** events 1–2 have a date but no time.
- **Routing:** social (2,3) → 社交-人们; academic/workshop/talk (4,5,6) → 学习-自主; deadline (1) → 琐事.
- **Link cleaning:** registration URLs recovered from `title=`, not the `urldefense.com` wrapper.
- **Description** for #5 would read, e.g.:
  > Learn more about academic support, join clubs, and meet our tutors.
  > 📍 Koret Pavilion, 564 O'Connor Ln
  > 🔗 活动详情: …/register/academic-resource-fair-2026
  > 🔳 签到二维码（点开出示）: summerapply.stanford.edu/register/mobile?id=0002b9ac-…&cmd=barcode
  > [gmail:19ecac95d7d3519d]
