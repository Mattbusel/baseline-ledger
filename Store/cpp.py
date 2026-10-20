"""Custom product pages: three audiences, each with its own screenshot order, promotional text, deep link
and (where the API allows) search keywords from the app's keyword list.

    python Store/cpp.py create      make or update the pages and upload their screenshots (idempotent)
    python Store/cpp.py status
    python Store/cpp.py ids         print each page's version id (for the review submission)

Screenshots are picked from fastlane/screenshots/en-US by caption key (the order frame.mjs writes them in).
"""
import hashlib
import json
import sys
from pathlib import Path

import requests

sys.path.insert(0, str(Path(__file__).resolve().parent))
import asc  # noqa: E402

APP = "6813452278"
SHOTS = Path(__file__).resolve().parent.parent / "fastlane" / "screenshots" / "en-US"
KEYS = ["score", "lockscreen", "plan", "stats", "opponents", "scout", "challenge", "live", "match", "clay"]
DISPLAY = "APP_IPHONE_67"

PAGES = [
    dict(name="Live scoring", deep="baselineledger://score",
         shots=["score", "lockscreen", "match", "stats", "opponents", "clay"],
         keywords=["scorekeeper", "scoreboard", "tiebreak"],
         promo="Score your match point by point, right from your Lock Screen. Serve numbers, break points and momentum fill themselves in."),
    dict(name="Practice plan", deep="baselineledger://plan",
         shots=["plan", "live", "challenge", "stats", "score", "clay"],
         keywords=["practice", "drills", "coach", "plan"],
         promo="A new practice plan every week, built from your own numbers. Log practice ball by ball and take on a new challenge every month."),
    dict(name="League and ladder", deep="baselineledger://matches",
         shots=["opponents", "scout", "stats", "score", "lockscreen", "match"],
         keywords=["league", "usta", "utr", "ntrp", "club"],
         promo="Your record against everyone on the ladder, a scouting report before every rematch, and the numbers that win close matches."),
]


def shot_file(key):
    return SHOTS / f"{KEYS.index(key) + 1:02d}_iPhone.png"


def pages():
    return asc.call("GET", f"/v1/apps/{APP}/appCustomProductPages", params={"limit": 50})["data"]


def version_and_loc(page_id):
    vs = asc.call("GET", f"/v1/appCustomProductPages/{page_id}/appCustomProductPageVersions", params={"limit": 10})["data"]
    v = vs[0]
    locs = asc.call("GET", f"/v1/appCustomProductPageVersions/{v['id']}/appCustomProductPageLocalizations", params={"limit": 50})["data"]
    return v, next((l for l in locs if l["attributes"]["locale"] == "en-US"), None)


def upload_shots(loc_id, keys):
    sets = asc.call("GET", f"/v1/appCustomProductPageLocalizations/{loc_id}/appScreenshotSets")["data"]
    sset = next((s for s in sets if s["attributes"]["screenshotDisplayType"] == DISPLAY), None)
    files = [shot_file(k) for k in keys]
    local = [hashlib.md5(f.read_bytes()).hexdigest() for f in files]
    if sset:
        remote = [s["attributes"].get("sourceFileChecksum") for s in asc.call("GET", f"/v1/appScreenshotSets/{sset['id']}/appScreenshots", params={"limit": 20})["data"]]
        if remote == local:
            print("   screenshots MATCH"); return
        for s in asc.call("GET", f"/v1/appScreenshotSets/{sset['id']}/appScreenshots", params={"limit": 20})["data"]:
            asc.call("DELETE", f"/v1/appScreenshots/{s['id']}")
    else:
        sset = asc.call("POST", "/v1/appScreenshotSets", {"data": {"type": "appScreenshotSets", "attributes": {"screenshotDisplayType": DISPLAY},
                        "relationships": {"appCustomProductPageLocalization": {"data": {"type": "appCustomProductPageLocalizations", "id": loc_id}}}}})["data"]
    for f in files:
        data = f.read_bytes()
        made = asc.call("POST", "/v1/appScreenshots", {"data": {"type": "appScreenshots", "attributes": {"fileName": f.name, "fileSize": len(data)},
                        "relationships": {"appScreenshotSet": {"data": {"type": "appScreenshotSets", "id": sset["id"]}}}}})["data"]
        for op in made["attributes"]["uploadOperations"]:
            h = {x["name"]: x["value"] for x in op.get("requestHeaders", [])}
            requests.request(op["method"], op["url"], headers=h, data=data[op["offset"]: op["offset"] + op["length"]], timeout=120).raise_for_status()
        asc.call("PATCH", f"/v1/appScreenshots/{made['id']}", {"data": {"type": "appScreenshots", "id": made["id"],
                 "attributes": {"uploaded": True, "sourceFileChecksum": hashlib.md5(data).hexdigest()}}})
    print(f"   uploaded {len(files)} screenshots")


def keywords(loc_id, words):
    have = asc.call("GET", f"/v1/apps/{APP}/searchKeywords", params={"limit": 200}, quiet=True)
    if not have:
        print("   keywords: the API offers no searchKeywords for this app (skipped)"); return
    ids = {k["attributes"].get("keyword", k["id"]).lower(): k["id"] for k in have.get("data", [])}
    pick = [ids[w] for w in words if w in ids]
    if not pick:
        print("   keywords: none of", words, "in", sorted(ids)[:30]); return
    r = asc.call("POST", f"/v1/appCustomProductPageLocalizations/{loc_id}/relationships/searchKeywords",
                 {"data": [{"type": "appKeywords", "id": i} for i in pick]})
    print("   keywords", words, "ok" if r is not None else "FAILED")


def create():
    have = {p["attributes"]["name"]: p for p in pages()}
    for pg in PAGES:
        if pg["name"] in have:
            page = have[pg["name"]]
            print(pg["name"], "exists", page["id"])
        else:
            r = asc.call("POST", "/v1/appCustomProductPages", {
                "data": {"type": "appCustomProductPages", "attributes": {"name": pg["name"]},
                         "relationships": {"app": {"data": {"type": "apps", "id": APP}},
                                           "appCustomProductPageVersions": {"data": [{"type": "appCustomProductPageVersions", "id": "${v1}"}]}}},
                "included": [
                    {"type": "appCustomProductPageVersions", "id": "${v1}", "attributes": {"deepLink": pg["deep"]},
                     "relationships": {"appCustomProductPageLocalizations": {"data": [{"type": "appCustomProductPageLocalizations", "id": "${l1}"}]}}},
                    {"type": "appCustomProductPageLocalizations", "id": "${l1}", "attributes": {"locale": "en-US", "promotionalText": pg["promo"]}},
                ]})
            if not r:
                print(pg["name"], "create FAILED"); continue
            page = r["data"]
            print(pg["name"], "created", page["id"])
        v, loc = version_and_loc(page["id"])
        if v["attributes"].get("deepLink") != pg["deep"]:
            asc.call("PATCH", f"/v1/appCustomProductPageVersions/{v['id']}", {"data": {"type": "appCustomProductPageVersions", "id": v["id"], "attributes": {"deepLink": pg["deep"]}}}, quiet=True)
        if loc is None:
            loc = asc.call("POST", "/v1/appCustomProductPageLocalizations", {"data": {"type": "appCustomProductPageLocalizations",
                           "attributes": {"locale": "en-US", "promotionalText": pg["promo"]},
                           "relationships": {"appCustomProductPageVersion": {"data": {"type": "appCustomProductPageVersions", "id": v["id"]}}}}})["data"]
        elif loc["attributes"].get("promotionalText") != pg["promo"]:
            asc.call("PATCH", f"/v1/appCustomProductPageLocalizations/{loc['id']}", {"data": {"type": "appCustomProductPageLocalizations", "id": loc["id"],
                     "attributes": {"promotionalText": pg["promo"]}}})
        print("  version", v["id"], v["attributes"].get("state"))
        upload_shots(loc["id"], pg["shots"])
        keywords(loc["id"], pg["keywords"])


def status():
    for p in pages():
        v, loc = version_and_loc(p["id"])
        print(p["attributes"]["name"], p["id"], "version", v["id"], v["attributes"])


def ids():
    print(json.dumps({p["attributes"]["name"]: version_and_loc(p["id"])[0]["id"] for p in pages()}))


if __name__ == "__main__":
    {"create": create, "status": status, "ids": ids}.get(sys.argv[1] if len(sys.argv) > 1 else "status", status)()
