# LGS+（Windows）

日本の建築現場向け **LGS / 石膏ボード / クロス** 材料積算アプリの **Windows 版**。  
PDF・写真図面から壁・天井を測り、注文書 PDF をオフライン生成します。

iPhone/iPad・Mac とは **別アカウント**（`client_app=windows`）です。アプリ内課金は未対応です。

## 必要環境

- Windows 10 / 11（64-bit）
- [Flutter SDK](https://docs.flutter.dev/get-started/install/windows)（stable）
- Visual Studio 2022（「デスクトップ開発 with C++」ワークロード）

確認:

```powershell
flutter doctor
```

`Windows` の項目がチェック済みであること。

## 起動

```powershell
cd path\to\LGS+windows
flutter pub get
flutter run -d windows
```

または:

```powershell
.\scripts\run_windows.ps1
```

## リリースビルド

```powershell
flutter build windows --release
# または
.\scripts\run_windows.ps1 -Release
```

成果物: `build\windows\x64\runner\Release\LGSPlus.exe`

## macOS 版との主な違い

| 項目 | Windows |
|---|---|
| アカウント区分 | `client_app=windows`（Mac/iOS と別） |
| DB | `sqflite_common_ffi` |
| ファイル保存後 | Explorer で選択表示 |
| アプリ内課金 | なし（サポート連絡） |
| OCR（ML Kit） | 未使用（モバイルのみ） |
| Dock 未読バッジ | なし（Mac 専用） |

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
macos/        # 参考用（Mac 版ランナー）
scripts/      # Windows 起動・ビルドスクリプト
```
