---
name: Reply Chat
description: Send a message to the Crewly Chat UI. Use this to post responses, updates, or notifications directly to a chat conversation.
version: 1.0.0
category: communication
skillType: claude-skill
assignableRoles:
  - team-leader
  - developer
  - qa
  - tpm
  - designer
  - frontend-developer
  - backend-developer
  - fullstack-dev
  - qa-engineer
  - product-manager
  - architect
  - generalist
  - sales
  - support
triggers:
  - reply chat
  - send chat
  - chat message
  - chat response
tags:
  - communication
  - chat
  - notification
execution:
  type: script
  script:
    file: execute.sh
    interpreter: bash
    timeoutMs: 15000
---

# Reply Chat Skill

Send a message to the Crewly Chat UI. This is the preferred way for agents to post messages to the Chat UI.

## Usage

```bash
bash config/skills/agent/core/reply-chat/execute.sh '{"content":"Task completed","senderName":"dev-1"}'
```

### Flag-based

```bash
bash config/skills/agent/core/reply-chat/execute.sh \
  --text "Task completed" \
  --sender "dev-1" \
  --conversation "conv-abc123"
```

## Options

| Flag | Short | Description |
|------|-------|-------------|
| `--conversation` | `-C` | Chat conversation ID (optional — defaults to current) |
| `--text` | `-t` | Message text |
| `--text-base64` | | UTF-8 message encoded as Base64 (recommended from Windows PowerShell) |
| `--sender` | `-s` | Sender name (required) |
| `--sender-type` | | Sender type (default: agent) |

### Windows PowerShell (UTF-8 seguro)

Do not pass accented text directly from Windows PowerShell to Bash. Encode the
message first so only ASCII crosses the PowerShell/Bash boundary:

```powershell
$reply = @'
Actualización visible para el usuario.
'@
$encoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($reply))
bash config/skills/agent/core/reply-chat/execute.sh --conversation "conv-abc123" --sender "dev-1" --text-base64 "$encoded"
```
