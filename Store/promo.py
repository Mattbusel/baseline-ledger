"""Promoted in-app purchases: the 1024x1024 images from Store/art/promo.mjs, then the promoted list in order.

    python Store/promo.py images     upload each product's promotion image (replaces an existing one)
    python Store/promo.py promote    create the promoted purchases (visible to all) and set the order
    python Store/promo.py status
"""
import hashlib
import sys
from pathlib import Path

import requests

sys.path.insert(0, str(Path(__file__).resolve().parent))
import asc  # noqa: E402

APP = "6813452278"
BASE = "com.mattbusel.baselineledger."
ART = Path(__file__).resolve().parent / "art" / "promo"
# Order on the product page: Plus first, then the finishes.
ORDER = ["plus.yearly", "plus.monthly", "court.clay", "court.night", "court.hard", "court.lawn"]


def sub(suffix):
    for g in asc.call("GET", f"/v1/apps/{APP}/subscriptionGroups", params={"limit": 50})["data"]:
        for s in asc.call("GET", f"/v1/subscriptionGroups/{g['id']}/subscriptions", params={"limit": 50})["data"]:
            if s["attributes"]["productId"] == BASE + suffix:
                return s
    return None


def iap(suffix):
    got = asc.call("GET", f"/v1/apps/{APP}/inAppPurchasesV2", params={"filter[productId]": BASE + suffix, "limit": 10})
    return next((d for d in (got or {}).get("data", []) if d["attributes"]["productId"] == BASE + suffix), None)


def product(suffix):
    """(kind, id): kind is 'subscriptions' or 'inAppPurchases'."""
    if suffix.startswith("plus."):
        s = sub(suffix)
        return ("subscriptions", s["id"]) if s else (None, None)
    i = iap(suffix)
    return ("inAppPurchases", i["id"]) if i else (None, None)


def upload(kind, pid, png: Path):
    data = png.read_bytes()
    img_type = "subscriptionImages" if kind == "subscriptions" else "inAppPurchaseImages"
    rel = "subscription" if kind == "subscriptions" else "inAppPurchase"
    listing = f"/v1/subscriptions/{pid}/images" if kind == "subscriptions" else f"/v2/inAppPurchases/{pid}/images"
    cur = asc.call("GET", listing, quiet=True)
    for d in (cur or {}).get("data", []):
        if d["attributes"].get("sourceFileChecksum") == hashlib.md5(data).hexdigest():
            print(f"  {png.name}: already there ({d['attributes'].get('state')})")
            return
        asc.call("DELETE", f"/v1/{img_type}/{d['id']}")
    made = asc.call("POST", f"/v1/{img_type}", {"data": {"type": img_type, "attributes": {"fileName": png.name, "fileSize": len(data)},
                    "relationships": {rel: {"data": {"type": kind, "id": pid}}}}})
    if not made:
        print(f"  {png.name}: reserve FAILED"); return
    mid = made["data"]["id"]
    for op in made["data"]["attributes"]["uploadOperations"]:
        headers = {h["name"]: h["value"] for h in op.get("requestHeaders", [])}
        requests.request(op["method"], op["url"], headers=headers, data=data[op["offset"]: op["offset"] + op["length"]], timeout=120).raise_for_status()
    r = asc.call("PATCH", f"/v1/{img_type}/{mid}", {"data": {"type": img_type, "id": mid,
                 "attributes": {"uploaded": True, "sourceFileChecksum": hashlib.md5(data).hexdigest()}}})
    print(f"  {png.name}: {'uploaded' if r else 'commit FAILED'}")


def images():
    for suffix in ORDER:
        kind, pid = product(suffix)
        if not pid:
            print(suffix, "missing"); continue
        print(suffix, kind, pid)
        upload(kind, pid, ART / f"{suffix}.png")


def promote():
    have = asc.call("GET", f"/v1/apps/{APP}/promotedPurchases", params={"limit": 50, "include": "inAppPurchaseV2,subscription"})
    by_product = {}
    for d in (have or {}).get("data", []):
        rel = d.get("relationships", {})
        for k in ("inAppPurchaseV2", "subscription"):
            t = (rel.get(k) or {}).get("data")
            if t:
                by_product[t["id"]] = d["id"]
    ids = []
    for suffix in ORDER:
        kind, pid = product(suffix)
        if not pid:
            print(suffix, "missing"); continue
        if pid in by_product:
            ids.append(by_product[pid]); print(suffix, "already promoted"); continue
        rel = {"app": {"data": {"type": "apps", "id": APP}}}
        if kind == "subscriptions":
            rel["subscription"] = {"data": {"type": "subscriptions", "id": pid}}
        else:
            rel["inAppPurchaseV2"] = {"data": {"type": "inAppPurchases", "id": pid}}
        r = asc.call("POST", "/v1/promotedPurchases", {"data": {"type": "promotedPurchases",
                     "attributes": {"visibleForAllUsers": True, "enabled": True}, "relationships": rel}})
        print(suffix, "promoted" if r else "promote FAILED")
        if r:
            ids.append(r["data"]["id"])
    if ids:
        r = asc.call("PATCH", f"/v1/apps/{APP}/relationships/promotedPurchases", {"data": [{"type": "promotedPurchases", "id": i} for i in ids]})
        print("order", "set" if r is not None else "FAILED")


def status():
    have = asc.call("GET", f"/v1/apps/{APP}/promotedPurchases", params={"limit": 50})
    for d in (have or {}).get("data", []):
        print(d["id"], d["attributes"])


if __name__ == "__main__":
    {"images": images, "promote": promote, "status": status}.get(sys.argv[1] if len(sys.argv) > 1 else "status", status)()
