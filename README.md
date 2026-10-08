# Komovia Shogi (komovia_shogi)

将棋の対局・AI・詰め将棋・棋譜・盤描画と、フレンド/通知/メッセージ/ランキング/トーナメントなどの社交機能を備えたFlutterアプリ。

「Komovia」ファミリー（komovia_shogi / komovia_go / komovia_chess）の一つで、ゲーム横断の共通基盤 [komovia_core](https://github.com/zka32101/komovia_core) に依存する。

## ブランド

**Komovia Shogi** を正式名称として採用（未公開段階での決定）。将棋ルール・AI・盤描画は元々 [zka32101/kouki-shogi](https://github.com/zka32101/kouki-shogi)（効棋）から移植されたもので、`lib/src/*.dart` の一部ファイルのドキュメントコメントにその移植元が技術的な出典として残っているが、これは製品名の方針とは独立した履歴的な注記であり、ユーザー向けのブランドは Komovia Shogi に統一する。

## 構成

- `lib/src/` — 将棋ルール・AI・盤描画（`ShogiGame`/`ShogiEngine`/`ShogiPosition`/`ShogiBoardRenderer`/`ShogiHandicapRule`/`ShogiPuzzle`、`komovia_core`の`Game`/`Engine`/`Position`/`BoardRenderer`/`HandicapRule`/`Puzzle`インターフェースを実装）
- `lib/services/`, `lib/viewmodels/`, `lib/views/screens/` — Firebase/Riverpodベースの社交機能アプリ層（Friendship/AppNotification/DirectMessage/LeaderboardEntry/Tournament、いずれも`komovia_core`の共有モデルを使用）
- `lib/firebase_options.dart` — プレースホルダー設定。実際のFirebaseプロジェクトに接続するには `flutterfire configure` を実行する必要がある
