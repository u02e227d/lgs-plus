# LGS+（Windows）

日本の建築現場向け **LGS / 石膏ボード / クロス** 材料積算アプリの Windows 版。  
PDF・写真図面から壁・天井を測り、注文書 PDF をオフライン生成します。

iPhone/iPad・Mac とは **別アカウント**（`client_app=windows`）です。アプリ内課金は未対応です。

## 起動（Windows 上）

```bash
cd path\to\LGS+windows
flutter pub get
flutter run -d windows
```

リリースビルド:

```bash
flutter build windows --release
```

成果物: `build\windows\x64\runner\Release\LGSPlus.exe`

## 技術構成

| 層 | 実装 |
|---|---|
| UI | Flutter 3 / Material 3 |
| 永続化 | SQLite（`sqflite_common_ffi`） |
| 注文書 | `pdf` + `printing` + ファイル保存 |

## ディレクトリ

```
lib/          # 共通 Dart コード
windows/      # Windows ランナー（CMake）
```
