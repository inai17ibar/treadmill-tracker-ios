# Treadmill Tracker

ジムのトレッドミル（ランニングマシン）でのウォーキング・ランニングに特化した iOS アプリです。
GPS が使えない屋内でも、トレッドミルに設定した **速度と傾斜** から距離と消費カロリーを計算して記録します。

## 機能

- **ライブ計測**: 経過時間・距離・消費カロリー・ペース・METs・上昇・歩数 / ピッチを大きな文字で表示
- **速度・傾斜の操作**: トレッドミル本体と同じように ±0.1 / ±1 km/h、±0.5 / ±1 % で変更（長押しで連続）。
  変更ごとに区間として記録します
- **歩く / 走る**: カロリー計算式を自動（7.5 km/h 以上で「走る」）・歩く・走るから選択
- **メニュー**: 12-3-30、脂肪燃焼ウォーク、坂道インターバル、ウォーク＆ジョグ、ランインターバル、ペース走。
  速度の強さを 70〜130% で調整でき、ステップが変わると音声と振動で次の速度・傾斜を案内します
- **目標**: 時間・距離・消費カロリーの目標と進捗、達成時に音声で通知
- **音声ガイド**: 1 km（1 マイル）ごとのタイム、メニューの切り替え（音楽は一時的に小さくなります）
- **距離の補正**: 終了後にトレッドミルの表示距離を入力すると、全区間の速度を同じ比率で補正
- **履歴**: 今週の合計、速度・傾斜のグラフ、スプリット、区間の一覧
- **ヘルスケア**: 屋内ウォーキング / 屋内ランニングとして、距離・アクティブエネルギー・上昇を保存。
  体重・身長の読み込み
- **単位**: km / マイル

## 計算方法

区間（速度・傾斜が一定の時間）ごとに計算して合計します。一時停止中は含みません。

- 距離 = 速度 × 時間
- 酸素摂取量（ACSM の代謝計算式、VO₂: mL/kg/分、速度 S: m/分、傾斜 G: 小数）
  - 歩行: VO₂ = 0.1·S + 1.8·S·G + 3.5
  - 走行: VO₂ = 0.2·S + 0.9·S·G + 3.5
- 消費カロリー（kcal/分）= VO₂ × 体重(kg) / 1000 × 5
- 運動分（アクティブ）= 安静時の 3.5 を除いた値。ヘルスケアにはこちらを保存します

下り傾斜は 0% として計算します。手すりにつかまると実際の消費は少なくなります。

## 必要環境

- iOS 17 以降の iPhone
- Xcode 16 以降、[XcodeGen](https://github.com/yonaskolb/XcodeGen)

## ビルド

```sh
brew install xcodegen
xcodegen generate
open TreadmillTracker.xcodeproj
```

Signing & Capabilities で自分のチームを選んで実行してください。HealthKit の capability は
`project.yml` で設定済みです。歩数（CoreMotion）は実機でのみ取得できます。

### 実機ビルドの署名エラー

`Unable to process request - PLA Update available` が出た場合は、
[Apple Developer のアカウント](https://developer.apple.com/account/)で最新の
Apple Developer Program License Agreement を確認して同意してください。
組織のチームの場合は Account Holder による同意が必要です。
同意後、Xcode の Signing & Capabilities で対象の Team と
Automatically manage signing を確認し、Try Again を押して再ビルドします。

HealthKit の Clinical Health Records と Background Delivery は、このアプリでは使用しません。
Xcode でこれらの追加項目を有効にする必要はありません。
生成された `Support/` と `.xcodeproj` は Git の対象外です。
権限設定を再生成する場合は `xcodegen generate` を実行してください。
プロジェクトの再生成後は、自分の Team を選び直してください。

計算ロジックは Swift Package の `TreadmillKit` にあり、Linux でもテストできます。

```sh
swift test
```

## 構成

```text
Sources/TreadmillKit/       計算ロジック（UI・iOS フレームワークに依存しない）
  Metabolic.swift           ACSM 式、歩く / 走るの判定
  WorkoutSession.swift      速度・傾斜・一時停止を区間として記録、距離・カロリー・スプリット
  WorkoutProgram.swift      メニュー（ステップ）と現在位置
  WorkoutGoal.swift         目標と進捗
  WorkoutRecord.swift       保存する記録、距離の補正、週の合計
  Units.swift               単位と表示
Sources/TreadmillTracker/   SwiftUI アプリ
  Models/WorkoutModel.swift ライブ計測（タイマー・音声・メニューの進行・歩数）
  Services/                 HealthKit、CMPedometer、音声、履歴の保存（JSON）
  Views/                    ホーム、ワークアウト、サマリー、履歴、設定
Tests/TreadmillKitTests/
```
