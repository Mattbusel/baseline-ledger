"""Featuring nomination for 1.2 (App Store Connect > Featuring > Nominations), through the API."""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import asc  # noqa: E402

APP = "6813452278"
NAME = "Baseline Ledger 1.2: score tennis from the Lock Screen"
DESC = ("Baseline Ledger is a tennis scorekeeper and stat book for club players, built entirely with Apple frameworks and "
        "finished in black and gold. Version 1.2 turns it into a live scoring tool: tap who won each point and the score, "
        "serve numbers and break points fill themselves in, and an interactive Live Activity puts Won, Lost and Fault buttons "
        "on the Lock Screen and in the Dynamic Island, so players can score between points without unlocking. It adds head to "
        "head records with on-device scouting reports, a weekly practice plan generated on the phone from the player's own "
        "numbers, pressure-point stats, a monthly challenge (an In-App Event: the November Serve Challenge), Lock Screen "
        "widgets, iOS 18 Control Center controls, App Shortcuts for Siri, and TipKit onboarding. No account, no tracking, "
        "everything on device.")

if __name__ == "__main__":
    have = []
    for st in ("DRAFT", "SUBMITTED"):
        got = asc.call("GET", "/v1/nominations", params={"limit": 50, "filter[state]": st, "include": "relatedApps"})
        have += [d for d in (got or {}).get("data", []) if d["attributes"].get("name") == NAME]
    if have:
        print("exists", have[0]["id"], have[0]["attributes"].get("state")); sys.exit()
    r = asc.call("POST", "/v1/nominations", {"data": {"type": "nominations", "attributes": {
        "name": NAME, "type": "APP_ENHANCEMENTS", "description": DESC, "submitted": True,
        "publishStartDate": "2026-10-27T00:00:00Z", "deviceFamilies": ["IPHONE"], "hasInAppEvents": True,
        "locales": ["en-US", "en-GB", "en-AU", "en-CA", "ja", "ko", "zh-Hans", "es-MX", "es-ES", "de-DE", "fr-FR", "pt-BR", "it"]},
        "relationships": {"relatedApps": {"data": [{"type": "apps", "id": APP}]}}}})
    print(json.dumps(r["data"]["attributes"]) if r else "FAILED")
