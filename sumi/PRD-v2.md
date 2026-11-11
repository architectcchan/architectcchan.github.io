# Sumi V1: Product Requirements Document (v2, "Hatch")

**Version:** 2.0 (Nov 11, 2026). Supersedes v1.1 ("passive mirror") on every point they conflict on. A changelog vs. v1.1 is at the end.
**Platform:** Native iOS only. Swift + SwiftUI. Minimum iOS 17.0.
**One sentence:** Put your phone down. Go to sleep. See what hatched when you wake up.

> Labels:
> - **[FACT]** backed by a named source (Apple docs, a company page).
> - **[JUDGMENT]** a product or engineering opinion. It can change.
> - **[TARGET]** a goal we set ourselves, not a benchmark.
> - **[VERIFY]** not confirmed. Prove it on a real device (Slice 0.5) before building on it.

---

## 0. Instructions for the AI coding assistant (read first)

1. **Build slice by slice** (Section 12). Finish a slice, meet its acceptance criteria, then stop and summarize what was built, tested, and left. Wait for the founder's go-ahead.
2. **Ask before adding scope.** List ideas under "Suggestions (not built)". Never build Section 13 (Out of scope).
3. **Every change must compile** with zero errors and no new warnings. If you are not sure an API exists or behaves as described, say so and propose a device check. Do not invent APIs. Screen Time APIs are the highest-risk area (Section 6).
4. **Rules live in `SumiCore`** (pure Swift, Foundation only, no UIKit/SwiftUI/FamilyControls imports). It has unit tests for every rule in Sections 4 and 5. CI runs them on every push (`.github/workflows/sumi-core.yml`).
5. **Stack is fixed:** Swift 5.10+, SwiftUI, Observation (`@Observable`) + plain MVVM, SwiftData (CloudKit OFF), FamilyControls + ManagedSettings + DeviceActivity, UserNotifications (local only), Swift Package Manager only, PostHog (analytics), Sentry (crashes, Slice 3). No backend in V1. No HealthKit in V1.
6. **Hard rules:**
   - **Reward behavior the user controls** (phone stayed down), **never sleep physiology** (hours, stages, scores).
   - **Never punish.** Nothing is ever lost: no decay, no dying creature, no "streak broken" copy.
   - **No medical claims.** Sumi is a bedtime game, not a sleep tracker.
   - **Nothing bright or urgent after bedtime.** All night UI is near-black and dim.
   - **Never say "verified".** Sumi cannot see everything on the phone (Section 6.4).

---

## 1. Product summary

### 1.1 What Sumi is
A bedtime commitment game. The user picks a bedtime and wake time once. Every night at bedtime, Sumi **automatically locks the apps the user chose** (TikTok, Instagram, YouTube...) until wake time. While the phone stays down, an egg incubates. In the morning, the user opens Sumi and the egg cracks, wobbles, or hatches into a creature for their collection.

Opening a locked app is allowed, but it has a visible cost: a **receipt** ("PAID WITH: 10 MIN OF SLEEP"). The egg never dies. It just warms more slowly.

### 1.2 The pain
- "Revenge bedtime procrastination": staying up scrolling to win back time the day took. People know the phone is the problem and still fail their own bedtime rules.
- Sleep trackers measure the damage after the fact. They don't stop the scroll at 12:40 a.m.
- Screen-time blockers are generic and joyless, and they don't make the morning feel like a reward.

### 1.3 Target user (ICP)
**Adults 18 to 30 who scroll in bed, know it, and keep failing their own bedtime.** They like collectible and mascot aesthetics and do not want clinical sleep coaching. iPhone only.

Not for V1: minors (Screen Time works differently for child accounts, and sleep plus consent), clinical use, shift workers with rotating schedules (supported later), Android.

### 1.4 Positioning
| Product | What it does | Why Sumi is different |
|---|---|---|
| Brainrot (Screen Time Control) | General app blocker with a mascot whose health tracks screen time | Sumi is only about bedtime: one job, one moment, with a morning payoff. **Biggest threat:** Brainrot already has a "Bedtime" preset and could ship a night feature fast. Speed and focus are the defense. |
| Pokémon Sleep | Sleep tracking, then a morning creature reveal and a deep daytime game | Sumi has no daytime chores and no phone on the mattress. The reward comes from putting the phone down, not from sensor-measured sleep. |
| SleepTown | Start a session, stay off the phone, a building grows | Closest concept. Sumi adds a real app lock with a receipt (friction at the moment of temptation) and a creature collection instead of buildings. |
| Sleep Cycle / Rise | Trackers and coaches | Sumi makes no measurements and no health claims. |

### 1.5 V1 success in one line
[TARGET] Testers keep the phone down on at least 4 nights a week, a month in, because they want tomorrow's hatch.

---

## 2. Core loop

```
Once:     Onboarding → pick bedtime + wake time → pick apps to lock → egg placed
Nightly:  T−30 min: one gentle notification ("Your egg is getting cozy")
          Bedtime: the lock turns on by itself (scheduled, no tap needed)
          If a locked app is opened: shield → "Ask Sumi" → receipt → 5/10/15 min unlock
          Wake time: the lock turns off by itself
Morning:  Open Sumi → reveal (egg warmer / cracks / hatches) in < 10 s → maybe share → close
```

**Key decision [JUDGMENT]: the night starts automatically.** A nightly "Start Night" tap is a habit the user has to build. A scheduled lock is a habit the user can only break. The user can pause any single night ahead of time (sick, travelling, party), and a paused night costs nothing.

---

## 3. Screens

### 3.0 Global rules
- Portrait only. Dark-first night palette (deep navy to near-black, warm amber accents). Morning screens use a soft dawn palette.
- One primary action per screen. Dynamic Type supported on text screens.
- Haptics: light on reveal, success on hatch. Reduce Motion: cross-fade to still poses.
- Example copy below. Final copy lives in `Localizable.xcstrings`. English only.

### 3.1 Onboarding (target 12 to 16 screens, ≤ 2.5 min)
| # | Screen | Primary action | Notes |
|---|---|---|---|
| 1 | Hook: "Put your phone down. Wake up to something." | Continue | Egg wobbles |
| 2 | Quiz: "What keeps you up?" (scrolling / videos / games / messages / work) | Multi-select | One question per screen |
| 3 | Quiz: "When do you usually put your phone down?" | Time wheel | Stored as `usualPhoneDown` |
| 4 | Quiz: "When do you want to be asleep?" | Time wheel | Becomes `bedtime` |
| 5 | Quiz: "When do you wake up?" | Time wheel | Becomes `wakeTime` |
| 6 | Quiz: "Have you tried to stop before?" (Screen Time limits / Do Not Disturb / willpower / nothing) | Select | |
| 7 | **Interactive slider:** drag bedtime from 23:00 to 02:30. The egg gets colder and the night sky loses its stars. | Drag | Brainrot's rot slider, never gross or sad |
| 8 | **Profile result:** e.g. "The Revenge Scroller: you take your time back at night." | Continue | Archetype from answers (Section 4.6). Identity, not diagnosis |
| 9 | **Honest projection:** "Scrolling from {usualPhoneDown} to {bedtime} is about {X} hours a week." | Continue | Show the math in small text. No lifetime-years scare numbers |
| 10 | How it works: 3 cards (lock at bedtime → receipt if you cheat → hatch in the morning) | Continue | |
| 11 | Screen Time pre-permission: "Sumi locks the apps you pick, only during your night." | Allow Screen Time | Then system sheet (`AuthorizationCenter.requestAuthorization(for: .individual)`) |
| 12 | Pick apps to lock (`FamilyActivityPicker`) | Done | Suggest categories: Social, Entertainment |
| 13 | Notification pre-permission: "One nudge before bed. One in the morning. That's it." | Yes / No thanks | |
| 14 | **Commitment:** hold the egg to place it ("Hold to keep it warm tonight") | Hold 2 s | Brainrot's hold-to-commit |
| 15 | Egg placed: "Your first night starts at {bedtime}. See you in the morning." | Done | |

Rules: no account, no email. If Screen Time is denied, onboarding continues; Home shows "Sumi needs Screen Time to lock your apps" with a retry. No paywall in onboarding for V1 (Section 8).

### 3.2 Home (day)
- Egg (or the latest creature) about 55% of the screen, with an idle animation.
- Line: "Tonight: lock at 23:30 · unlock at 07:30".
- Chip: "Good nights this week: 4". Never "streak lost".
- Primary: "Collection". Secondary: "Pause tonight", "Edit night".
- Top right: settings.

### 3.3 Home (night, after the lock starts)
- Near-black screen, small sleeping egg, the time, and "Sumi is keeping your egg warm." Nothing else.
- Opening Sumi at night does not count against the user.

### 3.4 Shield (when a locked app is opened)
Built with `ShieldConfigurationDataSource`. Title: "It's {time}. Your egg is sleeping." Subtitle: "Unlocking costs sleep." Primary button: "Close app". Secondary button: "Ask Sumi". [VERIFY: how the secondary button can lead into Sumi, Section 6.3]

### 3.5 Receipt (the core friction moment)
- Sumi asks "A little scrolling? How long?" with options 5 / 10 / 15 min and a big "Never mind" button.
- A receipt slides in: date, time, "1× SCROLL BREAK · 10 MIN", "PAID WITH: 10 MIN OF SLEEP". The user signs with a finger. "PAID" stamp. "See you in 10 minutes."
- The selected apps unlock for the chosen minutes, then lock again by themselves.
- Max 3 receipts a night. After that: "Sumi's out of receipts tonight." The secondary button only offers "Emergency unlock" (ends tonight's lock; the night becomes restless, Section 4.3).

### 3.6 Morning reveal (first open after wake time)
1. "Tue, Nov 10 · last night" and one line about the night ("Phone down all night. The egg is toasty.").
2. The egg animation for the outcome (Section 5.4): warmer glow, crack, or hatch.
3. On a hatch: the creature pops out, name card, "New!" or "Evolved!" badge.
4. Primary: "Share" (image card). Secondary: "Collection".
Under 10 seconds from open to done.

### 3.7 Collection
- A silhouette grid of all species (the "???" slots). Owned species show the current evolution stage.
- Tap a species: art, name, one-line bio, stage dots (1 to 3), the date it hatched.
- Header: "Nights together: 23."

### 3.8 Settings
- Night: bedtime, wake time, locked apps, which days the lock runs (default every day), "Pause tonight".
- Notifications: bedtime nudge on/off, morning nudge on/off.
- Privacy: what Sumi can and can't see (Section 9), "Delete all Sumi data".
- About, feedback, version. Debug menu in DEBUG/TestFlight builds (force outcomes, replay hatch, reset).

---

## 4. Night rules (implemented in `SumiCore`)

### 4.1 The night window
- `bedtime` and `wakeTime` are wall-clock times (hour, minute) in the user's current time zone.
- A night is keyed by its **evening date** ("the night of Nov 10").
- If `bedtime` is at or after 12:00, the window starts on the evening date. If it is before 12:00 (e.g. 01:00), it starts on the next calendar day.
- The window ends at the first `wakeTime` after the start.
- A valid plan is **3 to 14 hours** long. The onboarding wheels enforce this.
- All instants are absolute `Date`s computed with `Calendar` in the plan's time zone, so DST is handled by `Calendar`.

### 4.2 Night events
Logged by the app and the Screen Time extensions into the shared App Group store:
- `lockStarted(at)` at the start of the window (from `DeviceActivityMonitor.intervalDidStart`).
- `receipt(at, minutes)` when the user signs a receipt.
- `emergencyUnlock(at)` when the user ends tonight's lock.
- `lockEnded(at)` at wake time.
- `paused` when the user paused this night before it started.

### 4.3 Night outcome (first match wins)
| # | Condition | Outcome | Warmth |
|---|---|---|---|
| N0 | night was paused | `paused` | 0, no penalty, does not count as a missed night |
| N1 | no `lockStarted` | `notStarted` | 0 |
| N2 | `emergencyUnlock` during the window | `restless` | 0 |
| N3 | receipt minutes inside the window > 15 | `restless` | 0 |
| N4 | receipt minutes inside the window 1 to 15 | `mostlyCalm` | 1 |
| N5 | otherwise | `calm` | 2 |

- Receipts outside the window are ignored. Receipt minutes are clipped to the window end.
- The thresholds (`mostlyCalmMaxMinutes = 15`) are config values, tunable by feature flag.
- **No outcome ever removes warmth or a creature.** `restless` just means the egg didn't warm up.

### 4.4 Counters
- **Nights together:** count of nights with `lockStarted` (showing up counts, even if restless). Never goes down.
- **Good nights this week:** `calm` + `mostlyCalm` nights in the last 7 nights.
- **Glow streak:** consecutive good nights (`calm` or `mostlyCalm`). A `paused` night does not break it. It is only ever shown as a positive ("3 cozy nights in a row ✨"). When it resets, nothing is shown.

### 4.5 Pause
- The user can pause the next night any time before its lock starts. Limit: 2 pauses per 7 nights [JUDGMENT; stops "pause every night" from gaming the glow streak]. Beyond that, the night simply runs.

### 4.6 Archetypes (onboarding result)
Picked from the quiz, in this order:
1. "The Revenge Scroller": main thing keeping them up is scrolling or videos, and `usualPhoneDown` is 60+ min after `bedtime`.
2. "The Night Owl": `bedtime` is at or after 01:00.
3. "The Just-One-More": main thing is games or videos.
4. "The Always-On": main thing is messages or work.
5. Fallback: "The Almost-There".
No diagnosis language. Copy is affectionate.

---

## 5. Hatching and collection (implemented in `SumiCore`)

### 5.1 Eggs and warmth
- One egg incubates at a time. It hatches at **4 warmth**: two calm nights, or any mix that reaches 4.
- Morning reveal states: warmth 0 → "the egg is resting", 1 → "a little warmer", 2 to 3 → "it cracked!", reaching 4 → hatch, and a new egg appears.
- Leftover warmth does not carry over [JUDGMENT; keeps the math simple].

### 5.2 What hatches
- Starter catalog: **12 species**, each with **3 evolution stages** (36 art poses). Rarity tiers: common (6), uncommon (4), rare (2). Weights 60 / 30 / 10.
- **Glow bonus:** each night of the glow streak beyond 1 adds +2 to the uncommon weight and +1 to the rare weight, **capped at +10 / +5**. Consistency helps, but there is no runaway.
- **Duplicates evolve.** If the rolled species is already owned and below stage 3, it evolves (+1 stage) instead of adding a copy. If it is already at stage 3, re-roll among species that are not maxed. If everything is maxed, the collection is complete: show a "complete" celebration and keep giving evolutions as cosmetic sparkles. (V1.1 adds new creature families.)
- Full collection takes 36 hatches × 2 good nights = **about 72 good nights** at the fastest. That covers the D30 test window. [JUDGMENT]

### 5.3 Deterministic rolls
- Every roll uses a seeded random generator (SplitMix64). Seed = hash of the install seed and the night key.
- Re-opening the app, reinstalling (with the same install seed), or re-running the engine gives **the same result**. This prevents "re-roll by reopening" and makes the logic testable.

### 5.4 Reveal result
`MorningReveal` = night outcome + warmth before and after + (optional) hatch result (species, new or evolved, stage) + the counters. The UI renders this and nothing else.

---

## 6. Screen Time architecture (iOS)

### 6.1 Components
| Target | Framework | Job |
|---|---|---|
| Sumi app | FamilyControls, ManagedSettings, DeviceActivity | Authorization, app picker, schedule setup, receipts, reveal |
| `SumiMonitor` extension | `DeviceActivityMonitor` | `intervalDidStart`: apply shields, log `lockStarted`. `intervalDidEnd`: clear shields, log `lockEnded`. Threshold events re-lock after a receipt |
| `SumiShield` extension | `ShieldConfigurationDataSource` | Custom shield look and copy |
| `SumiShieldAction` extension | `ShieldActionDelegate` | Handles "Close app" and "Ask Sumi" |
| App Group `group.<bundle>.sumi` | `UserDefaults(suiteName:)` / shared file | Event log, settings, selection (`FamilyActivitySelection` is `Codable`) |

### 6.2 Nightly schedule
`DeviceActivityCenter().startMonitoring(.night, during: DeviceActivitySchedule(intervalStart: bedtime, intervalEnd: wakeTime, repeats: true))`. [FACT: Apple DeviceActivity docs describe schedules with start and end `DateComponents` and `repeats`.] [VERIFY: a schedule that crosses midnight, e.g. 23:30 to 07:30, fires `intervalDidStart`/`intervalDidEnd` correctly every night.]

### 6.3 Receipts and temporary unlocks: open questions to prove in Slice 0.5
1. [VERIFY] **Getting from the shield into Sumi.** `ShieldActionDelegate` returns `.close`, `.defer`, or `.none`; it cannot open the app directly. Candidate: on "Ask Sumi", post a local notification ("Tap to ask Sumi") whose tap deep-links to the receipt screen. Measure how many taps this takes and whether it feels OK.
2. [VERIFY] **Timed unlock.** Removing shields is easy (`store.shield.applications = nil`). Re-locking after N minutes is the hard part. Candidate A: a `DeviceActivityEvent` with a usage threshold of N minutes on the selected apps; `eventDidReachThreshold` re-applies the shield (this also measures real use). Candidate B: a short one-off schedule (Apple may require ≥ 15 min intervals). Pick whichever works reliably.
3. [VERIFY] Extensions can write to the App Group store and post local notifications.
4. [VERIFY] Behavior when the user revokes Screen Time access mid-night (log `permissionLost`; treat as `notStarted` if before bedtime, otherwise the night keeps its events).
5. [FACT, Apple] Distribution needs the **Family Controls (Distribution) entitlement**, requested from Apple. Development builds work without it. **Request it before Slice 1 starts.**

### 6.4 What Sumi cannot see (honesty rule)
Sumi does not see total phone use, pickups, browsing, or anything outside the selected apps. Someone can scroll Safari or turn off Sumi's access. That's acceptable: Sumi is a commitment device, not a cop. Copy never says "verified" or "we know you were on your phone".

---

## 7. Notifications (local only)
| When | Copy (example) | Rule |
|---|---|---|
| Bedtime − 30 min | "Your egg is getting cozy. Lock starts at 23:30." | On by default, one per night, never after bedtime |
| Wake time + 5 min | "Something happened to your egg overnight 👀" | Only if the night was `calm` or `mostlyCalm` |
| Never | "Your streak is about to die", any ping between bedtime and wake time | Banned |

---

## 8. Monetization in V1 (TestFlight)
- Everything is free during the beta.
- **Fake-door paywall** on the morning of the 3rd hatch: "Sumi+: new creature families, more eggs, custom egg skins. $29.99/year." Buttons: "Start free trial" → "Sumi+ is coming soon, you'll get it free in the beta 💛" / "Not now". Log both taps. [JUDGMENT: measures willingness to pay before building paid content.]
- Never sell anything that changes the night rules (no paid extra receipts, no paid warmth). Monetize content and customization only.

---

## 9. Data and privacy
- No account. Anonymous install ID (UUID in Keychain) and install seed (UInt64).
- On device only: plan, night events, outcomes, collection. SwiftData + App Group store, CloudKit OFF.
- `FamilyActivitySelection` tokens are opaque; Sumi never learns app names in readable form.
- Analytics (PostHog) carry only enums and counts: outcome, receipts count, warmth, hatch rarity, onboarding step. Never app names, never times with dates.
- "Delete all Sumi data" stops monitoring, clears shields, wipes stores, resets the install ID, and returns to onboarding.
- App Store: no HealthKit in V1. Privacy label: Identifiers (random ID) and Usage Data for analytics, not linked to identity.

---

## 10. Share card
- Image only in V1: 1080 × 1920 PNG. Morning dawn palette.
- Content: "Night of Nov 10", the creature (or the egg), one line ("Phone down all night. Moonmoth hatched."), optional receipt count ("0 receipts" is a flex), wordmark "sumi".
- System share sheet (`ShareLink`). Save to Photos with add-only permission.

---

## 11. Metrics and kill bars
**North star: Successful Night Rate** = good nights (`calm` + `mostlyCalm`) ÷ nights with a scheduled lock.

| Metric | Continue | Warning |
|---|---|---|
| Onboarding → apps picked | > 65% | < 45% |
| First night: lock started | > 85% | < 70% |
| Successful Night Rate (first 7 nights) | > 60% | < 40% |
| Morning reveal opened (after a good night) | > 75% | < 55% |
| D1 / D7 / D30 retention (morning opens) | > 55% / 30% / 15% | < 40% / 20% / 10% |
| Good nights per active user per week at D30 | ≥ 4 | < 2.5 |
| Emergency unlock rate | < 15% of nights | > 30% |
| Fake-door "Start free trial" taps | ≥ 8% of users who see it | < 3% |
| Share: users who share at least once in week 2 | ≥ 10% | < 5% |

**Falsifiers (read at day 14, minimum 30 testers past their first night):**
- F1: Successful Night Rate < 40% → the lock or the reward isn't strong enough. Interview 10 testers before changing anything.
- F2: Hatch views don't drive return (testers with a hatch in week 1 retain no better than testers without) → the reward thesis is weak.
- F3: Emergency unlock > 30% → friction is too high or bedtime targets are unrealistic. Fix onboarding defaults first.
- F4: Anyone feels shamed → release blocker.

Planned experiment (Slice 3, if tester count allows): mystery hatch vs. a plain streak counter, randomized at install.

---

## 12. Build plan (vertical slices)

### Slice 0: `SumiCore` engine + CI ✅ (done: 48 tests green in CI)
Pure Swift package `sumi/SumiCore`: night window, events, outcomes, counters, archetypes, seeded RNG, catalog, hatch and evolution. Unit tests for every rule in Sections 4 and 5. GitHub Actions runs `swift test` on macOS.
**Done when:** CI is green.

### Slice 0.5: Screen Time spike (real iPhone, throwaway code)
A bare app plus the three extensions. Prove every [VERIFY] in Section 6 on the founder's iPhone over 3 nights. Write the results into this PRD.
**Done when:** the lock turns on and off by itself across midnight for 3 nights, a 10-minute receipt unlock re-locks on time, and the shield → Sumi path works in ≤ 2 taps. **If the shield → Sumi path fails, redesign the receipt before Slice 1.**

### Slice 1: The nightly loop with placeholder art
Onboarding (Section 3.1), schedule, shield, receipt, night Home, morning reveal wired to `SumiCore`. Placeholder egg and 12 colored-blob creatures.
**Done when:** the founder runs it for 5 real nights and every outcome in Section 4.3 has happened at least once (debug-forced is fine for the rare ones).

### Slice 2: Collection, share card, notifications, final art
**Done when:** the collection grid, image share card, both notifications, and final art for the egg plus at least 6 species work on device.

### Slice 3: Fake-door paywall, analytics, privacy, TestFlight
**Done when:** every event in Section 11 is logged, "Delete all data" works, crash-free on 5 nights, and the TestFlight build is with testers.

---

## 13. Out of scope (V1)
HealthKit and any sleep measurement; phone-on-the-mattress sessions; microphone; sleep scores, stages, charts; AI captions and any backend; video share; alarm clock; daytime chores (feeding, cooking, berries); social feed, friends, leaderboards; trading; Android; watchOS; widgets (V1.1 candidate); real paywall and purchases; accounts and sync; more than 12 species.

## 14. Open questions
| # | Question | Blocks | Default |
|---|---|---|---|
| Q1 | Who makes the art, budget, deadline? (egg + 12 species × 3 stages) | Slice 2 | Placeholder blobs until decided |
| Q2 | Is the creature line called "Sumi", or is Sumi the guide who keeps your egg warm? | Slice 2 copy | Sumi is the guide; creatures have their own names |
| Q3 | Bundle ID, App Group, domain, feedback email | Slice 0.5 | `com.example.sumi` placeholders |
| Q4 | Receipt cap: 3 per night OK? | Slice 1 | 3 |
| Q5 | Should a restless night still give 1 warmth for showing up? | Slice 1 | No (behavior must matter) |
| Q6 | Name and trademark check for "Sumi" | Launch | Check before TestFlight |

---

## Changelog vs. v1.1 ("passive mirror")
- **Product changed** from "your sleep, as a creature" (HealthKit mirror) to a bedtime commitment game. Reason: the mirror had no reason to come back after the novelty, no lever on behavior, and no monetization path.
- **Removed:** HealthKit sleep engine, phone-on-the-bed Sleep Session (Section 4A), microphone, AI captions and Cloudflare Worker, video share, sleep-state animations driven by hours slept.
- **Added:** Screen Time lock on a schedule, receipts, egg warmth, hatching, collection with duplicate-evolves, fake-door paywall.
- **Kept:** never-punish rules, no medical claims, slice-by-slice build with kill bars, privacy-first and no accounts, the 04:00-style "a night is keyed by its evening" thinking.
