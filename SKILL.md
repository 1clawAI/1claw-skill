---
name: 1claw
description: HSM-backed secret management for AI agents — store, retrieve, rotate, and share secrets via the 1Claw vault without exposing them in context.
homepage: https://1claw.xyz
---

# 1Claw — HSM-Backed Secret Management

Use this skill to securely store, retrieve, and share secrets using the 1Claw vault. 1Claw provides hardware security module (HSM) backed encryption so AI agents can access API keys, passwords, and credentials at runtime without exposing them in conversation context.

## When to use this skill

- You need an API key, password, or credential to complete a task
- You want to store a newly generated credential securely
- You need to share a secret with a human collaborator by email
- You need to rotate a credential after regenerating it
- You want to check what secrets are available before using one

## Setup

### Prerequisites

1. A 1Claw account at [1claw.xyz](https://1claw.xyz)
2. An agent registered under your account
3. An access policy granting the agent permission to the vault

### MCP server (recommended)

Add the 1Claw MCP server to your client configuration:

**Claude Desktop / Cursor** (stdio mode):

```json
{
    "mcpServers": {
        "1claw": {
            "command": "npx",
            "args": ["-y", "@1claw/mcp"],
            "env": {
                "ONECLAW_AGENT_TOKEN": "<your-agent-jwt>",
                "ONECLAW_VAULT_ID": "<your-vault-uuid>"
            }
        }
    }
}
```

**Hosted mode** (HTTP streaming):

```
URL: https://mcp.1claw.xyz/mcp
Headers:
  Authorization: Bearer <agent-jwt>
  X-Vault-ID: <vault-uuid>
```

### TypeScript SDK

```bash
npm install @1claw/sdk
```

```ts
import { createClient } from "@1claw/sdk";

const client = createClient({
    baseUrl: "https://api.1claw.xyz",
    agentId: process.env.ONECLAW_AGENT_ID,
    apiKey: process.env.ONECLAW_AGENT_API_KEY,
});
```

## Available tools

### list_secrets

List all secrets in the vault. Returns paths, types, and versions — never values.

```
list_secrets()
list_secrets(prefix: "api-keys/")
```

### get_secret

Fetch the decrypted value of a secret by path. Use immediately before the API call that needs it. Do not store the value or include it in summaries.

```
get_secret(path: "api-keys/stripe")
```

### put_secret

Store a new secret or update an existing one. Each call creates a new version.

```
put_secret(path: "api-keys/stripe", value: "sk_live_...", type: "api_key")
```

Types: `api_key`, `password`, `private_key`, `certificate`, `file`, `note`, `ssh_key`, `env_bundle`.

### delete_secret

Soft-delete a secret. Reversible by an admin.

```
delete_secret(path: "api-keys/old-key")
```

### describe_secret

Get metadata (type, version, expiry) without fetching the value. Use to check existence or validity.

```
describe_secret(path: "api-keys/stripe")
```

### rotate_and_store

Store a new value for an existing secret, creating a new version. Use after regenerating a key.

```
rotate_and_store(path: "api-keys/stripe", value: "sk_live_new...")
```

### get_env_bundle

Fetch an `env_bundle` secret and parse its KEY=VALUE lines as JSON.

```
get_env_bundle(path: "config/prod-env")
```

### create_vault

Create a new vault for organizing secrets.

```
create_vault(name: "project-keys", description: "API keys for the project")
```

### list_vaults

List all vaults accessible to you.

```
list_vaults()
```

### grant_access

Grant a user or agent access to a vault.

```
grant_access(vault_id: "...", principal_type: "agent", principal_id: "...", permissions: ["read"])
```

### share_secret

Share a secret with someone by email. They don't need a 1Claw account — the share is claimed when they sign up.

```
share_secret(secret_id: "...", email: "alice@example.com", expires_at: "2026-12-31T00:00:00Z", max_access_count: 3)
```

## Best practices

1. **Fetch secrets just-in-time.** Call `get_secret` immediately before you need the credential, not at the start of the conversation.
2. **Never echo secret values.** Don't include raw secret values in your responses to the user. Say "I retrieved the API key and used it" instead.
3. **Use `describe_secret` first** if you just need to check whether a secret exists or is still valid.
4. **Use `list_secrets` to discover** what credentials are available before guessing paths.
5. **Rotate after regeneration.** If you regenerate an API key at a provider, immediately `rotate_and_store` the new value.
6. **Share by email** when a human collaborator needs a credential. They'll see it when they log in.

## Error handling

| Error | Meaning                             | Action                                                   |
| ----- | ----------------------------------- | -------------------------------------------------------- |
| 404   | Secret not found                    | Check the path with `list_secrets`                       |
| 410   | Expired or max access count reached | Ask the user to store a new version                      |
| 402   | Free tier quota exhausted           | Inform the user to upgrade at 1claw.xyz/settings/billing |
| 401   | Not authenticated                   | Token expired; re-authenticate                           |
| 403   | No permission                       | Ask the user to grant access via a policy                |

## Links

- Dashboard: [1claw.xyz](https://1claw.xyz)
- Docs: [docs.1claw.xyz](https://docs.1claw.xyz)
- SDK: [github.com/1clawAI/1claw-sdk](https://github.com/1clawAI/1claw-sdk)
- MCP server: [@1claw/mcp on npm](https://www.npmjs.com/package/@1claw/mcp)
- API: `https://api.1claw.xyz`
