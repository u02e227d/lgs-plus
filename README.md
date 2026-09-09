# LGS+

日本の建築現場向け **LGS / 石膏ボード / クロス** 材料積算アプリ。  
PDF・写真図面、またはカメラ撮影から、端側 CV 吸着で壁・天井を測り、注文書 PDF をオフライン生成します。

## 技術構成

| 層 | 実装 |
|---|---|
| UI | Flutter 3 / Material 3（日本語 Noto Sans JP） |
| 図面キャンバス | 3層 CustomPaint（底図 / 吸着・塗り / LGS点・グリッド） |
| 端側 CV | Dart 実装の Canny + 確率的 HoughLinesP 相当（OpenCV 互換ロジック、API費用ゼロ） |
| 永続化 | SQLite（完全オフライン） |
| 注文書 | `pdf` + `printing` + `share_plus`（Email / LINE / 印刷） |

## 主なフロー

1. **登録** → 会社情報入力 → メール活性化（デモはローカル模擬）→ パスワード設定  
2. **新規工地** → 図面アップロード（PDF / アルバム / カメラ）→ **比例尺**設定（例 3,640mm）  
3. **測定** → 壁ペン（Auto-Snap）/ 天井ペン（半透明塗り）→ 工法選択 → 自動積算  
4. **注文** → 測定チェック → 配送希望日 → 明細編集・追加 → PDF 共有

## 壁モード算量

- 面積 `S = 壁長 × 高さ`
- LGS：Stud 本数（両端含む）、Runner 天地長さ
- ボード：3×6 / 3×8、1層 / 2層
- クロス：門幅 0.9m × ロス率

## 天井モード算量

- 多角形面積（m² / 坪 / 畳）
- Mバー・CWバー・吊りボルト・ボード枚数
- 骨格グリッド **90°回転**対応

## 起動

```bash
cd ~/Desktop/LGS+
flutter pub get
flutter run
```

## ディレクトリ

```
lib/
  models/          # ドメインモデル
  data/            # SQLite
  services/        # 認証・積算・CV吸着・PDF
  screens/         # 認証 / 工地 / 図面 / 測定 / 注文
  widgets/         # キャンバス Painter
```

## 今後の拡張候補

- 本番メール活性化（SMTP / Firebase Auth）
- `opencv_dart` ネイティブ連携（より高精度な線分抽出）
- 両面張り・開口部控除・階別集計
- クラウド同期（任意）
