# Claude Code Rate Limit Statusline ⚡

A lightweight, zero-cost, and 100% accurate rate limit statusline for **Claude Code** (Pro / Max tiers).

## 💡 Why This Project?

Claude Code's official `/statusline` API does not expose concrete Rate Limit data. Polling the official Usage API frequently via scripts will easily trigger `429 Too Many Requests` blocks.

**The solution:**
By running a minimal local Node.js reverse proxy, we intercept and parse the `anthropic-ratelimit-unified-*` headers returned by the Anthropic API during normal conversations, then convert them into a format that the native Statusline can read.

## ✨ Features

* **🚫 No 429 blocks** — sends zero extra requests; relies entirely on intercepting existing traffic.
* **🎯 100% official data** — reads server-side Unified Rate Limit directly, no local estimation.
* **🌈 Visual statusline** — dynamic color coding shows remaining 5h and 7d quota percentages and reset times (yellow above 50%, red above 80% consumed).
* **👻 Silent background process** — all output redirected to `/dev/null`, no log files on disk.
* **🐧 Dual-platform** — automatically compatible with macOS and Ubuntu/Linux.

## 🚀 Quick Start

Run the following command in your terminal to download and execute the one-click setup script. The script will automatically check for required tools (e.g., `jq`) and start the proxy server in the background.

```bash
chmod +x setup_claude_status.sh
./setup_claude_status.sh
```

## 🛠️ Usage

After installation, simply point Claude Code at the local proxy.

### 1. Set the environment variable

Set `ANTHROPIC_BASE_URL` before launching Claude Code. Add this line to your shell profile to make it permanent:

```bash
# zsh users
echo 'export ANTHROPIC_BASE_URL="http://localhost:8080"' >> ~/.zshrc

# bash users
echo 'export ANTHROPIC_BASE_URL="http://localhost:8080"' >> ~/.bashrc
```

> The setup script will print the exact one-liner for your shell at the end — just copy and paste it.

### 2. Launch Claude Code

```bash
claude
```

### 3. Bind the statusline

Inside the Claude interface, run the following command to bind the generated script:

```bash
/statusline ~/.claude/statusline-command.sh
```

🎉 Send any message to Claude and your statusline will light up immediately!

## 🛑 Stop the Proxy

To temporarily stop the background proxy server:

```bash
kill $(cat /tmp/claude_proxy.pid) && rm -f /tmp/claude_proxy.pid
```

Or search by name:

```bash
pkill -f "node claude-proxy.js"
```

## 📁 File Reference

| File | Description |
|------|-------------|
| `claude-proxy.js` | Node.js reverse proxy — forwards requests to `api.anthropic.com`, captures Rate Limit headers, and writes them to `/tmp/claude_rate_limit.json` |
| `setup_claude_status.sh` | One-click setup script — installs dependencies, starts the proxy, and copies the statusline script |
| `statusline-command.sh` | Statusline script — displays model name, Git branch, context usage, and 5h / 7d Rate Limit |

## ⚙️ Technical Details

* Proxy listens on port `8080`
* Rate limit data path: `/tmp/claude_rate_limit.json`
* Proxy PID path: `/tmp/claude_proxy.pid` (used for stop/restart)
* `reset_5h` field is a Unix timestamp (not ISO 8601)
