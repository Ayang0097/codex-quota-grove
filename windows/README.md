# Codex Quota Widget · Quota Grove for Windows

Windows 版使用 .NET 8 WPF 实现，与 macOS 版共享额度解析规则、主题边界和本地数据原则。

## 支持范围

- Windows 10/11 x64。
- 根据 Windows 显示语言自动使用中文或英文；中文系统显示中文，其他系统默认显示英文。
- 收起卡片 `400 × 160 DIP`，单击展开为 `400 × 356 DIP`。
- 双击刷新、拖动定位、左右屏幕边缘收纳、悬停滑出。
- 右键刷新、管理登录启动、重置位置、查看隐私说明和退出。
- 自动读取 `%USERPROFILE%\.codex\sessions` 下的本机额度事件。
- 可通过 `QUOTA_GROVE_CODEX_HOME` 或 `CODEX_HOME` 指定其他 Codex 数据目录。
- 无网络上传、无遥测，不读取账号凭据。

## 从源码测试

需要 .NET 8 SDK：

```powershell
dotnet run --project windows/QuotaGrove.SelfTest/QuotaGrove.SelfTest.csproj --configuration Release
dotnet build windows/QuotaGrove.Windows/QuotaGrove.Windows.csproj --configuration Release --runtime win-x64
```

## 生成便携版本

```powershell
dotnet publish windows/QuotaGrove.Windows/QuotaGrove.Windows.csproj `
  --configuration Release `
  --runtime win-x64 `
  --self-contained true `
  --output dist/windows-x64 `
  -p:PublishSingleFile=true `
  -p:IncludeNativeLibrariesForSelfExtract=true `
  -p:DebugType=None `
  -p:DebugSymbols=false
```

生成的 `QuotaGrove.exe` 是自包含版本，不要求用户预先安装 .NET。当前公开构建未购买 Windows 代码签名证书，首次运行可能出现 Microsoft Defender SmartScreen 提示。

Windows 自动构建会同时运行 30 项自检（包含大日志额度防回退检查）、启动可执行文件，并渲染中英文收起态、英文展开态和 1% 废土预览图作为验收证据。
