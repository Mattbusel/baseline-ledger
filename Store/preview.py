"""Upload the App Preview video (from CI's preview artifact) to a version's 6.9-inch preview set.

    python Store/preview.py <version> <preview.mp4> [locale ...]     default locale en-US
    python Store/preview.py <version> --status
"""
import hashlib
import sys
import time
from pathlib import Path

import requests

sys.path.insert(0, str(Path(__file__).resolve().parent))
import asc  # noqa: E402

PREVIEW = "IPHONE_67"


def loc_id(version, locale):
    app = asc.find_app()
    v = asc.call("GET", f"/v1/apps/{app['id']}/appStoreVersions", params={"filter[versionString]": version})["data"][0]
    locs = asc.call("GET", f"/v1/appStoreVersions/{v['id']}/appStoreVersionLocalizations", params={"limit": 50})["data"]
    return next(l["id"] for l in locs if l["attributes"]["locale"] == locale)


def preview_set(lid):
    sets = asc.call("GET", f"/v1/appStoreVersionLocalizations/{lid}/appPreviewSets")["data"]
    s = next((x for x in sets if x["attributes"]["previewType"] == PREVIEW), None)
    if s:
        return s
    return asc.call("POST", "/v1/appPreviewSets", {"data": {"type": "appPreviewSets", "attributes": {"previewType": PREVIEW},
                    "relationships": {"appStoreVersionLocalization": {"data": {"type": "appStoreVersionLocalizations", "id": lid}}}}})["data"]


def upload(version, mp4: Path, locale):
    data = mp4.read_bytes()
    md5 = hashlib.md5(data).hexdigest()
    s = preview_set(loc_id(version, locale))
    for p in asc.call("GET", f"/v1/appPreviewSets/{s['id']}/appPreviews")["data"]:
        if p["attributes"].get("sourceFileChecksum") == md5:
            print(locale, "already uploaded:", p["attributes"].get("assetDeliveryState", {}).get("state")); return
        asc.call("DELETE", f"/v1/appPreviews/{p['id']}")
    made = asc.call("POST", "/v1/appPreviews", {"data": {"type": "appPreviews",
                    "attributes": {"fileName": mp4.name, "fileSize": len(data), "mimeType": "video/mp4", "previewFrameTimeCode": "00:00:08:00"},
                    "relationships": {"appPreviewSet": {"data": {"type": "appPreviewSets", "id": s["id"]}}}}})["data"]
    for op in made["attributes"]["uploadOperations"]:
        h = {x["name"]: x["value"] for x in op.get("requestHeaders", [])}
        requests.request(op["method"], op["url"], headers=h, data=data[op["offset"]: op["offset"] + op["length"]], timeout=300).raise_for_status()
    asc.call("PATCH", f"/v1/appPreviews/{made['id']}", {"data": {"type": "appPreviews", "id": made["id"],
             "attributes": {"uploaded": True, "sourceFileChecksum": md5}}})
    for _ in range(30):
        time.sleep(10)
        st = asc.call("GET", f"/v1/appPreviews/{made['id']}")["data"]["attributes"].get("assetDeliveryState", {})
        if st.get("state") in ("COMPLETE", "FAILED"):
            break
    print(locale, "preview:", st)


if __name__ == "__main__":
    ver = sys.argv[1]
    if "--status" in sys.argv:
        s = preview_set(loc_id(ver, "en-US"))
        for p in asc.call("GET", f"/v1/appPreviewSets/{s['id']}/appPreviews")["data"]:
            print(p["id"], p["attributes"].get("assetDeliveryState"))
    else:
        for loc in (sys.argv[3:] or ["en-US"]):
            upload(ver, Path(sys.argv[2]), loc)
