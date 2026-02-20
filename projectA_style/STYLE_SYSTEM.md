# ProjectA Style System

## Purpose
7キャラ紹介で得られた画風を、別プロジェクトでも再現するためのスタイル分離キット。

## Style IDs
- `main`: チャッピー/クロコ/ジェミー王/ラマ/グロック/カーソル向け
- `shinen`: 深淵将軍向け（重厚・陰影強め）

## Usage Rule
- 今回運用は全キャラ `main` を使用
- `shinen` は保存のみ（将来バリアントとして利用可能）

## Prompt Assembly
`prompts/base_template.txt` + `prompts/style_main.txt` + キャラ要件

## Anchors
- `references/style_main_anchor.jpg`
- `references/style_shinen_anchor.jpg`

生成時は該当アンカー画像を inlineData で添付する。
