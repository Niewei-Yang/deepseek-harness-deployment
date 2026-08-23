# DeepSeek Harness deployment

This private repository stores the local deployment wrapper for DeepSeek Harness. It does not contain personal profiles, API keys, session data, or `node_modules`.

## Deploy on another Windows computer

1. Install Node.js 20 or newer.
2. Clone this repository.
3. Run `powershell -ExecutionPolicy Bypass -File .\install.ps1`.
4. Run `start-deepseek-harness.cmd`.

The launcher opens a command window, reports whether the service is enabled and shows the port. When the service is ready, it opens the browser at `http://127.0.0.1:18080`.

## Update later

Run `powershell -ExecutionPolicy Bypass -File .\update.ps1` to pull the latest repository files and reinstall the locked dependencies.

To upgrade the DeepSeek Harness release, replace `dsh-0.1.0-rc.7.tgz`, update the version in `package.json`, regenerate `pnpm-lock.yaml`, test locally, commit, and push.

## Original project

https://github.com/deepseek-ai/deepseek-harness
