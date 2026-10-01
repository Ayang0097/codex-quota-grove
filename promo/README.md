# Codex Quota Widget · 额度森林可编辑推广素材

使用应用 v1.4.0 的实际渲染画面制作。所有额度数字均为示例，画面保留“状态演示”标识，不包含用户真实日志。中文文案和图层可在 Remotion Studio 编辑。

## 重建

在仓库根目录运行：

```sh
./Scripts/build-app.sh
python3 Scripts/render-promo-assets.py
cd promo
npm ci
npm run dev -- --no-open
```

## 输出

```sh
npx remotion still SocialPreview ../docs/screenshots/quota-grove-social-preview.png
npx remotion render QuotaGrovePromo out/quota-grove-promo.mp4 --codec=h264 --crf=18 --muted
```

- QuotaGrovePromo：1920 × 1080，30 fps，600 帧，20 秒，无声。
- QuotaGroveDemo：前 6 秒额度状态演示，可用于制作 README GIF。
- SocialPreview：1280 × 640 分享封面。

## 分镜与来源

| 时间 | 内容 | 来源 |
| --- | --- | --- |
| 0–6 秒 | 森林、秋天、末日、废土 | `public/cards/85.png` 等；应用 `--render-preview` |
| 6–11 秒 | 收起、展开、贴边 | `expanded.png`、`stashed.png`；同一应用渲染器 |
| 11–16 秒 | macOS 五套背景 | 各背景套系的实际渲染截图 |
| 16–20 秒 | 下载入口与使用价值 | 可编辑文字、森林卡片 |

所有关键元素使用独立图层。位移采用对称缓入缓出，每段最后保持静止。无额外音乐或音轨。`out/`、依赖与浏览器缓存不会提交到仓库。
