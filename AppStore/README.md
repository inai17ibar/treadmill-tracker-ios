# 初回申請 1.0.0

## App Store Connect 入力用

- Bundle ID: `com.inai17ibar.TreadmillTracker`
- バージョン: `1.0.0` / ビルド: `1`（再アップロード時はビルド番号を増やす）
- 第一言語: 日本語
- カテゴリ案: ヘルスケア／フィットネス
- コピーライト: `2026 Soichiro Inatani`
- サポートURL: https://inai17ibar.github.io/treadmill-tracker-ios/support.html
- プライバシーポリシーURL: https://inai17ibar.github.io/treadmill-tracker-ios/privacy.html
- 掲載文: `ja-JP/` 内の各テキスト。名称の空き状況は App Store Connect で確認する。
- 審査メモ: `review-notes.txt`
- 審査用ログイン: 不要
- 審査連絡先: Soichiro Inatani / inai17ibar@gmail.com。App Store Connect が求める電話番号は本人が入力する。

価格・配信地域・公開タイミング・年齢制限の質問票は、運営者が App Store Connect で確定する。
本アプリには広告、アプリ内課金、ユーザー投稿、チャット、自由なWeb閲覧、医療診断・治療の機能はない。
フィットネス／健康に関する質問には実際の機能に従って回答し、対象年齢の最終判定は Apple の質問票を使う。

## App Privacy の回答準備

現在の実装では、健康・運動・設定のデータを端末内と Apple の HealthKit で処理し、
開発者のサーバーへ送信しない。広告・解析・トラッキング SDK もない。
Apple の「端末上でのみ処理されるデータは収集ではない」という定義に基づき、
アプリ本体の回答案は「データを収集しない」。最終提出時に実装と利用サービスを再確認する。

ブラウザで開くサポートページは GitHub Pages 上にあり、GitHub 側のアクセス情報処理は
プライバシーポリシーに記載した。ユーザーから任意に送信されるサポートメールは、
問い合わせ対応に使用する。収集・送信機能や SDK を追加した場合は、回答とポリシーを更新する。

`PrivacyInfo.xcprivacy` には UserDefaults の利用理由 `CA92.1`（本アプリの設定保存）、
トラッキングなし、開発者による収集なしを宣言した。
`ITSAppUsesNonExemptEncryption = false` は、自前の暗号化実装・外部暗号ライブラリがない現状に対応する。

## スクリーンショット

実際の1.0.0ビルドから撮影する。`Design/dark-lime-mockup.png` はデザイン案なので、実画面の代わりに提出しない。
Appleの現行仕様に合うiPhone画面を使い、以下の5場面を候補とする。

1. ホーム：週の実績、選択中のメニュー、スタート
2. 計測中：経過時間、距離、カロリー、速度・傾斜の操作
3. メニュー選択：インターバルやウォーク＆ジョグ
4. 履歴の詳細：速度・傾斜のグラフ、スプリット
5. 設定：任意のヘルスケア連携と履歴復元

実ユーザーの健康情報を掲載せず、必要ならテスト用記録を使う。
未実装の機能、推定値を実測値とする説明、医学的効果の断定を含めない。

## Archive とアップロード

1. `project.yml` のバージョン・ビルドを確認する。生成済みInfo.plistだけを編集しない。
2. `xcodegen generate` 後、自分のTeamとAutomatically manage signingを選ぶ。
3. 実行先をAny iOS Deviceにし、Product > Archiveを実行する。
4. OrganizerでValidate Appを実行して、配布用署名・アイコン・Manifestなどを確認する。
5. Distribute App > App Store Connectでアップロードする。
6. TestFlightの配信用ビルドで、手入力、単位、メニュー、停止・再開、補正、保存、復元、
   HealthKit／モーション拒否時の動作、サポート・ポリシー表示を確認する。
7. App Store Connectで掲載情報・スクリーンショット・申告・価格／地域を入力し、ビルドを選択する。
8. 公開タイミングを選んで審査へ提出する。Appleへのアップロードと審査提出は今回の準備作業には含まない。

## 公開ページの更新

本文の唯一の編集元は `Sources/TreadmillTracker/Resources/AppInformation.json`。
アプリ内の案内も同じファイルを読む。編集後に次を実行する。

```sh
python3 scripts/build_support_site.py
```

`docs/` のHTMLとアプリ側のJSONを一緒にコミット・Pushする。
GitHub Pagesはmainブランチの`/docs`を公開する。配信されたURLがHTTP 200で表示されることを確認する。

## Apple公式資料

- [App Privacy Details](https://developer.apple.com/app-store/app-privacy-details/)
- [HealthKit privacy](https://developer.apple.com/documentation/healthkit/protecting-user-privacy)
- [Required reason APIs](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype)
- [Export compliance property](https://developer.apple.com/documentation/bundleresources/information-property-list/itsappusesnonexemptencryption)
- [Screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications)
- [Upload builds](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds)
