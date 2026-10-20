# App Review notes

---

No account, login or network connection is required. A new install starts empty.

WHAT IS NEW IN 1.2: live match scoring point by point, with a Live Activity on the Lock Screen and in the Dynamic Island that has Won, Lost and Fault buttons (LiveActivityIntent) so a point can be scored without unlocking; the match in progress is saved to the app group after every point and can be resumed; head-to-head records and scouting reports; shareable match posters; a free monthly challenge; Lock Screen widgets and two iOS 18 Control Center controls; Siri / Shortcuts (App Intents); TipKit tips; and Baseline Ledger Plus, a new auto-renewable subscription.

HOW TO USE: Home > "Score match" opens the live scorer. Enter an opponent, pick the format, tap "Start the match", then tap "You won it" or "They won it" for each point (Fault gives a second serve; Winner, Ace and Your error tag the point). With the scorer running, lock the phone: the Lock Screen card shows the score with Won / Lost / Fault buttons. "End" saves the match. "Start hitting" on Home logs a practice session ball by ball. Matches tab > Head to head lists every opponent.

BASELINE LEDGER PLUS (auto-renewable subscription group "Baseline Ledger Plus"): com.mattbusel.baselineledger.plus.monthly ($2.99 a month) and com.mattbusel.baselineledger.plus.yearly ($14.99 a year, with a one-week free trial for new subscribers). Where to find it: Home > the Baseline Ledger Plus card near the bottom > SEE; or Home > "This week's plan" card; or Stats > "Pressure points come with Plus"; or Gear > iCloud backup lock. The paywall shows both plans with price and period, the trial terms, the auto-renew terms, Terms of Use (Apple standard EULA) and Privacy Policy links, Restore, Redeem code, and Manage subscription once subscribed.
Plus includes everything in Pro, plus: a weekly practice plan built on the device from the user's own numbers (Home > This week's plan), Pressure Points stats from live-scored matches (Stats tab), all four court finishes while subscribed (Home > Extras), 10 scouting reports and 10 match posters every month, and iCloud backup and restore through the iCloud key-value store (Gear > iCloud backup).

OTHER IN-APP PURCHASES (StoreKit 2, all optional):
- Baseline Ledger Pro (existing non-consumable, $4.99): the full stat book on the Stats tab, momentum charts, clutch numbers, the Form widget, more than one racquet, CSV export. Offered at the bottom of the same paywall ("Or just the stat book"). Paid-era buyers are unlocked automatically (production only).
- Scouting Reports, $0.99 consumable (3 credits): Matches > Head to head > an opponent > Scouting report. One report a week is free, so the first tap shows a report; the next one offers 3 more for $0.99.
- Match Posters, $0.99 consumable (3 credits): open a saved match > Poster. The first poster is free; after that 3 more for $0.99.
- Red Clay, Lawn, Hard Court and Night Session finishes, $0.99 each, non-consumable: Home > Extras card at the bottom. A bought finish recolours the app and widgets and switches the app icon (alternate icons). Gold Leaf is included.
To test a consumable purchase on a fresh install: log two matches against the same opponent (Matches > pencil button), open Head to head > that player > Scouting report twice.

PRIVACY: no data is collected. Everything is stored on the device; the widgets read a small summary through the app group. The optional iCloud backup (Plus) writes the ledger to the user's own iCloud key-value store; the developer never receives it.

2. PURPOSE AND TARGET AUDIENCE
A private tennis scorekeeper, practice journal and match log for club players who want to improve deliberately. Rated 4+.

3. SETUP AND ACCESS
No setup, login or credentials.

4. EXTERNAL SERVICES
None. No network requests of our own, analytics, advertising or third-party frameworks. Built with SwiftUI, Swift Charts, WidgetKit, ActivityKit, AppIntents, TipKit, StoreKit and Foundation.

5. REGIONAL DIFFERENCES
None.

6. REGULATED INDUSTRY / PROTECTED MATERIAL
Not applicable. Not affiliated with any tennis federation or rating system; UTR and NTRP appear only as free-text labels the user types. All art, text and code are my own work.
