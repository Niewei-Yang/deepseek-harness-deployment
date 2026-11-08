# DeepSeek Harness 一键部署（Windows）

把本仓库下载到另一台 Windows 电脑后，双击 `install.cmd`，按提示完成环境安装，即可从开始菜单打开 DeepSeek Harness。**下载 ZIP 即可，无须安装 Git，也无须复制本机的 node_modules。**

## 在另一台电脑上一键部署

1. 打开[本仓库](https://github.com/Niewei-Yang/deepseek-harness-deployment)，点击 **Code → Download ZIP**，或[直接下载 main 分支 ZIP](https://github.com/Niewei-Yang/deepseek-harness-deployment/archive/refs/heads/main.zip)。
2. **先完整解压**到准备长期保留的文件夹，例如 `D:\Apps\deepseek-harness`。不要在 ZIP 内直接运行安装程序。
3. 打开解压后的文件夹，双击 **install.cmd**。
4. 安装器会检查 Node.js 和 Corepack。缺少或版本不符时，按提示输入 **Y**：
   - Node.js 通过 winget 安装或升级；
   - Corepack 通过 npm 安装或修复；
   - 首次下载工具时，按屏幕提示操作；如系统要求提升安装权限，请确认。
5. 看到 **Installation complete / Installation finished successfully** 后，关闭安装窗口。
6. 在开始菜单搜索并打开 **DeepSeek Harness**。
7. 首次使用时，按网页提示配置自己的模型 API Key 和工作目录。

安装成功后会有两个开始菜单入口：

| 入口 | 用途 |
| --- | --- |
| DeepSeek Harness | 启动后台服务并打开网页；同时检查更新 |
| DeepSeek Harness Update | 检查并安装 npm 默认发布渠道的新版，升级前自动备份 |

这里的“一键”指从 `install.cmd` 启动安装流程；首次安装仍可能需要确认环境安装、系统权限，并自行填写模型 API Key。首次安装需要能访问 npm 的网络。

### 没有 winget 或自动安装失败时

先从 [Node.js 官网](https://nodejs.org/)安装 **Node.js 24.9 或更高版本**，然后关闭原安装窗口，再双击 `install.cmd`。如仍提示缺少 Corepack，可在终端执行：

```powershell
npm install --global corepack@latest
```

如命令提示权限不足，请用管理员终端安装该工具。完成后重新运行 `install.cmd`。安装器通过 `corepack pnpm@11.28.5` 调用仓库固定版本，无须另行运行 `corepack enable`，也不会使用电脑上任意版本的全局 pnpm。

安装时若网络断开，恢复连接后可以再次双击 `install.cmd`。

## 当前固定的部署版本

| 项目 | 版本或设置 |
| --- | --- |
| Harness CLI | `@deepseek-ai/dsh@0.2.1-rc.5` |
| pnpm | `11.28.5`，由 package.json 固定 |
| Node.js | 最低 `24.9.0`；本机验证版本 `24.14.1` |
| 依赖 | 由 pnpm-lock.yaml 锁定，安装使用 --frozen-lockfile |
| 网页地址 | `127.0.0.1:18080`，仅监听本机，启用令牌认证 |

仓库固定的是当前已验证的部署版本，首次安装不会自动改为 npm 的最新版本。安装后可使用更新入口升级。

## 日常启动和检测更新

打开开始菜单中的 **DeepSeek Harness**。需要时，启动器会在后台启动服务，等待访问令牌写入日志，并验证网页可访问后再打开浏览器。正常启动后可以关闭命令行窗口；后台服务会继续运行，关闭浏览器也不会停止后台服务。

启动时自动检查 npm 的 **latest** 渠道：

- 成功检查的结果缓存 24 小时；
- 有新版时在启动窗口显示提示和更新命令；
- 网络失败不影响启动，失败后自动检查间隔一小时；主动检查可以立即重试；
- 普通启动只检查、提示，不自动安装；不选择 alpha 渠道。

如果安装目录中已有一套通过更新器切换过的依赖，安装器会使用该依赖目录并校验实际 CLI 版本。

## 安装新版与备份

打开开始菜单的 **DeepSeek Harness Update**，或者双击安装目录里的 `update.cmd`。

更新器先在独立目录下载依赖并校验 CLI 版本，再备份、切换程序文件。如果本部署正在监听 18080 端口，会在备份和切换时停止它，完成后重新启动；其他程序占用该端口时会报错退出。下载或预检失败不会替换现有程序；切换失败会尝试恢复旧程序文件。

备份位于安装目录的 `work/upgrade-backup-<时间戳>/`，其中包括部署文件和用户数据副本。复制用户数据时不遍历目录联接。备份包含密钥、聊天记录或带访问令牌的日志，请保留在本地。

需要时，也可在安装目录打开 PowerShell：

```powershell
# 只检查更新，不安装
powershell -NoProfile -ExecutionPolicy Bypass -File .\update.ps1 -CheckOnly

# 安装 npm latest 渠道的版本
powershell -NoProfile -ExecutionPolicy Bypass -File .\update.ps1

# 明确指定一个发布版本
powershell -NoProfile -ExecutionPolicy Bypass -File .\update.ps1 -Version 0.2.1-rc.5
```

Harness 更新与部署脚本同步是两件事：更新器负责升级 npm 程序，不会执行 Git pull、提交或推送。它修改的本地 package.json 和 lockfile 也不会自动上传到 GitHub。仓库中的新启动器或安装脚本修复，需要另外同步仓库文件。

## 换电脑时，哪些内容会带过去

本仓库包含安装脚本、启动器、更新器、版本清单、lockfile 和图标。**API Key、聊天记录、个人配置不会随 GitHub 下载迁移。**

默认用户数据位于 `%USERPROFILE%\.dsh`；如设置了 `DSH_HOME`，以该路径为准。另一台电脑可直接重新配置模型凭据；如果需要完整迁移原有数据，应在停止相关 Harness 进程后单独备份、传输和恢复用户目录。

不要直接打包本机的 node_modules 拿到另一台电脑使用。Windows 下 pnpm 会创建包含绝对路径的目录联接，换电脑后应使用安装器重新生成依赖和快捷方式。

**安装或升级后不要移动安装目录，也不要删除整个 work 目录。** 更新器会让 node_modules 联接到 `work/update-stage-<时间戳>/node_modules`，当前正在使用的版本目录必须保留。备份中的旧依赖也可能需要恢复到原路径后才能使用。

## 启动故障排查

- **刚启动时日志为空**：启动器会重试，最多等待约 90 秒；不会把端口已监听或 HTTP 401 当作网页已可用。
- **服务提前退出**：窗口会显示简短错误，并指出日志路径。
- **网页返回 401**：通过开始菜单启动器打开带 `?token=...` 的完整地址。直接访问裸地址可能返回 401。
- **端口 18080 被其他程序占用**：先确认并解决端口冲突，再重新启动。
- **更新检查超时**：可以继续使用 Harness；网络恢复后通过更新入口或 `-CheckOnly` 主动检查。

服务日志在安装目录的 `dsh-service.stdout.log` 和 `dsh-service.stderr.log`。输出日志包含网页访问令牌，请勿公开上传。

跨版本升级可能影响个人插件或配置。更新器的 CLI 预检不代表所有模型和第三方插件都兼容，也不会在新版启动后自动回滚用户数据。需要回退时，应先停止服务，再恢复对应的程序和必要的用户数据备份。

## 验证范围

已在 Windows x64、Node.js 24.14.1 上验证安装后的 CLI 版本和认证网页访问；另有空日志、延迟令牌、重复启动、服务提前退出、更新缓存及断网重试的回归检查。新目录安装检查使用已有 Node.js/Corepack 环境，不等同于全新 Windows 系统的完整测试；其他操作系统和架构未验证。

## 上游项目

[DeepSeek Harness 官方仓库](https://github.com/deepseek-ai/deepseek-harness)

仓库中的 `dsh-0.1.0-rc.7.tgz` 是历史文件，当前安装和升级流程均不使用它。
