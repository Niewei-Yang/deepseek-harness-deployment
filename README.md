# DeepSeek Harness 部署

本仓库保存 DeepSeek Harness 的 Windows 部署封装。它不包含个人配置、API 密钥、会话数据或 `node_modules`。

## 部署快照（2026-09-17）

- CLI：`@deepseek-ai/dsh` **0.1.5-rc.1**，从 npm 安装。
- 包管理器：**pnpm 8.9.0**，版本固定在 `package.json` 中。
- 完整的依赖版本记录在 `pnpm-lock.yaml`；部分 Harness 包解析为 `0.1.5-rc.2`。
- 已在 Windows + **Node.js 24.14.1** 上完成本地验证。当前 lockfile 包含需要 Node.js **22.19.0 或更高版本**的依赖。
- Web 配置绑定到 `127.0.0.1:18080`，并启用令牌（token）认证。

## 在另一台 Windows 电脑上部署

1. 克隆本仓库，或将其 ZIP 压缩包解压到任意文件夹。
2. 双击 `install.cmd`。
3. 如果缺少 Node.js 或 Corepack，请按提示安装缺失的环境。
4. 打开开始菜单，启动 `DeepSeek Harness`。

安装程序使用相对于自身所在目录的路径，安装锁定版本的依赖，并创建或替换开始菜单快捷方式。首次安装需要联网，用于获取 Node.js/Corepack 或下载依赖包。需要 Node.js 22.19.0 或更高版本以及 Windows PowerShell；Node.js 24.14.1 是本地验证过的运行时。请使用 Corepack 选择固定的 pnpm 版本，或自行安装 pnpm 8.9.0。

启动器会打开一个命令窗口，报告服务是否已启用并显示端口。需要时，它会在后台启动服务。服务就绪后，它会从 `dsh-service.stdout.log` 读取带令牌的 URL，校验后使用浏览器打开。直接访问 `http://127.0.0.1:18080` 可能返回 HTTP 401；请使用启动器显示的完整 URL，其中包含 `?token=...`。

服务输出保存在启动器同目录下的 `dsh-service.stdout.log` 和 `dsh-service.stderr.log` 中。输出日志包含访问令牌：请仅保留在本地。日志、依赖备份、临时工作文件、`.env` 文件以及本地 `.dsh` 数据均被 Git 忽略。请在每台电脑上自行配置模型凭据和配置；本仓库不会迁移这些内容。

快捷方式使用上游 Harness Web 应用中的官方黑色鲸鱼图标：https://github.com/deepseek-ai/deepseek-harness/blob/master/apps/web/public/favicon.svg

## 后续更新

运行 `powershell -ExecutionPolicy Bypass -File .\update.ps1` 以拉取仓库的最新文件并重新安装锁定版本的依赖。

如需升级 DeepSeek Harness 版本，请修改 `package.json` 中的确切 npm 版本号，运行 `corepack pnpm install` 重新生成 `pnpm-lock.yaml`，在本地测试后提交并推送。常规部署使用 `--frozen-lockfile`，不会解析新的依赖版本。

旧的 `dsh-0.1.0-rc.7.tgz` 作为历史产物保留；当前部署已不再使用它。

## 故障排查

- 如果启动失败，请在本地检查 `dsh-service.stderr.log`，并确认端口 18080 未被占用。
- 如果正在运行的服务返回 401，且其令牌日志缺失或已过期，请停止该 Harness 进程，并使用本封装脚本重新启动，以生成新的日志。
- 更新依赖后，请重启现有的 Harness 进程以加载更新后的版本。`update.ps1` 不会自动重启它。

## 原项目

https://github.com/deepseek-ai/deepseek-harness
