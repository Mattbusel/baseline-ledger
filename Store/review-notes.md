# App Review notes

---

No account, login or network connection is required. A new install starts empty.

WHAT IS NEW IN 1.2: live match scoring point by point (with a Live Activity showing the score on the Lock Screen and in the Dynamic Island), head-to-head records and notes per opponent, on-device scouting reports, shareable match posters, Record and Form widgets (WidgetKit extension, data shared through the app group group.com.mattbusel.baselineledger), Pro momentum and clutch charts, and six new in-app purchases.

HOW TO USE: Home > "Score match" (or the gold ball button on the Matches tab) opens the live scorer. Enter an opponent, pick the format, tap "Start the match", then tap "You won it" or "They won it" for each point (Fault gives a second serve; Winner, Ace and Your error tag the point). "End" saves the match and opens the match sheet. "Start hitting" on Home logs a practice session ball by ball. Matches tab > Head to head lists every opponent.

IN-APP PURCHASES (StoreKit 2, all optional; Restore is on the Pro card at the bottom of Home and in the Extras shop):
- Baseline Ledger Pro (existing non-consumable, $4.99): the full stat book on the Stats tab, momentum charts, clutch numbers, the Form widget, more than one racquet, CSV export. Paywall: Stats tab > "See Baseline Ledger Pro", or SEE on the Pro card at the bottom of Home. Paid-era buyers are unlocked automatically (production only).
- Scouting Reports, $0.99 consumable (3 credits): Matches > Head to head > an opponent > Scouting report. One report a week is free, so the first tap shows a report; the next one offers 3 more for $0.99. A report is computed on the device from the user's matches against that opponent.
- Match Posters, $0.99 consumable (3 credits): open a saved match > Poster. The first poster is free; after that 3 more for $0.99.
- Red Clay, Lawn, Hard Court and Night Session finishes, $0.99 each, non-consumable: Home > Extras card at the bottom. A bought finish recolours the app and widgets and switches the app icon (alternate icons). Gold Leaf is free.
To test a consumable purchase on a fresh install: log two matches against the same opponent (Matches > pencil button), open Head to head > that player > Scouting report twice.

PRIVACY: no data is collected. Everything is stored on the device; the widgets read a small summary through the app group.

2. PURPOSE AND TARGET AUDIENCE
A private tennis scorekeeper, practice journal and match log for club players who want to improve deliberately. Rated 4+.

3. SETUP AND ACCESS
No setup, login or credentials.

4. EXTERNAL SERVICES
None. No network requests, analytics, advertising or third-party frameworks. Built with SwiftUI, Swift Charts, WidgetKit, ActivityKit, StoreKit and Foundation.

5. REGIONAL DIFFERENCES
None.

6. REGULATED INDUSTRY / PROTECTED MATERIAL
Not applicable. Not affiliated with any tennis federation or rating system; UTR and NTRP appear only as free-text labels the user types. All art, text and code are my own work.
