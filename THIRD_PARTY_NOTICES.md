# Third-party notices

Quota Grove 的 macOS 版仅使用 Apple 系统框架：AppKit、Foundation、Core Animation、Core Location。Windows 版使用 Microsoft .NET 8 与 WPF，并以自包含形式分发；Windows ZIP 同时附带 Microsoft .NET 的许可证与第三方声明文件。

Quota Grove 应用图标和全部应用代码为本项目独立创建；“额度森林”四张主题背景由产品负责人提供，并依据 PRD 确认拥有使用和分发权利。“星屿生态舱”“云海灯塔”“月光花房”“深海幻境”“时间铸境”主题背景与落叶粒子图集使用 OpenAI ImageGen 为本项目专门生成，再经本地适配或运行时后处理，不包含第三方品牌标识；星屿粒子、灯塔飞鸟、月蝶、水母与星轮机械体由应用代码实时绘制。项目没有复制同类项目的代码、文件结构、脚本或 README。

## OpenAI Codex 来源标识

- 文件：`Assets/CodexIcon.png`
- 来源：官方 Codex/ChatGPT 桌面应用内置的 `icon-codex-light.png`。
- 用途：仅在“7 天额度”标题旁标识额度数据来源，不作为 Quota Grove 的应用图标、品牌标志或仓库头像。
- 权属：该图标及相关商标权利归 OpenAI 或其相关权利人所有。
- 许可边界：该文件不适用本仓库的许可证授权；本项目不主张其所有权或再许可权。收录该标识不表示 OpenAI 对本项目的授权、合作、认可或背书。

除上述来源标识、Windows 自包含包中的 Microsoft .NET 运行时，以及用户可选启用的 Open-Meteo 天气查询外，本项目不捆绑其他第三方库、字体、图标包或遥测 SDK。

## Open-Meteo 天气数据

- 服务：[Open-Meteo](https://open-meteo.com/)。
- 用途：仅在用户主动开启“跟随当地天气”后，使用模糊化到两位小数的经纬度查询当前天气代码、降雨量、阵雨量和降雪量，以控制雨效或雪效是否显示。
- 数据许可：CC BY 4.0；使用时保留 Open-Meteo 署名。
- 服务条款：免费 API 限非商业用途并受调用频率限制；商业分发需要使用符合 Open-Meteo 商业条款的方案。
- 隐私边界：额度、Codex 日志、对话或账号信息不会发送给 Open-Meteo。

“OpenAI”“Codex”“ChatGPT”是其各自权利人的名称或商标。本工具为非官方独立工具，与 OpenAI 无隶属或背书关系。
