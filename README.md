# DeepSeek Harness deployment

This repository stores the Windows deployment wrapper for DeepSeek Harness. It does not contain personal profiles, API keys, session data, or `node_modules`.

## Deployment snapshot (2026-09-17)

- CLI: `@deepseek-ai/dsh` **0.1.5-rc.1**, installed from npm.
- Package manager: **pnpm 8.9.0**, pinned in `package.json`.
- Full dependency versions are recorded in `pnpm-lock.yaml`; some Harness packages resolve to `0.1.5-rc.2`.
- Verified locally with **Node.js 24.14.1** on Windows. The current lockfile includes dependencies requiring Node.js **22.19.0 or newer**.
- Web profile, bound to `127.0.0.1:18080`, with token authentication.

## Deploy on another Windows computer

1. Clone this repository or extract its ZIP archive into any folder.
2. Double-click `install.cmd`.
3. If Node.js or Corepack is missing, follow the prompt to install the missing environment.
4. Open Start Menu and launch `DeepSeek Harness`.

The installer uses paths relative to its own directory, installs the locked dependencies, and creates or replaces the Start Menu shortcut. The first installation needs an internet connection for Node.js/Corepack or package downloads. Node.js 22.19.0 or newer and Windows PowerShell are required; Node.js 24.14.1 is the locally verified runtime. Use Corepack to select the pinned pnpm version, or install pnpm 8.9.0 yourself.

The launcher opens a command window, reports whether the service is enabled and shows the port. When needed, it starts the service in the background. Once ready, it reads the token URL from `dsh-service.stdout.log`, verifies it, and opens it in the browser. A bare request to `http://127.0.0.1:18080` may return HTTP 401; use the complete URL shown by the launcher, including `?token=...`.

Service output is stored in `dsh-service.stdout.log` and `dsh-service.stderr.log` beside the launcher. The output log contains the access token: keep it local. Logs, dependency backups, temporary work files, `.env` files, and local `.dsh` data are ignored by Git. Configure your own model credentials and profiles on each computer; these are not migrated by this repository.

The shortcut uses the official black whale favicon from the upstream Harness web app: https://github.com/deepseek-ai/deepseek-harness/blob/master/apps/web/public/favicon.svg

## Update later

Run `powershell -ExecutionPolicy Bypass -File .\update.ps1` to pull the latest repository files and reinstall the locked dependencies.

To upgrade the DeepSeek Harness release, update the exact npm version in `package.json`, run `corepack pnpm install` to regenerate `pnpm-lock.yaml`, test locally, commit, and push. Normal deployments use `--frozen-lockfile` and do not resolve new dependency versions.

The old `dsh-0.1.0-rc.7.tgz` is retained as a historical artifact; it is no longer used by the current deployment.

## Troubleshooting

- If startup fails, inspect `dsh-service.stderr.log` locally and confirm that port 18080 is free.
- If a running service returns 401 and its token log is missing or stale, stop that Harness process and relaunch using this wrapper to generate a fresh log.
- After updating dependencies, restart the existing Harness process to load the updated release. `update.ps1` does not restart it automatically.

## Original project

https://github.com/deepseek-ai/deepseek-harness
