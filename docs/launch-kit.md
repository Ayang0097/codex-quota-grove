# Codex Quota Widget · 额度森林 v1.4.0 发布素材与推广计划

文案草稿，可按各平台语气调整后发布。演示里的额度是示例值；视频由应用真实渲染的界面组成，不是实时额度消耗录像。

## 素材

- 分享封面：[1280 × 640 PNG](screenshots/quota-grove-social-preview.png)。
- README 动图：[6 秒 GIF](screenshots/quota-grove-demo.gif)。
- 完整演示：[20 秒 MP4](https://github.com/Ayang0097/codex-quota-grove/releases/download/v1.4.0/Quota-Grove-v1.4.0-demo.mp4)。
- 可编辑视频工程：[promo](../promo/README.md)。
- 项目地址：https://github.com/Ayang0097/codex-quota-grove
- 下载入口：https://github.com/Ayang0097/codex-quota-grove/releases/latest

## V2EX「分享创造」草稿

标题：Codex Quota Widget：我把剩余额度做成了一片会枯萎的森林

我做了一个桌面小工具 Quota Grove（额度森林），把本机 Codex 的 7 天剩余额度与重置时间放到一个悬浮卡片里。

额度充足时是森林，下降后会变成秋天、末日和废土。单击查看详情，拖到屏幕边缘会收起来，悬停再展开。

它每 10 秒读取本机额度记录，不需要 API Key，也不消耗模型 Token。支持 macOS Apple Silicon 和 Windows x64；macOS 额外提供五套背景和可选天气效果。

下载：https://github.com/Ayang0097/codex-quota-grove/releases/latest

目前仍有边界：依赖本机 Codex 日志，可能暂时拿不到新数据；macOS 未做 Apple 公证，Windows 也没有商业签名，首次打开可能遇到系统提示。仓库首页有安装说明。

想听听实际使用 Codex 的朋友的反馈：你更在意一眼看到剩余额度，还是重置时间？第一次安装卡在哪一步？

这是独立的非官方工具。代码使用仓库现有的保留权利许可。

## 中文短视频 / 图文草稿

标题：当 Codex 额度快用完，我桌面上的森林也枯了

Codex 还剩多少周额度？什么时候重置？

我把这两个信息做成了桌面上的一片森林：额度充足时郁郁葱葱，越用越少，就从秋天走向废土。

这个小工具叫“额度森林”。可以常驻桌面，也能贴边隐藏。Mac 和 Windows 都能用；读取额度不调用模型，不消耗 Token。

项目与安装说明：github.com/Ayang0097/codex-quota-grove

你希望它再显示什么信息？

配图或视频：附带本次演示。保持“状态演示”标记；主题套系画面注明 macOS。

## X 英文草稿

I made Codex Quota Widget · Quota Grove: your Codex quota, as a forest that fades.

See your remaining weekly quota and reset time on your desktop. Stash it at the screen edge. No API key or model calls for quota polling.

macOS + Windows. Independent, unofficial tool.

https://github.com/Ayang0097/codex-quota-grove

建议配 20 秒视频；若字数受账号限制，保留第一句、平台与项目链接。

## 邀请试用的短消息

我做了一个把 Codex 周额度显示成森林的桌面小工具，支持 Mac 和 Windows。你平时用 Codex 吗？如果方便，想请你试一下，告诉我能否顺利打开、额度是否显示、第二天还会不会留着用。

安装说明：https://github.com/Ayang0097/codex-quota-grove

## 第一周执行顺序

| 时间 | 行动 | 记录 |
| --- | --- | --- |
| 第 1 天 | 分享给能直接触达的 Codex 用户，目标邀请 10 位 | 邀请数、安装成功数、具体卡点 |
| 第 2–3 天 | 修复确认过的安装或显示问题，回复反馈 | 是否复现、解决版本、第二天是否继续使用 |
| 第 3–4 天 | 发布一篇 V2EX 分享创造帖，附演示与安装入口 | 发帖时间、浏览、评论和下载增量 |
| 第 5–6 天 | 在自己的内容账号发短视频；有英文受众再发 X | 各渠道内容浏览与可用的链接点击 |
| 第 7 天 | 汇总反馈，决定保留哪个渠道与下一项改进 | 至少 3 条具体反馈；不把目标当作增长保证 |

不要从不同时间窗口的总数计算转化率。GitHub 访客不是全渠道曝光数，Release 下载次数也不是独立安装人数。克隆可能来自自动化，不能当活跃用户数。

GitHub Traffic 只提供最近 14 天窗口。可手动运行 `python3 Scripts/snapshot-github-metrics.py` 保存带时间戳的本地快照；首发前后分别记录，验证下载会增加自己的测试下载次数。此脚本不会创建自动任务。

## 来源与适用边界

- [V2EX 分享创造](https://v2ex.com/go/create)：允许展示自己的作品。
- [GitHub Traffic](https://docs.github.com/en/repositories/viewing-activity-and-data-for-your-repository/viewing-traffic-to-a-repository)：流量窗口与统计口径。
- [GitHub 分享封面](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/customizing-your-repositorys-social-media-preview)：推荐 1280 × 640、文件小于 1 MB。

以上素材未代表你向社区或私人联系人发送消息。
