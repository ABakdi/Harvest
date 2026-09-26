# Notifications & Reminders

Reminders are the product's pulse — but fatigue kills apps. Every notification follows a **gentle-to-urgent** escalation and respects one principle: *never nag about something already done.*

## The daily schedule

What is built, and when it fires ([[Audit-v2]] D3-06):

| When | Notification | Condition | Time is mine |
| :--- | :--- | :--- | :--- |
| 7:00 | ☀️ *"Good morning! Here's today's harvest plan."* | The master switch | Settings |
| 20:00 | 💰 *"What did you spend today? Log it in 2 taps."* | Cancelled once an expense is logged | Settings |
| 21:30 | 🌙 *"Plan tomorrow's harvest."* | The master switch | Settings |
| 23:00 | 🔥 *"Log your remaining tasks to save your streak."* | **Only** if the streak is genuinely at risk | Fixed |
| Bedtime −30 min | 🌙 Wind-down | Only with a daily cycle set ([[Health]]) | Follows the cycle, per weekday |
| 19:00 | A debt still owed, quoting what is left | Until it is paid off | Per debt |
| A time I set | A seed, an album | Always | Per row |
| Real-time | ⏳ Remaining minutes overlay on distracting apps | [[Phase-7-Screen-Time]] | — |

The three ritual times are settable; the late check is not, because
its whole point is the hour when a day is nearly over.

## Prime-time learning — not built

The plan was to learn *when* I usually check in and move a gentle
nudge to 30 minutes before that window. It was never built, and I have
not missed it: the rituals sit at the hours I would have learned
anyway, and a fifth notification is exactly what rule #9 is there to
prevent. It stays here as an idea, not a promise ([[Audit-v2]]
D3-06).

## Escalation rules

```mermaid
flowchart TD
    A[Task due today] --> B{Done already?}
    B -- yes --> Z[Silence 🤫]
    B -- no --> C[Morning review names it]
    C --> D{Still pending at the evening plan?}
    D -- no --> Z
    D -- yes --> E[Evening plan mentions it]
    E --> F{Streak at risk at the late check?}
    F -- no --> Z
    F -- yes --> G[One urgent nudge — never more]
```

- The **four rituals** are the cap — morning review, evening plan, the expense check-in, the streak-risk nudge — and a comeback nudge takes the morning ritual's place rather than adding to them. A time I put on a seed, an album or a debt myself is not a ritual and always fires: I asked for it, by name, at that hour ([[Audit-v2-Beta]] B-11 — the old wording promised a cap the app never counted).
- **A reminder I asked for rings; a nudge does not.** A time I put on a seed, an album or a debt is alarm-grade: over the lock screen, on the alarm stream, snoozable, because I asked for it by name at that hour ([[Audit-v2-Beta]] N-07). The wind-down, the streak-risk nudge and the comeback rungs are ordinary notifications — nothing about going to bed needs to ring over a lock screen ([[Audit-v2]] D3-06).
- Every category individually mutable in settings.
- Copy always uses the farming voice ([[Glossary]]) — warm, short, no shame.

Implementation details: [[Notifications-and-Background]].

## The daily cycle ([[Checkpoint-4]])

Every default above assumes a shape of day. Settings → **Daily cycle**
makes that shape mine: a bedtime and a wake time, eight hours
recommended, a red warning below five and no refusal — a night shift is
a fact, not a mistake for a dialog to correct.

Changing either time finds every reminder the **new** night would
swallow, seeds and unsettled debts alike, and asks by name before
touching anything. Answering yes moves them by one rule: **a reminder
keeps its distance from waking.** Something set for two hours after I
get up stays two hours after I get up, wrapping past midnight rather
than falling off the end of the day. Only the clashing ones move;
leaving them is a real answer.

The point is to remove an excuse. An app whose reminders only make
sense for someone who rises at seven is quietly telling everyone else
to fix their sleep before they can start — which is the same "I'll
begin on Monday" the whole thing exists to defeat.

## The comeback ladder ([[Checkpoint-3]])

Every other reminder here fires because I asked it to. This one fires
because I **stopped** asking — and for a streak app that is the one
case worth getting right, because an app that goes quiet the moment you
stop opening it has given up on the single thing it does.

**"Stopped" means the app's one definition of activity** — the same
list the streak engine uses when it asks whether a stretch of days was
idle ([[Gamification]]): a check-in, a picture in a scheduled album, an
expense, a night written down, a weight, a finished workout. Steps are
not on it; the phone counted those. Before [[Audit-v2-Beta]] B-04 the
ladder counted check-ins and expenses only, and somebody who wrote
their sleep down every morning was, to it, a week absent.

Six rungs, escalating from warm to plain, one message each. The ladder
*is* the rotation:

| Rung | Fires | Voice |
| :--- | :--- | :--- |
| 1 day | the morning after one missed day | 🌱 *"Your field is waiting"* |
| 3 days | | *"Three days without water"* |
| 1 week | | 🌾 *"A week away"* |
| 2 weeks | | *"Two weeks quiet"* |
| 1 month | | *"A month of fallow ground"* |
| 2 months | then every 30 days | *"Still here whenever you are"* |

- A rung fires the morning **after** its run of missed days is complete,
  so the one-day nudge lands two days after the last check-in.
- Past the last rung the ladder settles into a **monthly heartbeat**
  rather than going silent. Someone who put the phone down in March
  should still hear from their field in June.
- **Anything counts as showing up**: a check-in or a logged expense
  resets the whole ladder, which is replanned on every check-in, every
  expense, every app open and every 3 AM reset.
- A rung **replaces** the morning ritual on the day it fires rather than
  stacking on it — the 4/day cap is a rule, not a target
  ([[Business-Rules]] #9).
- It is a ritual, so the master "Allow reminders" switch silences it —
  unlike a seed's own reminder, which is a time I asked for.
- It is **not** an alarm: no full-screen intent, no alarm stream, no
  snooze. "We miss you" does not get to wake anybody up.
- No shame, ever. Every message says the history is safe and one
  check-in starts the next streak; none of them counts the days lost.

An app installed and never opened still gets the ladder — with no
check-ins on record it counts from the day the first seed was planted.

## Alarms, not toasts (checkpoint round 5)

- A time I set — a seed's *remind me at*, a debt's reminder — **always
  fires**, regardless of the master "Allow reminders" switch; the switch
  only governs the daily rituals (morning, evening, expense, prime time,
  streak risk).
- Every reminder is scheduled **exact to the minute** (Android exact
  alarms; the app asks for the permission the first time a time is set),
  rings on the **alarm stream** with vibration, and shows **over the lock
  screen** for seed and debt reminders.
- Every reminder carries **snooze actions** — *in 10 min · in 1 hour ·
  in 3 hours*. They work with the app closed; the snoozed copy survives
  the daily replan and a reboot.
- Setting or editing a reminder reschedules immediately — no need to
  reopen the app.

