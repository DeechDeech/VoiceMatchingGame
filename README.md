# ボイス神経衰弱

Flutter で作成した、Android アプリ（APK）と Web（GitHub Pages）に対応する横画面の音声神経衰弱です。札をめくると日本語の音声が流れ、同じ音声の札を 2 枚そろえるとペアになります。読み札の文字は表示せず、声の記憶で遊びます。

## 動作環境

- Flutter 3.41 以降 / Dart 3.11 以降
- Android Studio（Android SDK・エミュレーター）
- Visual Studio Code（Flutter / Dart 拡張、GitHub Copilot / Copilot Chat 拡張）
- 音声は `assets/audio/voices/` の WAV を使用し、1ゲームごとに全クリップから 8 種類をランダムに選びます。

## 開発

```powershell
flutter pub get
flutter run
```

VS Code では `.vscode/launch.json` から Android または Chrome を選び、F5 で起動できます。Android Studio では Flutter プラグインを有効にし、このフォルダーを開いてください。

### APK の作成

```powershell
flutter build apk --release
```

APK は `build/app/outputs/flutter-apk/app-release.apk` に作成されます。端末へ直接インストールする場合は Android の設定で提供元不明アプリのインストールを許可してください。

### Web / GitHub Pages

```powershell
flutter build web --release --base-href "/VoiceMatchingGame/"
```

GitHub リポジトリの **Settings → Pages → Build and deployment → Source** を **GitHub Actions** に設定すると、`main` ブランチへの push ごとに `.github/workflows/deploy-pages.yml` が Web 版をビルド・公開します。

## 遊び方と設定

- カードをめくると、その札に登録された音声が流れます。文字や絵柄ではなく、音声だけで同じペアを探します。
- 2 枚をめくると 1 ターンです。全 8 ペアをそろえるとターン数を表示します。
- 音量設定では BGM と読み上げ音声の音量を調整できます。カードをめくる効果音は固定音量です。
- BGM は `assets/audio/bgm.mp3`（ループ再生）、カード音は `assets/audio/flip.wav` です。初回のタップ後に BGM を開始します（ブラウザーの自動再生制限に対応）。
- 札の縦横比は 1:1.40（縦長）です。全札が収まらない小さな画面ではスクロールできます。
- 音声の再生中でも次の札をめくれます（再生中の音声は新しい札の音声に切り替わります）。めくった札には再生時間を示す円形の表示が出ます。
- 札の背面画像は `assets/images/card_back.png`（仮画像、横500×縦700px など 1:1.40 を推奨）を同名で差し替えてください。
- 端末の向きは横向きのままセンサーで上下反転に追従します。
- 音声ファイルを追加・変更したら `dart run tool/generate_voice_catalog.dart <音声フォルダ>` で `assets/audio/voices/` と `lib/voice_catalog.dart` を再生成してください。

## テスト

```powershell
flutter test
flutter analyze
```
