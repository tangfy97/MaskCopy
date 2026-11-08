#!/usr/bin/env python3
"""Collects specimen (sample) identity documents from Wikimedia Commons for testing.

    python3 -I scripts/fetch_specimens.py [Fixtures/specimens/commons]

Uses the Commons API, one request at a time, and keeps each file's title, source page,
licence and author in manifest.json. The images go in Fixtures/specimens/, which is not
committed: they are not ours to publish. Only files whose title or description says they are
a specimen or sample, or a document of a made-up person, are kept.
"""
import json
import os
import re
import sys
import time
import urllib.parse
import urllib.request

API = "https://commons.wikimedia.org/w/api.php"
AGENT = "MaskeSpecimenFetcher/0.1 (test data for an open-source privacy app; https://github.com/tangfy97/MaskCopy)"
OUT = sys.argv[1] if len(sys.argv) > 1 else "Fixtures/specimens/commons"

COUNTRIES = {
    # Europe
    "AT": "Austria Austrian", "BE": "Belgium Belgian", "BG": "Bulgaria Bulgarian", "HR": "Croatia Croatian",
    "CY": "Cyprus Cypriot", "CZ": "Czech", "DK": "Denmark Danish", "EE": "Estonia Estonian", "FI": "Finland Finnish",
    "FR": "France French", "DE": "Germany German", "GR": "Greece Greek", "HU": "Hungary Hungarian",
    "IE": "Ireland Irish", "IT": "Italy Italian", "LV": "Latvia Latvian", "LT": "Lithuania Lithuanian",
    "LU": "Luxembourg", "MT": "Malta Maltese", "NL": "Netherlands Dutch", "PL": "Poland Polish",
    "PT": "Portugal Portuguese", "RO": "Romania Romanian", "SK": "Slovakia Slovak", "SI": "Slovenia Slovenian",
    "ES": "Spain Spanish", "SE": "Sweden Swedish", "NO": "Norway Norwegian", "IS": "Iceland Icelandic",
    "LI": "Liechtenstein", "CH": "Switzerland Swiss", "GB": "United Kingdom British UK", "UA": "Ukraine Ukrainian",
    "RS": "Serbia Serbian", "TR": "Turkey Turkish", "AL": "Albania Albanian", "BA": "Bosnia", "ME": "Montenegro",
    "MK": "North Macedonia Macedonian", "MD": "Moldova Moldovan", "GE": "Georgia Georgian", "BY": "Belarus Belarusian",
    # Elsewhere
    "US": "United States US American", "CA": "Canada Canadian", "MX": "Mexico Mexican", "AU": "Australia Australian",
    "NZ": "New Zealand", "CN": "China Chinese", "HK": "Hong Kong", "TW": "Taiwan", "JP": "Japan Japanese",
    "KR": "South Korea Korean", "SG": "Singapore Singaporean", "MY": "Malaysia Malaysian",
}
KINDS = {
    "passport": ["passport", "passport data page"],
    "idCard": ["identity card", "ID card"],
    "drivingLicence": ["driving licence", "driver license"],
    "residencePermit": ["residence permit"],
}
SPECIMEN = re.compile(r"specimen|sample|muster|mustermann|modèle|modelo|esempio|voorbeeld|exemplar|wzór|vzor|näyte|prov|example|样本|樣本|見本|견본", re.I)
JUNK = re.compile(r"cover|stamp|visa\b|logo|map|hard ?drive|ultra|portrait of|svg$|\.pdf$|\.tif", re.I)


def api(params):
    params = dict(params, format="json", maxlag="5")
    req = urllib.request.Request(API + "?" + urllib.parse.urlencode(params), headers={"User-Agent": AGENT})
    for attempt in range(3):
        try:
            with urllib.request.urlopen(req, timeout=30) as r:
                return json.load(r)
        except Exception as e:  # rate limit or network: wait and retry
            time.sleep(5 * (attempt + 1))
            last = e
    raise last


def search(query, limit=12):
    d = api({"action": "query", "list": "search", "srsearch": query, "srnamespace": 6, "srlimit": limit})
    return [r["title"] for r in d.get("query", {}).get("search", [])]


def info(titles):
    d = api({"action": "query", "prop": "imageinfo", "titles": "|".join(titles),
             "iiprop": "url|size|mime|extmetadata", "iiurlwidth": 1800})
    out = {}
    for page in d.get("query", {}).get("pages", {}).values():
        ii = (page.get("imageinfo") or [None])[0]
        if ii:
            out[page["title"]] = ii
    return out


def meta(ii, key):
    v = ii.get("extmetadata", {}).get(key, {}).get("value", "")
    return re.sub(r"<[^>]+>", "", v).strip()


def main():
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, "manifest.json")
    manifest = json.load(open(path)) if os.path.exists(path) else {}
    seen = {m["title"] for m in manifest.values()}
    for code, names in COUNTRIES.items():
        country_word = names.split()[0] if code not in ("US", "GB", "NZ", "HK", "KR") else {
            "US": "United States", "GB": "United Kingdom", "NZ": "New Zealand", "HK": "Hong Kong", "KR": "South Korea"}[code]
        for kind, words in KINDS.items():
            titles = []
            for w in words:
                titles += search(f"{country_word} {w} specimen")
                time.sleep(0.5)
            titles = [t for t in dict.fromkeys(titles) if t not in seen and not JUNK.search(t)]
            if not titles:
                continue
            for title, ii in info(titles[:40]).items():
                text = title + " " + meta(ii, "ImageDescription") + " " + meta(ii, "Categories")
                if not ii["mime"].startswith("image/") or min(ii["width"], ii["height"]) < 500:
                    continue
                if not SPECIMEN.search(text):
                    continue
                if not any(n.lower() in text.lower() for n in names.split()):
                    continue
                name = f"{code}-{kind}-{len([k for k in manifest if k.startswith(code + '-' + kind)]) + 1:02d}"
                ext = ".png" if ii["mime"] == "image/png" else ".jpg"
                url = ii.get("thumburl") or ii["url"]
                req = urllib.request.Request(url, headers={"User-Agent": AGENT})
                try:
                    with urllib.request.urlopen(req, timeout=60) as r:
                        data = r.read()
                except Exception as e:
                    print("  skip", title, e)
                    continue
                with open(os.path.join(OUT, name + ext), "wb") as f:
                    f.write(data)
                manifest[name] = {
                    "title": title, "file": name + ext, "country": code, "kind": kind,
                    "page": ii.get("descriptionurl"), "license": meta(ii, "LicenseShortName"),
                    "author": meta(ii, "Artist")[:200], "description": meta(ii, "ImageDescription")[:300],
                }
                seen.add(title)
                print(f"{name}: {title} ({manifest[name]['license']})", flush=True)
                time.sleep(0.5)
            json.dump(manifest, open(path, "w"), indent=1, ensure_ascii=False)
    print(f"{len(manifest)} specimens in {OUT}")


if __name__ == "__main__":
    main()
