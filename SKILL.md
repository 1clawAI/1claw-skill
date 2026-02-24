---
name: 1claw
description: HSM-backed secret management for AI agents — store, retrieve, rotate, and share secrets via the 1Claw vault without exposing them in context.
homepage: https://1claw.xyz
repository: https://github.com/1clawAI/1claw
metadata:
    {
        "openclaw":
            {
                "requires":
                    {
                        "env": ["ONECLAW_AGENT_TOKEN", "ONECLAW_VAULT_ID"],
                        "bins": [],
                    },
                "primaryEnv": "ONECLAW_AGENT_TOKEN",
                "install":
                    [
                        {
                            "id": "npm",
                            "kind": "node",
                            "package": "@1claw/mcp",
                            "bins": ["1claw-mcp"],
                            "label": "1Claw MCP Server",
                        },
                    ],
                "credentials": ["ONECLAW_AGENT_TOKEN"],
                "permissions":
                    [
                        "vault:read",
                        "vault:write",
                        "vault:delete",
                        "secret:read",
                        "secret:write",
                        "secret:delete",
                        "policy:create",
                        "share:create",
                        "tx:sign",
                        "tx:simulate",
                    ],
            },
    }
---

# 1Claw — HSM-Backed Secret Management

Use this skill to securely store, retrieve, and share secrets using the 1Claw vault. 1Claw provides hardware security module (HSM) backed encryption so AI agents can access API keys, passwords, and credentials at runtime without exposing them in conversation context.

## When to use this skill

- You need an API key, password, or credential to complete a task
- You want to store a newly generated credential securely
- You need to share a secret with a user or another agent
- You need to rotate a credential after regenerating it
- You want to check what secrets are available before using one

## Access control model

Agents do NOT get blanket access to all secrets in a vault. Access is controlled by policies that specify:

- **Which paths** the agent can access (glob patterns like `api-keys/*` or `**`)
- **Which permissions** (read, write, delete)
- **Under what conditions** (IP allowlist, time windows)
- **For how long** (policy expiry date)

A human must explicitly create a policy to grant an agent access. If no policy matches, access is denied with 403. In the dashboard (Vaults → [vault] → Policies), humans can create policies (with a vault selector and agent dropdown), edit permissions/conditions/expiry, and delete policies. When an agent gets a JWT via `POST /v1/auth/agent-token`, the JWT’s `scopes` are derived from these policies (path patterns) when the agent record has no scopes set, so the token always reflects current policy access.

### Crypto transaction proxy

Agents can have `crypto_proxy_enabled` set to `true` by a human. When enabled, two things happen:

1. The agent **gains access** to submit on-chain transaction intents through a signing proxy — signing keys stay in the HSM.
2. The agent is **blocked from reading** `private_key` and `ssh_key` type secrets directly via the normal secret read endpoint (returns 403). This prevents key exfiltration.

Transaction endpoints:
- `POST /v1/agents/{id}/transactions` with `{ to, value, chain, simulate_first?, max_fee_per_gas?, max_priority_fee_per_gas? }` — signs and optionally broadcasts. Supports EIP-155 (legacy) and EIP-1559 (Type 2) fee modes. Nonce auto-resolved when omitted.
- `POST /v1/agents/{id}/transactions/simulate` — pre-flight simulation via Tenderly without signing. Returns balance changes, gas estimates, and success/revert status.
- `POST /v1/agents/{id}/transactions/simulate-bundle` — simulate multiple transactions sequentially (e.g. approve + swap).

The `simulate_first` flag runs a Tenderly simulation before signing. If the simulation reverts, the transaction is rejected with 422. Org admins can enforce simulation as mandatory via the `crypto_proxy.require_simulation` setting.

The backend fetches the signing key from the vault, signs the transaction, and returns the signed transaction hex + keccak tx hash. The key is decrypted in-memory, used once, then zeroized. The flag is disabled by default and can be toggled at any time.

### Transaction guardrails

Humans can configure per-agent guardrails that restrict what the crypto proxy allows. These are enforced server-side before any transaction is signed:

- **Allowed destinations** (`tx_to_allowlist`): List of permitted `to` addresses. If set, any transaction to an address not on the list is rejected with 403.
- **Max value per tx** (`tx_max_value_eth`): Maximum ETH value for a single transaction. Transactions exceeding this are rejected.
- **Daily spend limit** (`tx_daily_limit_eth`): Maximum cumulative ETH spend over a rolling 24-hour window. Prevents runaway spending.
- **Allowed chains** (`tx_allowed_chains`): Restrict which chains the agent can transact on (e.g. only `sepolia` for testing). Transactions on other chains are rejected.

All guardrails default to unrestricted. Humans configure them via the dashboard (Agent detail → Transaction Guardrails), CLI (`1claw agent update --tx-max-value 0.5`), or SDK (`agents.update(id, { tx_max_value_eth: "0.5" })`). An agent cannot modify its own guardrails.

## Setup

### Prerequisites

1. A 1Claw account at [1claw.xyz](https://1claw.xyz)
2. An agent registered under your account
3. An access policy granting the agent permission to the vault

**CLI for humans:** For CI/CD and servers, humans can use the official CLI: `npm install -g @1claw/cli`, then `1claw login` (browser-based) or set `ONECLAW_TOKEN` / `ONECLAW_API_KEY`. See [docs — CLI](https://docs.1claw.xyz/docs/guides/cli).

**API key authentication:** `1ck_` keys (personal or agent API keys) can be used as Bearer tokens for all API endpoints. No separate JWT exchange required.

### MCP server (recommended)

Add the 1Claw MCP server to your client configuration.

**Recommended: auto-refreshing agent credentials** — Use `ONECLAW_AGENT_ID` + `ONECLAW_AGENT_API_KEY` instead of a static JWT. The MCP server automatically refreshes tokens and stays authenticated:

```json
{
    "mcpServers": {
        "1claw": {
            "command": "npx",
            "args": ["-y", "@1claw/mcp"],
            "env": {
                "ONECLAW_AGENT_ID": "<your-agent-uuid>",
                "ONECLAW_AGENT_API_KEY": "<agent-api-key>",
                "ONECLAW_VAULT_ID": "<your-vault-uuid>"
            }
        }
    }
}
```

**Alternative: static JWT** — `ONECLAW_AGENT_TOKEN` + `ONECLAW_VAULT_ID` (tokens expire; manual refresh required):

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

Grant a user or agent access to a vault. You can only grant access on vaults you created.

```
grant_access(vault_id: "...", principal_type: "agent", principal_id: "...", permissions: ["read"])
```

### share_secret

Share a secret with your creator (the human who registered you), a specific user or agent by ID, or create an open link. Use `recipient_type: "creator"` to share back with your human — no ID needed.

```
share_secret(secret_id: "...", recipient_type: "creator", expires_at: "2026-12-31T00:00:00Z")
share_secret(secret_id: "...", recipient_type: "user", recipient_id: "...", expires_at: "2026-12-31T00:00:00Z", max_access_count: 3)
share_secret(secret_id: "...", recipient_type: "anyone_with_link", expires_at: "2026-12-31T00:00:00Z")
```

`max_access_count: 0` is treated as unlimited (not zero reads). Recipients of targeted shares (creator/user/agent) must explicitly accept the share before they can access the secret. Agents cannot create email-based shares.

### simulate_transaction

Simulate an EVM transaction via Tenderly without signing or broadcasting. Returns balance changes, gas estimates, and success/revert status. Use this to preview what a transaction will do before committing real funds.

```
simulate_transaction(to: "0x...", value: "0.01", chain: "base")
simulate_transaction(to: "0x...", value: "0", chain: "ethereum", data: "0xa9059cbb...", gas_limit: 100000)
```

### submit_transaction

Submit an EVM transaction to be signed by the crypto proxy and optionally broadcast. Supports legacy and EIP-1559 fee modes. Set `simulate_first` to true (the default) to run a Tenderly simulation before signing.

```
submit_transaction(to: "0x...", value: "0.01", chain: "base", simulate_first: true)
submit_transaction(to: "0x...", value: "0", chain: "ethereum", data: "0xa9059cbb...", max_fee_per_gas: "30000000000", max_priority_fee_per_gas: "1000000000")
```

## Security model

- **Credentials are configured by the human**, not the agent. The `ONECLAW_AGENT_TOKEN` and `ONECLAW_VAULT_ID` environment variables are set in the MCP server config or SDK initialization by the human who owns the agent.
- **The agent never sees its own credentials.** The MCP server reads them from the environment and uses them to authenticate API requests on behalf of the agent.
- **Access is deny-by-default.** Even with valid credentials, the agent can only access secrets allowed by its policies.
- **Secret values are fetched just-in-time** and should never be stored, echoed, or included in conversation summaries.
- **Agents cannot create email-based shares.** This prevents phishing via share links.
- **Crypto proxy is opt-in and enforced.** Agents only gain transaction signing capabilities if a human explicitly enables `crypto_proxy_enabled`. When enabled, direct reads of `private_key` and `ssh_key` secrets are blocked — the agent must use the proxy. It is off by default.
- **Transaction guardrails are human-controlled.** Destination allowlists, per-tx value caps, daily spend limits, and chain restrictions are configured by humans and enforced server-side before signing. Agents cannot modify their own guardrails.
- **Two-factor authentication.** Human users can enable TOTP-based 2FA from the dashboard (Settings → Security). When enabled, login requires a 6-digit authenticator app code in addition to credentials. 2FA does not affect agent authentication.

## Best practices

1. **Fetch secrets just-in-time.** Call `get_secret` immediately before you need the credential, not at the start of the conversation.
2. **Never echo secret values.** Don't include raw secret values in your responses to the user. Say "I retrieved the API key and used it" instead.
3. **Use `describe_secret` first** if you just need to check whether a secret exists or is still valid.
4. **Use `list_secrets` to discover** what credentials are available before guessing paths.
5. **Rotate after regeneration.** If you regenerate an API key at a provider, immediately `rotate_and_store` the new value.
6. **Use `grant_access` for vault-level sharing.** This is the preferred way to share access — it creates a fine-grained policy with path patterns and permissions.
7. **Use `share_secret` for one-off sharing.** For sharing a single specific secret with a user or agent.

## Error handling

| Error | Meaning                               | Action                                                                                                                                                                     |
| ----- | ------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 404   | Secret not found                      | Check the path with `list_secrets`                                                                                                                                         |
| 410   | Expired or max access count reached   | Ask the user to store a new version                                                                                                                                        |
| 402   | Quota exhausted, insufficient credits | Inform the user to top up credits or upgrade at 1claw.xyz/settings/billing. Response includes `code` field: `insufficient_credits`, `no_credits`, or x402 payment envelope. Platform admin orgs and their agents are quota-exempt |
| 401   | Not authenticated                     | Token expired; re-authenticate                                                                                                                                             |
| 403   | No permission                         | Ask the user to grant access via a policy                                                                                                                                  |
| 429   | Rate limited                          | Wait and retry; share creation is limited to 10/min/org                                                                                                                    |

## Links

- Dashboard: [1claw.xyz](https://1claw.xyz)
- Docs: [docs.1claw.xyz](https://docs.1claw.xyz)
- SDK: [github.com/1clawAI/1claw-sdk](https://github.com/1clawAI/1claw-sdk)
- MCP server: [@1claw/mcp on npm](https://www.npmjs.com/package/@1claw/mcp)
- API: `https://api.1claw.xyz`
