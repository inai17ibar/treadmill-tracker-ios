#!/usr/bin/env python3
"""Generate GitHub Pages from the same offline policy and help shipped in the app."""
import html
import json
from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parents[1]
DATA = json.loads((ROOT / "Sources/TreadmillTracker/Resources/AppInformation.json").read_text())
OUT = ROOT / "docs"
BASE = "https://inai17ibar.github.io/treadmill-tracker-ios/"


def escape(value):
    return html.escape(value, quote=True)


def page(title, body, filename):
    markup = f'''<!doctype html>
<html lang="ja">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="color-scheme" content="dark">
  <meta name="description" content="トレッドミルのサポートとプライバシー情報。屋内ウォーキング・ランニングの記録に。">
  <title>{escape(title)} | トレッドミル</title>
  <link rel="canonical" href="{BASE}{filename}">
  <link rel="icon" href="icon.png" type="image/png">
  <link rel="stylesheet" href="style.css">
</head>
<body>
  <a class="skip" href="#main">本文へ</a>
  <header><a class="brand" href="index.html"><img src="icon.png" alt="" width="48" height="48">トレッドミル</a>
  <nav aria-label="メインメニュー"><a href="support.html">サポート</a><a href="privacy.html">プライバシー</a></nav></header>
  <main id="main"><p class="eyebrow">TREADMILL TRACKER</p><h1>{escape(title)}</h1>{body}</main>
  <footer><p>運営者：{escape(DATA['publisher'])}</p><a href="mailto:{escape(DATA['email'])}">{escape(DATA['email'])}</a>
  <p>© {DATA['updated'][:4]} {escape(DATA['publisher'])}</p></footer>
</body>
</html>
'''
    (OUT / filename).write_text(markup)


OUT.mkdir(exist_ok=True)
for key, filename in (("privacy", "privacy.html"), ("support", "support.html")):
    doc = DATA[key]
    if doc["url"] != BASE + filename:
        raise ValueError("The public URL and bundled app URL must match")
    sections = [f'<p class="updated">更新日：{escape(DATA["updated"])}</p>']
    for section in doc["sections"]:
        paragraphs = "".join(f'<p>{escape(text)}</p>' for text in section["paragraphs"])
        sections.append(f'<section><h2>{escape(section["title"])}</h2>{paragraphs}</section>')
    if key == "privacy":
        sections.append('<p><a href="https://docs.github.com/ja/site-policy/privacy-policies/github-general-privacy-statement">GitHubのプライバシーポリシー</a></p>')
    page(doc["title"], "\n".join(sections), filename)

page("今日も、一歩先へ。", '''
<p class="lead">屋内でも、積み重ねよう。<br>トレッドミルでのウォーキング・ランニングを、見やすい数字で記録。</p>
<section><h2>自分のペースで、記録する。</h2><p>速度と傾斜を入力して、時間・距離・推定消費カロリーを確認。メニューと音声ガイドで、日々の室内トレーニングを支えます。</p><p>対応環境：iOS 17以降のiPhone。アカウント登録は不要です。</p></section>
<div class="links"><a href="support.html">サポート・使い方 →</a><a href="privacy.html">プライバシーポリシー →</a></div>
''', "index.html")
shutil.copyfile(ROOT / "Sources/TreadmillTracker/Assets.xcassets/AppIcon.appiconset/AppIcon.png", OUT / "icon.png")
(OUT / ".nojekyll").touch()
print("Generated docs/index.html, privacy.html, support.html and icon.png")
