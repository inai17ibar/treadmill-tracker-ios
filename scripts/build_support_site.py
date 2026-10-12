#!/usr/bin/env python3
"""Generate bilingual GitHub Pages from the app's offline policy and help."""
import html
import json
from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs"
BASE = "https://inai17ibar.github.io/treadmill-tracker-ios/"
LABELS = {
    "ja": dict(brand="トレッドミル", description="トレッドミルのサポートとプライバシー情報。屋内ウォーキング・ランニングの記録に。", skip="本文へ", nav="メインメニュー", support="サポート", privacy="プライバシー", updated="更新日：", publisher="運営者：", github="GitHubのプライバシーポリシー", heading="今日も、一歩先へ。", lead="屋内でも、積み重ねよう。", intro="トレッドミルでのウォーキング・ランニングを、見やすい数字で記録。", feature="自分のペースで、記録する。", detail="速度と傾斜を入力して、時間・距離・推定消費カロリーを確認。メニューと音声ガイドで、日々の室内トレーニングを支えます。", requirements="対応環境：iOS 17以降のiPhone。アカウント登録は不要です。"),
    "en": dict(brand="Treadmill", description="Help and privacy information for Treadmill, an indoor walking and running workout tracker.", skip="Skip to content", nav="Main navigation", support="Support", privacy="Privacy", updated="Updated: ", publisher="Publisher: ", github="GitHub privacy policy", heading="One step further.", lead="Keep moving. Even indoors.", intro="Record indoor walks and runs with clear, readable workout metrics.", feature="Track at your own pace.", detail="Enter speed and incline to track time, distance and estimated calories. Training programs and voice guidance support your daily indoor workouts.", requirements="Requires an iPhone with iOS 17 or later. No account required.")
}


def escape(value):
    return html.escape(value, quote=True)


def page(lang, data, title, body, filename):
    labels = LABELS[lang]
    prefix = "en/" if lang == "en" else ""
    assets = "../" if prefix else ""
    alternate = ("../" if prefix else "en/") + filename
    other = "日本語" if lang == "en" else "English"
    target = OUT / prefix
    target.mkdir(parents=True, exist_ok=True)
    markup = f'''<!doctype html>
<html lang="{lang}">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="color-scheme" content="dark">
  <meta name="description" content="{escape(labels['description'])}">
  <title>{escape(title)} | {labels['brand']}</title>
  <link rel="canonical" href="{BASE}{prefix}{filename}">
  <link rel="alternate" hreflang="ja" href="{BASE}{filename}">
  <link rel="alternate" hreflang="en" href="{BASE}en/{filename}">
  <link rel="icon" href="{assets}icon.png" type="image/png">
  <link rel="stylesheet" href="{assets}style.css">
</head>
<body>
  <a class="skip" href="#main">{labels['skip']}</a>
  <header><a class="brand" href="index.html"><img src="{assets}icon.png" alt="" width="48" height="48">{labels['brand']}</a>
  <nav aria-label="{labels['nav']}"><a href="support.html">{labels['support']}</a><a href="privacy.html">{labels['privacy']}</a><a href="{alternate}" lang="{'ja' if prefix else 'en'}">{other}</a></nav></header>
  <main id="main"><p class="eyebrow">TREADMILL TRACKER</p><h1>{escape(title)}</h1>{body}</main>
  <footer><p>{labels['publisher']}{escape(data['publisher'])}</p><a href="mailto:{escape(data['email'])}">{escape(data['email'])}</a>
  <p>© {data['updated'][:4]} {escape(data['publisher'])}</p></footer>
</body>
</html>
'''
    (target / filename).write_text(markup)


OUT.mkdir(exist_ok=True)
for lang in LABELS:
    suffix = "-en" if lang == "en" else ""
    data = json.loads((ROOT / f"Sources/TreadmillTracker/Resources/AppInformation{suffix}.json").read_text())
    labels = LABELS[lang]
    prefix = "en/" if lang == "en" else ""
    for key, filename in (("privacy", "privacy.html"), ("support", "support.html")):
        doc = data[key]
        if doc["url"] != BASE + prefix + filename:
            raise ValueError("The public URL and bundled app URL must match")
        sections = [f'<p class="updated">{labels["updated"]}{escape(data["updated"])}</p>']
        for section in doc["sections"]:
            paragraphs = "".join(f'<p>{escape(text)}</p>' for text in section["paragraphs"])
            sections.append(f'<section><h2>{escape(section["title"])}</h2>{paragraphs}</section>')
        if key == "privacy":
            sections.append(f'<p><a href="https://docs.github.com/{lang}/site-policy/privacy-policies/github-general-privacy-statement">{labels["github"]}</a></p>')
        page(lang, data, doc["title"], "\n".join(sections), filename)
    body = f'''<p class="lead">{labels['lead']}<br>{labels['intro']}</p>
<section><h2>{labels['feature']}</h2><p>{labels['detail']}</p><p>{labels['requirements']}</p></section>
<div class="links"><a href="support.html">{data['support']['title']} →</a><a href="privacy.html">{data['privacy']['title']} →</a></div>'''
    page(lang, data, labels["heading"], body, "index.html")
shutil.copyfile(ROOT / "Sources/TreadmillTracker/Assets.xcassets/AppIcon.appiconset/AppIcon.png", OUT / "icon.png")
(OUT / ".nojekyll").touch()
print("Generated Japanese and English index, privacy and support pages")
