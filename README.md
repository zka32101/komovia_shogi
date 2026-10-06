# komovia_shogi

将棋（効棋 / zka32101/kouki-shogi）のルール・AI・詰め・棋譜・盤描画を、[komovia_core](https://github.com/zka32101/komovia_core) の `Game`/`Engine`/`BoardRenderer` インターフェース上に実装するパッケージ。

## 現在の段階

パッケージの雛形のみ（`pubspec.yaml`で`komovia_core`への依存を宣言済み）。効棋からの将棋固有コードの移植（段階2）は未着手。

移植対象・手順は Komovia_共通基盤設計（Google Drive）§2c・§4 を参照。kouki-shogi は改名せず、効棋として現行配布を継続する。
