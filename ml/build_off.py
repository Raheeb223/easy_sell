"""Builds the commercial training set from Open Food / Beauty / Products Facts.

Open Food Facts (food, drinks), Open Beauty Facts (soap, shampoo, toothpaste)
and Open Products Facts (detergent, toilet cleaner, air freshener, household)
are crowd-sourced photo databases of packaged products from ~150 countries.
Database: ODbL. Photos: CC BY-SA 3.0 -- commercial use allowed with
attribution (see ml/README.md). Each product is photographed by ordinary
people with phones, from several sides: exactly the shop's view.

Per product: the uploaded photos that are NOT the ingredients / nutrition
close-ups (those are text tables that look alike across products), front
photos first, at most --per-product. South Asian products are all taken; the
rest of the world fills up to --max-products.

Images are fetched in parallel, resized to short side 256, and appended to
ONE pack file in shuffled order (the datasets live on a hard disk; see
pack_data.py). Resumable: re-running skips what is already packed.

    python -I ml/build_off.py --data G:/Easy_sell/ml_data --max-products 300000
"""
import argparse
import gzip
import io
import json
import random
import threading
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

import numpy as np
import pyarrow.parquet as pq
import requests
from PIL import Image

PRIORITY = {"en:bangladesh", "en:india", "en:pakistan", "en:nepal", "en:sri-lanka"}
SKIP_SELECTED = ("ingredients", "nutrition")
SHORT = 256

SOURCES = {
    "food": "https://openfoodfacts-images.s3.eu-west-3.amazonaws.com/data",
    "beauty": "https://images.openbeautyfacts.org/images/products",
    "petfood": "https://images.openpetfoodfacts.org/images/products",
    "products": "https://images.openproductsfacts.org/images/products",
}


def code_path(code: str) -> str:
    if len(code) <= 8:
        return code
    c = code.zfill(13)
    return f"{c[0:3]}/{c[3:6]}/{c[6:9]}/{c[9:]}"


def pick(raw_ids, selected):
    """raw_ids: uploaded image ids; selected: {key like front_en: imgid}."""
    skip = {v for k, v in selected.items() if k.startswith(SKIP_SELECTED)}
    front = [v for k, v in selected.items() if k.startswith("front")]
    order = list(dict.fromkeys([*front, *raw_ids]))
    return [i for i in order if i in raw_ids and i not in skip]


def from_parquet(path: Path, source: str):
    pf = pq.ParquetFile(path)
    for rg in range(pf.num_row_groups):
        t = pf.read_row_group(rg, columns=["code", "images", "countries_tags"])
        for r in t.to_pylist():
            imgs = r["images"] or []
            raw = [i["key"] for i in imgs if i["key"] and i["key"].isdigit() and i["sizes"] and i["sizes"].get("400")]
            sel = {i["key"]: str(i["imgid"]) for i in imgs if i["key"] and not i["key"].isdigit() and i["imgid"] is not None}
            ids = pick(raw, sel)
            if len(ids) >= 2 and r["code"]:
                yield source, r["code"], ids, bool(PRIORITY & set(r["countries_tags"] or []))


def from_jsonl(path: Path, source: str):
    with gzip.open(path, "rt", encoding="utf-8") as fh:
        for line in fh:
            j = json.loads(line)
            im = j.get("images") or {}
            up = im.get("uploaded") or {k: v for k, v in im.items() if str(k).isdigit()}
            raw = [k for k, v in up.items() if isinstance(v, dict) and (v.get("sizes") or {}).get("400")]
            sel = {}
            for kind, langs in (im.get("selected") or {}).items():
                for lang, v in (langs or {}).items():
                    if isinstance(v, dict) and v.get("imgid") is not None:
                        sel[f"{kind}_{lang}"] = str(v["imgid"])
            ids = pick(raw, sel)
            if len(ids) >= 2 and j.get("code"):
                yield source, j["code"], ids, bool(PRIORITY & set(j.get("countries_tags") or []))


_local = threading.local()


def fetch(url):
    s = getattr(_local, "s", None)
    if s is None:
        s = _local.s = requests.Session()
        s.headers["User-Agent"] = "EasySell-dataset-builder/1.0 (on-device shop assistant research)"
    for attempt in range(3):
        try:
            r = s.get(url, timeout=20)
            if r.status_code == 200 and r.content:
                im = Image.open(io.BytesIO(r.content)).convert("RGB")
                w, h = im.size
                k = SHORT / min(w, h)
                if k < 1:
                    im = im.resize((max(1, round(w * k)), max(1, round(h * k))), Image.BICUBIC)
                out = io.BytesIO()
                im.save(out, "JPEG", quality=88)
                return out.getvalue()
            if r.status_code == 404:
                return None
        except Exception:
            time.sleep(1 + attempt)
    return None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--data", type=Path, required=True)
    ap.add_argument("--max-products", type=int, default=300000)
    ap.add_argument("--per-product", type=int, default=4)
    ap.add_argument("--threads", type=int, default=48)
    a = ap.parse_args()
    off = a.data / "off"

    products = []
    for src, fn in (("food", from_parquet(off / "food.parquet", "food")),
                    ("beauty", from_parquet(off / "beauty.parquet", "beauty")),
                    ("petfood", from_parquet(off / "petfood.parquet", "petfood")),
                    ("products", from_jsonl(off / "openproductsfacts.jsonl.gz", "products"))):
        n0 = len(products)
        products.extend(fn)
        print(f"{src}: {len(products) - n0} products with 2+ usable photos", flush=True)

    rng = random.Random(0)
    rng.shuffle(products)
    # Household, beauty and pet products are rarer than food: keep them all,
    # plus every South Asian product, then fill with the rest of the world.
    must = [p for p in products if p[3] or p[0] != "food"]
    rest = [p for p in products if not (p[3] or p[0] != "food")]
    chosen = must + rest[: max(0, a.max_products - len(must))]
    print(f"chosen {len(chosen)} products ({len(must)} South Asian / non-food)", flush=True)

    jobs = []
    for src, code, ids, _ in chosen:
        for i in ids[: a.per_product]:
            jobs.append((f"{src}:{code}", f"{SOURCES[src]}/{code_path(code)}/{i}.400.jpg"))
    rng.shuffle(jobs)

    pack = a.data / "off_index.pack"
    urls_done = a.data / "off_index.urls.txt"
    done = set(urls_done.read_text(encoding="utf-8").split("\n")) if urls_done.exists() else set()
    offsets, lengths, labels = [], [], []
    if done and (a.data / "off_index.offsets.npy").exists():
        o = np.load(a.data / "off_index.offsets.npy")
        offsets, lengths = list(o[0]), list(o[1])
        labels = (a.data / "off_index.labels.txt").read_text(encoding="utf-8").split("\n")
    jobs = [j for j in jobs if j[1] not in done]
    print(f"{len(jobs)} images to fetch ({len(done)} already packed)", flush=True)

    pos = pack.stat().st_size if pack.exists() else 0
    t0 = time.time()

    def save():
        np.save(a.data / "off_index.offsets.npy", np.array([offsets, lengths], dtype=np.int64))
        (a.data / "off_index.labels.txt").write_text("\n".join(labels), encoding="utf-8")

    with open(pack, "ab") as out, open(urls_done, "a", encoding="utf-8") as ulog, \
            ThreadPoolExecutor(a.threads) as ex:
        for start in range(0, len(jobs), 20000):
            chunk = jobs[start:start + 20000]
            futs = {ex.submit(fetch, url): (label, url) for label, url in chunk}
            for f in as_completed(futs):
                label, url = futs[f]
                b = f.result()
                ulog.write(url + "\n")
                if not b:
                    continue
                out.write(b)
                offsets.append(pos)
                lengths.append(len(b))
                labels.append(label)
                pos += len(b)
            out.flush()
            ulog.flush()
            save()
            done_n = start + len(chunk)
            rate = done_n / (time.time() - t0)
            print(f"{done_n}/{len(jobs)} fetched, {len(labels)} packed, {pos / 1e9:.1f} GB, "
                  f"{rate:.0f} img/s, eta {(len(jobs) - done_n) / max(rate, 1) / 60:.0f} min", flush=True)
    save()
    print(f"done: {len(labels)} images, {len(set(labels))} products", flush=True)


if __name__ == "__main__":
    main()
