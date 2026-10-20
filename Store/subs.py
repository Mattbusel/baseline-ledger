"""Baseline Ledger Plus: the auto-renewable subscription group (monthly + yearly, yearly with a one-week free trial).

    python Store/subs.py create              group, both subscriptions, localizations, prices in every territory,
                                             availability, the yearly free trial (idempotent)
    python Store/subs.py shot <png>          review screenshot for both subscriptions
    python Store/subs.py status              state of each subscription
    python Store/subs.py offer-code          a custom offer code for Pro owners (first month free on monthly)

The one-time Pro unlock (com.mattbusel.baselineledger.pro) is untouched; Plus sits beside it.
"""
import hashlib
import sys
from pathlib import Path

import requests

sys.path.insert(0, str(Path(__file__).resolve().parent))
import asc  # noqa: E402

APP = "6813452278"
GROUP = "Baseline Ledger Plus"
GROUP_LOC = {
    # locale: (group display name, custom app name or None)
    "en-US": ("Baseline Ledger Plus", None),
    "en-GB": ("Baseline Ledger Plus", None),
    "en-AU": ("Baseline Ledger Plus", None),
    "en-CA": ("Baseline Ledger Plus", None),
    "ja": ("Baseline Ledger Plus", None),
    "ko": ("Baseline Ledger Plus", None),
    "zh-Hans": ("Baseline Ledger Plus", None),
    "es-ES": ("Baseline Ledger Plus", None),
    "es-MX": ("Baseline Ledger Plus", None),
    "de-DE": ("Baseline Ledger Plus", None),
    "fr-FR": ("Baseline Ledger Plus", None),
    "pt-BR": ("Baseline Ledger Plus", None),
    "it": ("Baseline Ledger Plus", None),
}
NOTE = ("Auto-renewable subscription in the group Baseline Ledger Plus. Open the app: Home tab > the Plus card near the bottom "
        "(or Stats tab > See the plans, or Home > This week's plan). The paywall shows both plans with price, period, the yearly "
        "plan's one-week free trial, auto-renew terms, Terms of Use and Privacy links, Restore Purchases, Redeem Code and Manage "
        "Subscription. Plus includes everything in the one-time Pro unlock (full stat book, momentum and clutch charts, Form widget, "
        "every racquet, CSV export) plus: a new practice plan every week built on the device from the user's own numbers, Pressure "
        "Points insights from live-scored matches (hold and break rates, deuce and 30-all points, serving for the set), all four court "
        "finishes while subscribed, 10 scouting reports and 10 match posters every month, and iCloud backup and restore of the "
        "ledger. No account is needed.")
SUBS = [
    ("plus.yearly", "ONE_YEAR", "Baseline Ledger Plus Yearly", 1, "14.99", "Baseline Ledger Plus (Yearly)", "Everything in Pro, weekly plans, backup"),
    ("plus.monthly", "ONE_MONTH", "Baseline Ledger Plus Monthly", 2, "2.99", "Baseline Ledger Plus (Monthly)", "Everything in Pro, weekly plans, backup"),
]
SUB_LOC = {
    "en-US": {"plus.yearly": ("Baseline Ledger Plus Yearly", "Everything in Pro, weekly plans, backup"),
           "plus.monthly": ("Baseline Ledger Plus Monthly", "Everything in Pro, weekly plans, backup")},
    "en-GB": {"plus.yearly": ("Baseline Ledger Plus Yearly", "Everything in Pro, weekly plans, backup"),
           "plus.monthly": ("Baseline Ledger Plus Monthly", "Everything in Pro, weekly plans, backup")},
    "en-AU": {"plus.yearly": ("Baseline Ledger Plus Yearly", "Everything in Pro, weekly plans, backup"),
           "plus.monthly": ("Baseline Ledger Plus Monthly", "Everything in Pro, weekly plans, backup")},
    "en-CA": {"plus.yearly": ("Baseline Ledger Plus Yearly", "Everything in Pro, weekly plans, backup"),
           "plus.monthly": ("Baseline Ledger Plus Monthly", "Everything in Pro, weekly plans, backup")},
    "ja": {"plus.yearly": ("Baseline Ledger Plus 年額", "Proの全機能、毎週の練習プラン、バックアップ"),
           "plus.monthly": ("Baseline Ledger Plus 月額", "Proの全機能、毎週の練習プラン、バックアップ")},
    "ko": {"plus.yearly": ("Baseline Ledger Plus 연간", "Pro 전체 기능, 주간 연습 플랜, 백업"),
           "plus.monthly": ("Baseline Ledger Plus 월간", "Pro 전체 기능, 주간 연습 플랜, 백업")},
    "zh-Hans": {"plus.yearly": ("Baseline Ledger Plus 年度", "包含 Pro 全部功能、每周训练计划和备份"),
           "plus.monthly": ("Baseline Ledger Plus 月度", "包含 Pro 全部功能、每周训练计划和备份")},
    "es-ES": {"plus.yearly": ("Baseline Ledger Plus anual", "Todo Pro, planes semanales y copia"),
           "plus.monthly": ("Baseline Ledger Plus mensual", "Todo Pro, planes semanales y copia")},
    "es-MX": {"plus.yearly": ("Baseline Ledger Plus anual", "Todo Pro, planes semanales y respaldo"),
           "plus.monthly": ("Baseline Ledger Plus mensual", "Todo Pro, planes semanales y respaldo")},
    "de-DE": {"plus.yearly": ("Baseline Ledger Plus jährlich", "Alles aus Pro, Wochenpläne, Backup"),
           "plus.monthly": ("Baseline Ledger Plus monatlich", "Alles aus Pro, Wochenpläne, Backup")},
    "fr-FR": {"plus.yearly": ("Baseline Ledger Plus annuel", "Tout Pro, plans hebdo et sauvegarde"),
           "plus.monthly": ("Baseline Ledger Plus mensuel", "Tout Pro, plans hebdo et sauvegarde")},
    "pt-BR": {"plus.yearly": ("Baseline Ledger Plus anual", "Tudo do Pro, planos semanais e backup"),
           "plus.monthly": ("Baseline Ledger Plus mensal", "Tudo do Pro, planos semanais e backup")},
    "it": {"plus.yearly": ("Baseline Ledger Plus annuale", "Tutto Pro, piani settimanali e backup"),
           "plus.monthly": ("Baseline Ledger Plus mensile", "Tutto Pro, piani settimanali e backup")},
}
BASE = "com.mattbusel.baselineledger."


def group():
    got = asc.call("GET", f"/v1/apps/{APP}/subscriptionGroups", params={"limit": 50})
    for g in got["data"]:
        if g["attributes"]["referenceName"] == GROUP:
            return g
    return asc.call("POST", "/v1/subscriptionGroups", {"data": {"type": "subscriptionGroups", "attributes": {"referenceName": GROUP},
                    "relationships": {"app": {"data": {"type": "apps", "id": APP}}}}})["data"]


def find(gid: str, pid: str):
    got = asc.call("GET", f"/v1/subscriptionGroups/{gid}/subscriptions", params={"limit": 50})
    return next((s for s in got["data"] if s["attributes"]["productId"] == pid), None)


def territories():
    return [t["id"] for t in asc.call("GET", "/v1/territories", params={"limit": 200})["data"]]


def create():
    g = group()
    gid = g["id"]
    print("group", gid)
    have = {l["attributes"]["locale"]: l for l in asc.call("GET", f"/v1/subscriptionGroups/{gid}/subscriptionGroupLocalizations", params={"limit": 50})["data"]}
    for loc, (name, custom) in GROUP_LOC.items():
        if loc in have:
            continue
        attrs = {"locale": loc, "name": name}
        if custom:
            attrs["customAppName"] = custom
        r = asc.call("POST", "/v1/subscriptionGroupLocalizations", {"data": {"type": "subscriptionGroupLocalizations", "attributes": attrs,
                     "relationships": {"subscriptionGroup": {"data": {"type": "subscriptionGroups", "id": gid}}}}})
        print("  group loc", loc, "ok" if r else "FAILED")
    terr = None
    for suffix, period, ref, level, usd, _, _ in SUBS:
        pid = BASE + suffix
        s = find(gid, pid)
        if not s:
            r = asc.call("POST", "/v1/subscriptions", {"data": {"type": "subscriptions", "attributes": {
                "name": ref, "productId": pid, "subscriptionPeriod": period, "familySharable": False, "reviewNote": NOTE, "groupLevel": level},
                "relationships": {"group": {"data": {"type": "subscriptionGroups", "id": gid}}}}})
            if not r:
                print(pid, "create FAILED"); continue
            s = r["data"]
        sid = s["id"]
        print(pid, sid, s["attributes"].get("state"))
        asc.call("PATCH", f"/v1/subscriptions/{sid}", {"data": {"type": "subscriptions", "id": sid, "attributes": {"reviewNote": NOTE}}}, quiet=True)
        locs = {l["attributes"]["locale"]: l for l in asc.call("GET", f"/v1/subscriptions/{sid}/subscriptionLocalizations", params={"limit": 50})["data"]}
        for loc, table in SUB_LOC.items():
            name, desc = table[suffix]
            assert len(name) <= 30 and len(desc) <= 45, (loc, name, desc, len(desc))
            if loc in locs:
                continue
            r = asc.call("POST", "/v1/subscriptionLocalizations", {"data": {"type": "subscriptionLocalizations",
                         "attributes": {"locale": loc, "name": name, "description": desc},
                         "relationships": {"subscription": {"data": {"type": "subscriptions", "id": sid}}}}})
            print("  loc", loc, "ok" if r else "FAILED")
        # Availability first: prices can only be set in territories the subscription is available in.
        av = asc.call("GET", f"/v1/subscriptions/{sid}/subscriptionAvailability", quiet=True)
        if not av or not av.get("data"):
            terr = terr or territories()
            r = asc.call("POST", "/v1/subscriptionAvailabilities", {"data": {"type": "subscriptionAvailabilities",
                         "attributes": {"availableInNewTerritories": True},
                         "relationships": {"subscription": {"data": {"type": "subscriptions", "id": sid}},
                                           "availableTerritories": {"data": [{"type": "territories", "id": t} for t in terr]}}}})
            print("  availability", "ok" if r else "FAILED")
        prices = asc.call("GET", f"/v1/subscriptions/{sid}/prices", params={"limit": 200, "include": "territory"})
        if len(prices["data"]) < 150:
            pts = asc.call("GET", f"/v1/subscriptions/{sid}/pricePoints", params={"filter[territory]": "USA", "limit": 200})
            usa = None
            nxt = pts
            while nxt and not usa:
                usa = next((p for p in nxt["data"] if p["attributes"]["customerPrice"] == usd), None)
                link = nxt.get("links", {}).get("next")
                nxt = asc.call("GET", link) if (link and not usa) else None
            if not usa:
                print("  no USA price point", usd); continue
            eq = [usa]
            link = f"/v1/subscriptionPricePoints/{usa['id']}/equalizations"
            params = {"limit": 200, "include": "territory"}
            while link:
                page = asc.call("GET", link, params=params)
                params = None
                eq += page["data"]
                link = page.get("links", {}).get("next")
            done_terr = set()
            for p in prices["data"]:
                t = (p.get("relationships", {}).get("territory", {}).get("data") or {}).get("id")
                if t:
                    done_terr.add(t)
            ok = 0
            for p in eq:
                t = (p.get("relationships", {}).get("territory", {}).get("data") or {}).get("id")
                if t and t in done_terr:
                    continue
                r = asc.call("POST", "/v1/subscriptionPrices", {"data": {"type": "subscriptionPrices",
                             "attributes": {"preserveCurrentPrice": False, "startDate": None},
                             "relationships": {"subscription": {"data": {"type": "subscriptions", "id": sid}},
                                               "subscriptionPricePoint": {"data": {"type": "subscriptionPricePoints", "id": p["id"]}}}}}, quiet=True)
                ok += 1 if r else 0
            print(f"  prices: {ok} new, {len(done_terr)} already set, of {len(eq)} territories at USD {usd} equivalents")
        if suffix == "plus.yearly":
            intro = asc.call("GET", f"/v1/subscriptions/{sid}/introductoryOffers", params={"limit": 200, "include": "territory"})
            if len(intro["data"]) < 150:
                terr = terr or territories()
                have_t = {(o.get("relationships", {}).get("territory", {}).get("data") or {}).get("id") for o in intro["data"]}
                ok = 0
                for t in terr:
                    if t in have_t:
                        continue
                    r = asc.call("POST", "/v1/subscriptionIntroductoryOffers", {"data": {"type": "subscriptionIntroductoryOffers",
                                 "attributes": {"duration": "ONE_WEEK", "offerMode": "FREE_TRIAL", "numberOfPeriods": 1, "startDate": None, "endDate": None},
                                 "relationships": {"subscription": {"data": {"type": "subscriptions", "id": sid}},
                                                   "territory": {"data": {"type": "territories", "id": t}}}}}, quiet=True)
                    ok += 1 if r else 0
                print(f"  free trial: {ok}/{len(terr)} territories")


def shot(png: str):
    data = Path(png).read_bytes()
    g = group()
    for suffix, *_ in SUBS:
        s = find(g["id"], BASE + suffix)
        if not s:
            continue
        sid = s["id"]
        cur = asc.call("GET", f"/v1/subscriptions/{sid}/appStoreReviewScreenshot", quiet=True)
        if cur and cur.get("data"):
            asc.call("DELETE", f"/v1/subscriptionAppStoreReviewScreenshots/{cur['data']['id']}")
        made = asc.call("POST", "/v1/subscriptionAppStoreReviewScreenshots", {"data": {"type": "subscriptionAppStoreReviewScreenshots",
                        "attributes": {"fileName": Path(png).name, "fileSize": len(data)},
                        "relationships": {"subscription": {"data": {"type": "subscriptions", "id": sid}}}}})
        if not made:
            print(suffix, "reserve FAILED"); continue
        mid = made["data"]["id"]
        for op in made["data"]["attributes"]["uploadOperations"]:
            headers = {h["name"]: h["value"] for h in op.get("requestHeaders", [])}
            requests.request(op["method"], op["url"], headers=headers, data=data[op["offset"]: op["offset"] + op["length"]], timeout=120).raise_for_status()
        r = asc.call("PATCH", f"/v1/subscriptionAppStoreReviewScreenshots/{mid}", {"data": {"type": "subscriptionAppStoreReviewScreenshots", "id": mid,
                     "attributes": {"uploaded": True, "sourceFileChecksum": hashlib.md5(data).hexdigest()}}})
        print(suffix, "review screenshot", "uploaded" if r else "FAILED")


def status():
    g = group()
    print("group", g["id"])
    for suffix, *_ in SUBS:
        s = find(g["id"], BASE + suffix)
        if not s:
            print(BASE + suffix, "missing"); continue
        n = len(asc.call("GET", f"/v1/subscriptions/{s['id']}/prices", params={"limit": 200})["data"])
        i = len(asc.call("GET", f"/v1/subscriptions/{s['id']}/introductoryOffers", params={"limit": 200})["data"])
        print(f"{BASE + suffix}: {s['id']} {s['attributes']['state']} prices={n} intro={i}")


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "status"
    if cmd == "shot":
        shot(sys.argv[2])
    else:
        {"create": create, "status": status}.get(cmd, lambda: sys.exit(__doc__))()
