# 1Claw Skill for ClawHub

An [OpenClaw](https://docs.openclaw.ai) skill that gives AI agents secure, HSM-backed secret management via [1Claw](https://1claw.xyz).

## What it does

Teaches agents to store, retrieve, rotate, and share secrets using the 1Claw vault. Secrets are encrypted with hardware security modules and fetched just-in-time — they never persist in conversation context.

## Files

| File | Purpose |
|------|---------|
| `SKILL.md` | Primary skill description, setup, tools, and best practices |
| `EXAMPLES.md` | Example agent conversations demonstrating each tool |
| `CONFIG.md` | Environment variables, credential setup, and secret types |

## Install via ClawHub CLI

```bash
clawhub install 1claw
```

## Links

- [1Claw Dashboard](https://1claw.xyz)
- [Documentation](https://docs.1claw.xyz)
- [SDK](https://github.com/kmjones1979/1claw-sdk)
- [MCP Server](https://github.com/kmjones1979/1claw/tree/main/packages/mcp)
