# DeepSeek Harness deployment

This private repository stores the local deployment wrapper for DeepSeek Harness. It does not contain personal profiles, API keys, session data, or `node_modules`.

## Deploy on another Windows computer

1. Clone this repository or extract its ZIP archive into any folder.
2. Double-click `install.cmd`.
3. If Node.js or Corepack is missing, follow the prompt to install the missing environment.
4. Open Start Menu and launch `DeepSeek Harness`.

The installer uses paths relative to its own directory, installs the locked dependencies, and creates or replaces the Start Menu shortcut. The first installation needs an internet connection for Node.js/Corepack or package downloads. Node.js 20 or newer and Windows PowerShell are required.

The launcher opens a command window, reports whether the service is enabled and shows the port. When the service is ready, it opens the browser at `http://127.0.0.1:18080`.

The shortcut uses the official black whale favicon from the upstream Harness web app: https://github.com/deepseek-ai/deepseek-harness/blob/master/apps/web/public/favicon.svg

## Update later

Run `powershell -ExecutionPolicy Bypass -File .\update.ps1` to pull the latest repository files and reinstall the locked dependencies.

To upgrade the DeepSeek Harness release, replace `dsh-0.1.0-rc.7.tgz`, update the version in `package.json`, regenerate `pnpm-lock.yaml`, test locally, commit, and push.

## Original project

https://github.com/deepseek-ai/deepseek-harness
