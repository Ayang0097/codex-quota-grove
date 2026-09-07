# 素材与视觉来源

## Quota Grove 应用图标

- 文件：`Assets/QuotaGroveIcon.svg`
- 来源：本项目独立绘制的 SVG。
- 构成：未闭合的额度环构成字母 `Q`，尾部自然延伸为一片带叶脉的叶子；深绿色玻璃底座使用项目自有配色。
- 字体：无。

## Codex 额度来源标识

- 文件：`Assets/CodexIcon.png`
- 来源：本机安装的官方 Codex/ChatGPT 桌面应用资源 `icon-codex-light.png`。
- 原始规格：1024 × 1024 px，透明背景、圆角底座。
- 使用位置：仅显示在卡片“7 天额度”标题旁，用于说明额度数据来自本机 Codex/ChatGPT 客户端。
- 不用于：Quota Grove 应用图标、仓库头像、产品 Logo、宣传主视觉或暗示官方合作与背书。
- 权属：该图标以及 OpenAI、Codex、ChatGPT 相关名称和商标的权利归其各自权利人所有；本项目不主张所有权，也不通过仓库许可证对其进行再许可。

## 卡片主题

- 正式背景：产品负责人提供的 `bg/*.png`，源尺寸均为 1983 × 793 px，与收起卡片保持约 2.5:1 比例。依据 PRD，这些素材由产品负责人确认拥有使用和分发权利。
- 森林：`bg/背景百分之50以上.png`
- 秋天：`bg/背景百分之50以下.png`
- 末日：`bg/背景百分之20以下.png`
- 废土：`bg/背景百分之3以下.png`
- 回退背景：`QuotaCardView.swift` 中独立绘制的 Core Graphics/AppKit 路径和渐变，仅在正式图片缺失时使用。

## 星屿生态舱背景套系

- 文件：`Assets/BackgroundSets/AstralTerrarium/forest.png`、`autumn.png`、`apocalypse.png`、`wasteland.png`。
- 来源：使用 OpenAI ImageGen 为 Quota Grove 专门生成的四张原创位图；原始输出均为 1983 × 793 px，与卡片保持约 2.5:1 比例。
- 统一视觉：同一座玻璃罩微缩生态岛，保留左上和右上暗部信息区，不包含文字、Logo 或第三方品牌标识。
- 阶段变化：森林为青绿发光生态舱，秋林为铜金衰退生态舱，末日为红紫裂变生态舱，废土为银灰冻结生态舱。
- 配套动效：上升孢子、金色星尘、逆风火屑和六向霜晶均由 `AstralParticleSystem.swift` 与 `QuotaCardView.swift` 实时绘制，不使用第三方粒子素材包。

## 云海灯塔背景套系

- 文件：`Assets/BackgroundSets/CloudseaBeacon/forest.png`、`autumn.png`、`apocalypse.png`、`wasteland.png`。
- 来源：使用 OpenAI ImageGen 为 Quota Grove 专门生成的四张原创位图；原始输出均为 1983 × 793 px，与卡片保持约 2.5:1 比例。
- 统一视觉：同一座装饰艺术风格灯塔与悬浮石岛，保留左右上方暗部信息区，不包含文字、Logo 或第三方品牌标识。
- 阶段变化：森林为蓝色云海与青色信标，秋林为铜金黄昏，末日为红紫雷暴，废土为银白冻结云层。
- 配套动效：青蓝、金色、暗红和灰白四种飞鸟轮廓、扇翼状态、队形与飞行轨迹均由 `BeaconParticleSystem.swift` 与 `QuotaCardView.swift` 实时绘制，不使用第三方鸟类图片或动画素材。

## 月光花房背景套系

- 文件：`Assets/BackgroundSets/MoonlitConservatory/forest.png`、`autumn.png`、`apocalypse.png`、`wasteland.png`。
- 来源：使用 OpenAI ImageGen 为 Quota Grove 专门生成的四张原创位图；原始输出均为 1983 × 793 px，与卡片保持约 2.5:1 比例。
- 统一视觉：同一座新艺术风格月夜玻璃花房，保留左右上方暗部信息区和底部进度条区域，不包含文字、Logo、人物或第三方品牌标识。
- 阶段变化：森林为珍珠薰衣草与雾粉花朵，秋林为暗铜和玫瑰金暮色，末日为石榴红藤蔓与蚀月，废土为银灰冰晶与冻结玻璃。
- 配套动效：珍珠浅粉、玫瑰金、石榴红和银白四种月蝶的轮廓、扇翼状态、景深与曲线轨迹均由 `MoonButterflySystem.swift` 与 `QuotaCardView.swift` 实时绘制，不使用第三方蝴蝶图片或动画素材。

## 深海幻境背景套系

- 文件：`Assets/BackgroundSets/AbyssalReverie/forest.png`、`autumn.png`、`apocalypse.png`、`wasteland.png`。
- 来源：使用 OpenAI ImageGen 为 Quota Grove 专门生成并定向编辑的四张原创位图；原始输出均为 1983 × 793 px，与卡片保持约 2.5:1 比例。
- 统一视觉：同一片无边框深海珊瑚海床和同一组水母构图，完整铺满画面，保留左右上方暗部信息区和底部进度条区域，不包含文字、Logo、人物或第三方品牌标识。
- 阶段变化：森林为青蓝生物荧光珊瑚，秋林为铜金衰退海域，末日为石榴红暗海沟，废土为银灰白化珊瑚与冷色海雪。
- 配套动效：青蓝、琥珀、石榴红和银白四种水母的伞体脉动、触手摆动、漂浮轨迹、景深和淡出均由 `AbyssalJellyfishSystem.swift` 与 `QuotaCardView.swift` 实时绘制，不使用第三方水母图片或动画素材。

## 时间铸境背景套系

- 文件：`Assets/BackgroundSets/Chronoforge/forest.png`、`autumn.png`、`apocalypse.png`、`wasteland.png`。
- 来源：使用内置 OpenAI ImageGen 为 Quota Grove 专门生成并以首张构图为母版定向编辑的四张原创位图；原始输出均为 1935 × 813 px，适配卡片约 2.5:1 的宽幅裁切。
- 统一视觉：同一座黑曜石、珐琅、黄铜与透明齿轮构成的超现实时间铸造城，主星仪集中在右侧，左侧和底部保留信息暗区；不包含文字、Logo、人物或第三方品牌标识。
- 阶段变化：森林为铜绿与钴蓝同步机械，秋林为老化黄铜和琥珀时间流，末日为黑钢与朱砂时间裂隙，废土为银灰、骨白瓷与冻结玻璃；废土阶段不含红色边缘提示。
- 配套动效：铜绿、黄铜、朱砂和银白四种星轮机械体的轨道、刻度、双指针、卫星、自转和曲线漂移均由 `ChronoforgeOrbitSystem.swift` 与 `QuotaCardView.swift` 实时绘制，不使用第三方机械或粒子素材。

## 落叶粒子

- 文件：`Assets/Leaves/forest-*.png`、`autumn-*.png`、`apocalypse-*.png`、`wasteland-*.png`。
- 来源：使用 OpenAI ImageGen 为 Quota Grove 专门生成的透明叶片图集，再在本地分割为运行时素材。
- 后处理：应用运行时根据森林、秋林、末日和废土主题调色，并使用 Core Image 生成景深虚化；方向模糊和飘落轨迹由应用代码实时绘制。
- 权利边界：素材不包含第三方品牌标识，不是从现有素材包、图库或同类项目复制。

除上述 Codex 额度来源标识外，项目未捆绑其他第三方品牌图标。

## README 展示图与动图

- 文件：`docs/screenshots/quota-grove-themes-en-v101.png`、`docs/screenshots/quota-grove-modes-en-v101.png`、`docs/screenshots/quota-grove-leaf-animation.gif`、`docs/screenshots/quota-grove-weather-rain-v130.gif`、`docs/screenshots/quota-grove-weather-snow-v130.gif`、`docs/screenshots/quota-grove-astral-terrarium-themes.png`、`docs/screenshots/quota-grove-astral-terrarium-modes.png`、`docs/screenshots/quota-grove-astral-terrarium-animation.gif`、`docs/screenshots/quota-grove-cloudsea-beacon-themes.png`、`docs/screenshots/quota-grove-cloudsea-beacon-modes.png`、`docs/screenshots/quota-grove-cloudsea-beacon-animation.gif`、`docs/screenshots/quota-grove-moonlit-conservatory-themes.png`、`docs/screenshots/quota-grove-moonlit-conservatory-modes.png`、`docs/screenshots/quota-grove-moonlit-conservatory-animation.gif`、`docs/screenshots/quota-grove-abyssal-reverie-themes.png`、`docs/screenshots/quota-grove-abyssal-reverie-modes.png`、`docs/screenshots/quota-grove-abyssal-reverie-animation.gif`、`docs/screenshots/quota-grove-chronoforge-themes.png`、`docs/screenshots/quota-grove-chronoforge-modes.png`、`docs/screenshots/quota-grove-chronoforge-animation.gif`。
- 来源：PNG 由 `Scripts/render-readme-showcase.swift` 调用应用内置的真实预览渲染器生成，再使用 Apple AppKit 合成；GIF 由应用的落叶、雨雪和主题粒子逐帧渲染能力输出，再编码为动图。
- 内容：展示六套背景套系的额度阶段，以及收起、展开、贴边隐藏、主题同步落叶、星屿粒子、灯塔飞鸟、月蝶、水母与星轮机械体动效。
- 字体：仅使用 macOS 系统字体，不额外捆绑字体文件。
