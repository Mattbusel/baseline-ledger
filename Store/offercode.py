"""Offer code for Pro owners: one free month of Plus Monthly, redeemable in the app (Redeem code on the paywall).

    python Store/offercode.py create      the offer (every territory) and a custom code PROPLUS
    python Store/offercode.py status
"""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import asc  # noqa: E402

SUB = "6824729087"  # com.mattbusel.baselineledger.plus.monthly
NAME = "Pro owners first month"
CODE = "PROPLUS"


def offers():
    return asc.call("GET", f"/v1/subscriptions/{SUB}/offerCodes", params={"limit": 50})["data"]


def create():
    off = next((o for o in offers() if o["attributes"]["name"] == NAME), None)
    if not off:
        prices = []
        link, params = f"/v1/subscriptions/{SUB}/prices", {"limit": 200, "include": "subscriptionPricePoint,territory"}
        while link:
            page = asc.call("GET", link, params=params)
            params = None
            prices += page["data"]
            link = page.get("links", {}).get("next")
        inc, refs = [], []
        for i, p in enumerate(prices):
            t = p["relationships"]["territory"]["data"]["id"]
            pp = p["relationships"]["subscriptionPricePoint"]["data"]["id"]
            lid = "${p%d}" % i
            refs.append({"type": "subscriptionOfferCodePrices", "id": lid})
            # A free trial carries no price point, only the territory.
            inc.append({"type": "subscriptionOfferCodePrices", "id": lid, "relationships": {
                "territory": {"data": {"type": "territories", "id": t}}}})
        r = asc.call("POST", "/v1/subscriptionOfferCodes", {"data": {"type": "subscriptionOfferCodes", "attributes": {
            "name": NAME, "customerEligibilities": ["NEW", "EXPIRED"], "offerEligibility": "STACK_WITH_INTRO_OFFERS",
            "duration": "ONE_MONTH", "offerMode": "FREE_TRIAL", "numberOfPeriods": 1},
            "relationships": {"subscription": {"data": {"type": "subscriptions", "id": SUB}}, "prices": {"data": refs}}}, "included": inc})
        if not r:
            sys.exit("offer create failed")
        off = r["data"]
        print("offer", off["id"], "created with", len(refs), "territories")
    codes = asc.call("GET", f"/v1/subscriptionOfferCodes/{off['id']}/customCodes", params={"limit": 50})
    if any(c["attributes"].get("customCode") == CODE for c in (codes or {}).get("data", [])):
        print("custom code", CODE, "exists"); return
    r = asc.call("POST", "/v1/subscriptionOfferCodeCustomCodes", {"data": {"type": "subscriptionOfferCodeCustomCodes", "attributes": {
        "customCode": CODE, "numberOfCodes": 25000, "expirationDate": "2027-10-19"},
        "relationships": {"offerCode": {"data": {"type": "subscriptionOfferCodes", "id": off["id"]}}}}})
    print("custom code", CODE, "created" if r else "FAILED")


def status():
    for o in offers():
        print(json.dumps(o["attributes"]))


if __name__ == "__main__":
    {"create": create, "status": status}.get(sys.argv[1] if len(sys.argv) > 1 else "status", status)()
