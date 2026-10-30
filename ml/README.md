# EasySell Vision: training the on-device product model

The app's own photo model (design: `docs/superpowers/specs/2026-10-31-phone-only-on-device-ai-design.md` §5a).
It runs only on the phone. It turns a photo into 256 numbers (a "fingerprint"); two photos of the same product give nearby fingerprints. The shop teaches each product with 2–3 photos, and every confirmed scan adds one more. Recognising a product needs no retraining and no server.

## Why it is trained, and on what

An ImageNet backbone tells a dog from a car, not one brand of soap from another.
The model is therefore fine-tuned with ArcFace metric learning on about 9,700 packaged-goods products from Products-10K. That teaches it to separate look-alike retail packs.

Testing uses only products the model never trained on, because every product in a real shop is new to it:

| Test set | What it is |
|---|---|
| Held-out Products-10K SKUs | 400 products left out of training |
| RP2K | 2,370 retail products photographed on shelves |
| Grocery Store dataset | 81 classes of real phone photos taken in shops, including loose fruit and vegetables |

Each test mirrors the app. Three photos per product are enrolled and the rest are scans. "shop200" means picking from a 200-product shop.

## Pipeline (all on the local GPU, nothing hosted)

```bash
# one-time: datasets to G:/Easy_sell/ml_data (see prepare_data.py docstring)
python -I ml/prepare_data.py --data G:/Easy_sell/ml_data
python -I ml/eval_fewshot.py --data G:/Easy_sell/ml_data --backbone mobilenetv3_large_100.ra_in1k  # baseline
python -I ml/train.py --data G:/Easy_sell/ml_data --out G:/Easy_sell/ml_runs/v1 --backbone mobilenetv3_large_100.ra_in1k
python -I ml/export_tflite.py --checkpoint G:/Easy_sell/ml_runs/v1/best.pt --data G:/Easy_sell/ml_data --work G:/Easy_sell/ml_runs/v1/export
```

`export_tflite.py` checks each TFLite variant against PyTorch on real photos. It ships the smallest variant that agrees, to `assets/models/easysell_vision.tflite`.

When the model changes, bump `VisionEmbedder.modelId`. The app then re-embeds products from the thumbnails it keeps, so shops never mix fingerprints from two models.

## Results

Recorded in `ml/RESULTS.md` after each training run.
