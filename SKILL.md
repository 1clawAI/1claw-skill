---
name: 1claw
version: 1.8.0
description: HSM-backed secret management for AI agents — store, retrieve, rotate, and share secrets via the 1Claw vault without exposing them in context. 1Claw is also a JWKS-published OIDC issuer for Workload Identity Federation (Anthropic WIF, GCP STS, AWS STS).
homepage: https://1claw.xyz
repository: https://github.com/1clawAI/1claw
metadata:
    {
        "openclaw":
            {
                "requires":
                    {
                        "env":
                            [
                                "ONECLAW_AGENT_API_KEY",
                            ],
                        "bins": [],
                    },
                "primaryEnv": "ONECLAW_AGENT_API_KEY",
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
                "credentials": ["ONECLAW_AGENT_API_KEY"],
                "optional_credentials":
                    ["ONECLAW_AGENT_ID", "ONECLAW_VAULT_ID"],
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

# 1Claw — HSM-Backed Secret Management for AI Agents

1Claw is a cloud HSM-backed secrets manager. Agents access API keys, passwords, and credentials at runtime without them ever entering the conversation context. Secrets are encrypted with keys that never leave the HSM.

**API base URL:** `https://api.1claw.xyz`
**Shroud (TEE proxy):** `https://shroud.1claw.xyz`
**MCP endpoint:** `https://mcp.1claw.xyz/mcp`
**Dashboard:** `https://1claw.xyz`
**Docs:** `https://docs.1claw.xyz`

## Pinata / OpenClaw

**Only `ONECLAW_AGENT_API_KEY` is a secret** in the host environment (e.g. Pinata → Environment Variables). Do not instruct users to set `ONECLAW_VAULT_ID` or `ONECLAW_AGENT_ID` as required — those UUIDs are optional identifiers, not credentials; the OpenClaw plugin auto-resolves agent and default vault from the API key. Mention `ONECLAW_VAULT_ID` only when pinning a specific vault among several.

## When to use this skill

- You need an API key, password, or credential to complete a task
- You want to store a newly generated credential securely
- You need to share a secret with a user or another agent
- You need to rotate a credential after regenerating it
- You want to check what secrets are available before using one
- You need to sign or simulate an EVM transaction without exposing private keys
- You need to sign an EIP-191 personal message or EIP-712 typed data
- You want to provision multi-chain signing keys (Ethereum, Bitcoin, Solana, XRP, Cardano, Tron)
- You want TEE-grade key isolation for transaction signing (use Shroud at `shroud.1claw.xyz`)
- Your vault uses **MPC secret storage** — DEKs split across GCP/AWS/Azure HSMs (Shamir 2-of-3) or XOR 2-of-2 client custody; provide `X-Client-Share` header when reading from client-custody vaults
- Your org uses **LLM token billing** (Stripe AI Gateway): enable in the dashboard; agent JWTs include `llm_token_billing` / `stripe_customer_id` for Shroud routing
- You need to request access to a Safe multisig treasury (agent access requests)
- You want to manage or deploy agent EVM addresses and Safe smart accounts (ERC-4337, one per chain; `POST /v1/agents/{id}/smart-accounts` to add a Safe)

---

## Setup

### Option 0: Self-enrollment (new agents)

If you don't have credentials yet, self-enroll. The API creates a **pending** enrollment; the human **approves** in the dashboard (or via the emailed link). After approval, the API key is emailed.

**With the human's email** — Allow/Deny links are emailed, and the JSON response usually includes **`approval_url`** as a fallback if mail is delayed or lost:

```bash
# curl
curl -s -X POST https://api.1claw.xyz/v1/agents/enroll \
  -H "Content-Type: application/json" \
  -d '{"name":"my-agent","human_email":"human@example.com"}'

# TypeScript SDK (static method, no auth needed)
import { AgentsResource } from "@1claw/sdk";
await AgentsResource.enroll("https://api.1claw.xyz", {
  name: "my-agent",
  human_email: "human@example.com",
});

# CLI (no auth needed)
npx @1claw/cli agent enroll my-agent --email human@example.com
```

**Name only** (omit `human_email`) — response includes **`approval_url`**; the human opens it while signed in to approve into their org (no email required to start):

```bash
curl -s -X POST https://api.1claw.xyz/v1/agents/enroll \
  -H "Content-Type: application/json" \
  -d '{"name":"my-agent"}'

npx @1claw/cli agent enroll my-agent
```

The human receives the Agent ID + API key by email after approval. They then configure policies for your access.

### Option 1: MCP server (recommended for AI agents)

Add to your MCP client configuration. Only the API key is required — agent ID and vault are auto-discovered.

```json
{
    "mcpServers": {
        "1claw": {
            "command": "npx",
            "args": ["-y", "@1claw/mcp"],
            "env": {
                "ONECLAW_AGENT_API_KEY": "<agent-api-key>"
            }
        }
    }
}
```

Optional overrides: `ONECLAW_AGENT_ID` (explicit agent), `ONECLAW_VAULT_ID` (explicit vault).

**stdio refresh:** The MCP server rebuilds its Vault API client from **current** environment variables on **each tool call** (no long-lived cached client tied to startup env), so updating `ONECLAW_VAULT_ID` or keys in the client config takes effect without restarting the process.

Hosted HTTP streaming mode:

```
URL: https://mcp.1claw.xyz/mcp
Headers:
  Authorization: Bearer <agent-jwt>
  X-Vault-ID: <vault-uuid>
```

### Option 2: TypeScript SDK

```bash
npm install @1claw/sdk
```

```ts
import { createClient } from "@1claw/sdk";

const client = createClient({
    baseUrl: "https://api.1claw.xyz",
    apiKey: process.env.ONECLAW_AGENT_API_KEY,
});
```

### Option 3: Direct REST API

Authenticate, then pass the Bearer token on every request.

```bash
# Exchange agent API key for a JWT (key-only — agent_id is auto-resolved)
RESP=$(curl -s -X POST https://api.1claw.xyz/v1/auth/agent-token \
  -H "Content-Type: application/json" \
  -d '{"api_key":"<key>"}')
TOKEN=$(echo "$RESP" | jq -r .access_token)
AGENT_ID=$(echo "$RESP" | jq -r .agent_id)

# Use the JWT
curl -H "Authorization: Bearer $TOKEN" https://api.1claw.xyz/v1/vaults
```

**Alternative:** `1ck_` API keys (personal or agent) can be used directly as Bearer tokens — no JWT exchange needed.

---

## Authentication

### Agent auth flow

1. Human registers an agent in the dashboard or via `POST /v1/agents` with an `auth_method` (`api_key` default, `mtls`, or `oidc_client_credentials`). For `api_key` agents → receives `agent_id` + `api_key` (prefix `ocv_`). For mTLS/OIDC agents → receives `agent_id` only (no API key).
2. All agents auto-receive an Ed25519 SSH keypair (public key on agent record, private key in `__agent-keys` vault).
3. API key agents exchange credentials: `POST /v1/auth/agent-token` with `{ "api_key": "<key>" }` (or `{ "agent_id": "<uuid>", "api_key": "<key>" }`) → returns `{ "access_token": "<jwt>", "expires_in": 3600, "agent_id": "<uuid>", "vault_ids": ["..."] }`. Agent ID is optional — the server resolves it from the key prefix.
4. Agent uses `Authorization: Bearer <jwt>` on all subsequent requests.
5. JWT scopes derive from the agent's access policies (path patterns). If no policies exist, scopes are empty (zero access). The agent's `vault_ids` are also included in the JWT — requests to unlisted vaults are rejected.
6. Token TTL defaults to ~1 hour but can be set per-agent via `token_ttl_seconds`. The MCP server auto-refreshes 60s before expiry.

### API key auth

Tokens starting with `1ck_` (human personal API keys) or `ocv_` (agent API keys) can be used as Bearer tokens directly on any authenticated endpoint.

### Human password reset (email/password accounts)

- Dashboard: **Forgot password?** on the login page → email link → `/reset-password?token=…`.
- API: `POST /v1/auth/forgot-password` `{ "email" }` and `POST /v1/auth/reset-password` `{ "token", "new_password" }` (public; forgot returns a generic message).
- CLI: `1claw forgot-password`, `1claw reset-password` (use `--api-url` for self-hosted).
- **Session revocation on password change/reset:** Both `change-password` and `reset-password` invalidate all existing JWTs for the user (`revoked_before` timestamp). Any previously issued token returns 401.
- **Account lockout:** 10 consecutive failed login attempts lock the account for 15 minutes. The lockout is per-user and resets on successful login.

### Shroud & Intents hosts

- **Shroud** (`shroud.1claw.xyz`): TEE LLM proxy + transaction signing; full Intents API surface.
- **Intents** (`intents.1claw.xyz`): Additional ingress for signing/health checks; production smoke tests hit `/healthz`.

---

## MCP Tools Reference

### list_secrets

List all secrets in the vault. Returns paths, types, and versions — never values.

| Parameter | Type   | Required | Description                              |
| --------- | ------ | -------- | ---------------------------------------- |
| `prefix`  | string | no       | Path prefix to filter (e.g. `api-keys/`) |

### get_secret

Fetch the decrypted value of a secret. Use immediately before the API call that needs it. Never store the value or include it in summaries.

| Parameter | Type   | Required | Description                          |
| --------- | ------ | -------- | ------------------------------------ |
| `path`    | string | yes      | Secret path (e.g. `api-keys/stripe`) |

### put_secret

Store a new secret or update an existing one. Each call creates a new version.

| Parameter          | Type   | Required | Default   | Description                                                                                          |
| ------------------ | ------ | -------- | --------- | ---------------------------------------------------------------------------------------------------- |
| `path`             | string | yes      |           | Secret path                                                                                          |
| `value`            | string | yes      |           | The secret value                                                                                     |
| `type`             | string | no       | `api_key` | One of: `api_key`, `password`, `private_key`, `certificate`, `file`, `note`, `ssh_key`, `env_bundle` |
| `metadata`         | object | no       |           | Arbitrary JSON metadata                                                                              |
| `expires_at`       | string | no       |           | ISO 8601 expiry datetime                                                                             |
| `max_access_count` | number | no       |           | Max reads before auto-expiry (0 = unlimited)                                                         |

### delete_secret

Soft-delete a secret. Reversible by an admin.

| Parameter | Type   | Required | Description           |
| --------- | ------ | -------- | --------------------- |
| `path`    | string | yes      | Secret path to delete |

### describe_secret

Get metadata (type, version, expiry) without fetching the value. Use to check existence.

| Parameter | Type   | Required | Description |
| --------- | ------ | -------- | ----------- |
| `path`    | string | yes      | Secret path |

### rotate_and_store

Store a new value for an existing secret, creating a new version. Use after regenerating a key.

| Parameter | Type   | Required | Description      |
| --------- | ------ | -------- | ---------------- |
| `path`    | string | yes      | Secret path      |
| `value`   | string | yes      | New secret value |

### get_env_bundle

Fetch an `env_bundle` secret and parse its `KEY=VALUE` lines as JSON.

| Parameter | Type   | Required | Description                    |
| --------- | ------ | -------- | ------------------------------ |
| `path`    | string | yes      | Path to an `env_bundle` secret |

### create_vault

Create a new vault for organizing secrets.

| Parameter     | Type   | Required | Description              |
| ------------- | ------ | -------- | ------------------------ |
| `name`        | string | yes      | Vault name (1–255 chars) |
| `description` | string | no       | Short description        |

### list_vaults

List all vaults accessible to you. No parameters.

### grant_access

Grant a user or agent access to a vault path pattern.

| Parameter             | Type              | Required | Default    | Description                                    |
| --------------------- | ----------------- | -------- | ---------- | ---------------------------------------------- |
| `vault_id`            | string (UUID)     | yes      |            | Vault ID                                       |
| `principal_type`      | `user` \| `agent` | yes      |            | Who to grant access to                         |
| `principal_id`        | string (UUID)     | yes      |            | The user or agent UUID                         |
| `permissions`         | string[]          | no       | `["read"]` | `["read"]`, `["write"]`, or `["read","write"]` |
| `secret_path_pattern` | string            | no       | `**`       | Glob pattern for secret paths                  |

### share_secret

Share a secret via link, with your creator, or with a specific user/agent.

| Parameter          | Type                                                 | Required       | Description                                                              |
| ------------------ | ---------------------------------------------------- | -------------- | ------------------------------------------------------------------------ |
| `secret_id`        | string (UUID)                                        | yes            | The secret's UUID                                                        |
| `recipient_type`   | `user` \| `agent` \| `anyone_with_link` \| `creator` | yes            | `creator` shares with the human who registered this agent — no ID needed |
| `recipient_id`     | string (UUID)                                        | conditional    | Required for `user` and `agent` types                                    |
| `expires_at`       | string                                               | yes            | ISO 8601 expiry                                                          |
| `max_access_count` | number                                               | no (default 5) | Max reads (0 = unlimited)                                                |

Targeted shares (creator/user/agent) require the recipient to explicitly accept before access.

### simulate_transaction

Simulate an EVM transaction via Tenderly without signing. Returns balance changes, gas estimates, success/revert status.

| Parameter          | Type   | Required | Default               | Description                                   |
| ------------------ | ------ | -------- | --------------------- | --------------------------------------------- |
| `to`               | string | yes      |                       | Destination address (0x-prefixed)             |
| `value`            | string | yes      |                       | Value in ETH (e.g. `"0.01"`)                  |
| `chain`            | string | yes      |                       | Chain name or chain ID (see Supported Chains) |
| `data`             | string | no       |                       | Hex-encoded calldata                          |
| `signing_key_path` | string | no       | `keys/{chain}-signer` | Vault path to signing key                     |
| `gas_limit`        | number | no       | 21000                 | Gas limit                                     |

### submit_transaction

Submit an EVM transaction for signing and optional broadcast. Requires `intents_api_enabled`.

| Parameter                  | Type    | Required | Default               | Description                               |
| -------------------------- | ------- | -------- | --------------------- | ----------------------------------------- |
| `to`                       | string  | yes      |                       | Destination address                       |
| `value`                    | string  | yes      |                       | Value in ETH                              |
| `chain`                    | string  | yes      |                       | Chain name or chain ID                    |
| `data`                     | string  | no       |                       | Hex-encoded calldata                      |
| `signing_key_path`         | string  | no       | `keys/{chain}-signer` | Vault path to signing key                 |
| `nonce`                    | number  | no       | auto-resolved         | Transaction nonce                         |
| `gas_price`                | string  | no       |                       | Gas price in wei (legacy mode)            |
| `gas_limit`                | number  | no       | 21000                 | Gas limit                                 |
| `max_fee_per_gas`          | string  | no       |                       | EIP-1559 max fee in wei (triggers Type 2) |
| `max_priority_fee_per_gas` | string  | no       |                       | EIP-1559 priority fee in wei              |
| `simulate_first`           | boolean | no       | true                  | Run Tenderly simulation before signing    |

### sign_transaction

Sign an EVM transaction without broadcasting. Returns `signed_tx` hex + `tx_hash` + `from` address. Same guardrails as `submit_transaction`.

| Parameter                  | Type    | Required | Default               | Description                               |
| -------------------------- | ------- | -------- | --------------------- | ----------------------------------------- |
| `to`                       | string  | yes      |                       | Destination address                       |
| `value`                    | string  | yes      |                       | Value in ETH                              |
| `chain`                    | string  | yes      |                       | Chain name or chain ID                    |
| `data`                     | string  | no       |                       | Hex-encoded calldata                      |
| `signing_key_path`         | string  | no       | `keys/{chain}-signer` | Vault path to signing key                 |
| `nonce`                    | number  | no       | auto-resolved         | Transaction nonce                         |
| `gas_price`                | string  | no       |                       | Gas price in wei (legacy mode)            |
| `gas_limit`                | number  | no       | 21000                 | Gas limit                                 |
| `max_fee_per_gas`          | string  | no       |                       | EIP-1559 max fee in wei (triggers Type 2) |
| `max_priority_fee_per_gas` | string  | no       |                       | EIP-1559 priority fee in wei              |

### list_transactions

List an agent's past transactions. Returns transaction history with status, chain, value, and timestamps.

No parameters required (uses the authenticated agent's context).

### get_transaction

Get details of a specific transaction.

| Parameter | Type   | Required | Description    |
| --------- | ------ | -------- | -------------- |
| `tx_id`   | string | yes      | Transaction ID |

### simulate_bundle

Simulate multiple EVM transactions as a sequence via Tenderly. Returns per-transaction results.

| Parameter      | Type   | Required | Description                                                         |
| -------------- | ------ | -------- | ------------------------------------------------------------------- |
| `transactions` | array  | yes      | Array of transaction objects (same fields as `simulate_transaction`) |

### inspect_content

Inspect text content through the Shroud security pipeline. Returns threat detections and policy violations without sending to an LLM.

| Parameter | Type   | Required | Description             |
| --------- | ------ | -------- | ----------------------- |
| `content` | string | yes      | Text content to inspect |

### list_signing_keys

List all multi-chain signing keys for an agent. Returns key IDs, chains, curves, public keys, and addresses.

| Parameter  | Type   | Required | Description                                |
| ---------- | ------ | -------- | ------------------------------------------ |
| `agent_id` | string | no       | Agent ID (uses authenticated agent if omitted) |

### provision_signing_key

Generate a signing key for an agent on a given blockchain. Returns the public key, on-chain address (when applicable), and key metadata. The private key is stored securely in the vault.

| Parameter  | Type   | Required | Description                                               |
| ---------- | ------ | -------- | --------------------------------------------------------- |
| `agent_id` | string | no       | Agent ID (uses authenticated agent if omitted)            |
| `chain`    | string | yes      | One of: ethereum, bitcoin, solana, xrp, cardano, tron     |

### sign_message

Sign a message using EIP-191 personal_sign. Agent must have `message_signing_enabled`.

| Parameter          | Type   | Required | Default               | Description                              |
| ------------------ | ------ | -------- | --------------------- | ---------------------------------------- |
| `agent_id`         | string | no       |                       | Agent ID (uses authenticated agent if omitted) |
| `message`          | string | yes      |                       | Hex-encoded message (0x-prefixed or raw) |
| `chain`            | string | no       | `ethereum`            | Chain name                               |
| `signing_key_path` | string | no       | `keys/{chain}-signer` | Vault path to signing key                |

### sign_typed_data

Sign EIP-712 typed structured data. Agent must pass EIP-712 guardrail enforcement (domain allowlist).

| Parameter          | Type   | Required | Default               | Description                                    |
| ------------------ | ------ | -------- | --------------------- | ---------------------------------------------- |
| `agent_id`         | string | no       |                       | Agent ID (uses authenticated agent if omitted) |
| `typed_data`       | object | yes      |                       | EIP-712 object (types, primaryType, domain, message) |
| `chain`            | string | no       | `ethereum`            | Chain name                                     |
| `signing_key_path` | string | no       | `keys/{chain}-signer` | Vault path to signing key                      |

### rotate_generate

Generate a new random value and rotate a secret to it. Combines generation and rotation in one step.

| Parameter | Type   | Required | Default   | Description                  |
| --------- | ------ | -------- | --------- | ---------------------------- |
| `path`    | string | yes      |           | Secret path                  |
| `type`    | string | no       | `api_key` | Secret type                  |
| `length`  | number | no       | 32        | Length of the generated value |

### list_versions

List all versions of a secret. Returns version numbers, timestamps, and status.

| Parameter | Type   | Required | Description |
| --------- | ------ | -------- | ----------- |
| `path`    | string | yes      | Secret path |

---

## REST API Quick Reference

Base URL: `https://api.1claw.xyz`. All authenticated endpoints require `Authorization: Bearer <token>`.

### Auth (public — no token required)

| Method | Path                    | Description                                           |
| ------ | ----------------------- | ----------------------------------------------------- |
| `POST` | `/v1/auth/token`        | Login (email + password) → `{ access_token }`         |
| `POST` | `/v1/auth/agent-token`  | Agent login (agent_id + api_key) → `{ access_token }` |
| `POST` | `/v1/auth/federated-token` | RFC 8693 token exchange → RS256 JWT for external relying parties |
| `POST` | `/v1/auth/google`       | Google OAuth (ID token verified via JWKS)             |
| `POST` | `/v1/auth/signup`       | Create account → sends verification email             |
| `POST` | `/v1/auth/verify-email` | Verify email token → creates user                     |
| `POST` | `/v1/auth/mfa/verify`   | Verify MFA code during login                          |
| `GET`  | `/.well-known/openid-configuration` | OIDC discovery (issuer, jwks_uri, supported algs) |
| `GET`  | `/.well-known/jwks.json` | Public JWKS (EdDSA + RS256 key versions, keyed by `kid`) |

### Auth (authenticated)

| Method   | Path                       | Description                                                      |
| -------- | -------------------------- | ---------------------------------------------------------------- |
| `GET`    | `/v1/auth/me`              | Get current user profile                                         |
| `PATCH`  | `/v1/auth/me`              | Update profile (`display_name`, `marketing_emails`)              |
| `DELETE` | `/v1/auth/me`              | Delete account (body: `{ "confirmation": "DELETE MY ACCOUNT" }`) |
| `DELETE` | `/v1/auth/token`           | Revoke current token                                             |
| `POST`   | `/v1/auth/change-password` | Change password                                                  |
| `POST`   | `/v1/auth/export-data`     | GDPR data export (returns JSON archive of user's personal data)  |

### Vaults

| Method   | Path                                   | Description                                                           |
| -------- | -------------------------------------- | --------------------------------------------------------------------- |
| `POST`   | `/v1/vaults`                           | Create vault (`{ name, description? }`) → `201`                       |
| `GET`    | `/v1/vaults`                           | List vaults → `{ vaults: [...] }`                                     |
| `GET`    | `/v1/vaults/{id}`                      | Get vault details                                                     |
| `DELETE` | `/v1/vaults/{id}`                      | Delete vault → `204`                                                  |
| `POST`   | `/v1/vaults/{id}/cmek`                 | Enable CMEK (`{ fingerprint }`)                                       |
| `DELETE` | `/v1/vaults/{id}/cmek`                 | Disable CMEK                                                          |
| `POST`   | `/v1/vaults/{id}/cmek-rotate`          | Start CMEK key rotation (headers: `X-CMEK-Old-Key`, `X-CMEK-New-Key`) |
| `GET`    | `/v1/vaults/{id}/cmek-rotate/{job_id}` | Get rotation job status                                               |

### Secrets

| Method   | Path                                 | Description                                                                                |
| -------- | ------------------------------------ | ------------------------------------------------------------------------------------------ |
| `PUT`    | `/v1/vaults/{id}/secrets/{path}`     | Store/update secret (`{ type, value, metadata?, expires_at?, max_access_count? }`) → `201` |
| `GET`    | `/v1/vaults/{id}/secrets/{path}`     | Read secret → `{ path, type, value, version, metadata }`                                   |
| `DELETE` | `/v1/vaults/{id}/secrets/{path}`     | Delete secret → `204`                                                                      |
| `GET`    | `/v1/vaults/{id}/secrets?prefix=...` | List secrets (metadata only, no values)                                                    |
| `GET`    | `/v1/vaults/{id}/secret-versions/{path}` | List all versions of a secret                                                          |
| `GET`    | `/v1/vaults/{id}/secret-version/{path}/{version}` | Get a specific secret version                                                  |
| `POST`   | `/v1/vaults/{id}/secret-versions/{path}/disable` | Disable a secret version                                                        |
| `POST`   | `/v1/vaults/{id}/secret-rotate/{path}` | Server-side secret rotation                                                            |

### Agents

| Method   | Path                                   | Description                                                                |
| -------- | -------------------------------------- | -------------------------------------------------------------------------- |
| `POST`   | `/v1/agents`                           | Create agent → `{ agent: {...}, api_key: "ocv_..." }`                      |
| `GET`    | `/v1/agents`                           | List agents → `{ agents: [...] }`                                          |
| `GET`    | `/v1/agents/{id}`                      | Get agent                                                                  |
| `GET`    | `/v1/agents/me`                        | Get current agent (self)                                                   |
| `PATCH`  | `/v1/agents/{id}`                      | Update agent (is_active, scopes, intents_api_enabled, guardrails) — **user-only; agents cannot PATCH their own record** |
| `DELETE` | `/v1/agents/{id}`                      | Delete agent → `204`                                                       |
| `POST`   | `/v1/agents/{id}/rotate-key`           | Rotate agent API key → `{ api_key: "ocv_..." }`                            |
| `POST`   | `/v1/agents/{id}/rotate-identity-keys` | Rotate agent SSH + ECDH keypairs (user-only; keys in `__agent-keys` vault) |

### Policies (Access Control)

| Method   | Path                             | Description                                                                                                    |
| -------- | -------------------------------- | -------------------------------------------------------------------------------------------------------------- |
| `POST`   | `/v1/vaults/{id}/policies`       | Create policy (`{ principal_type, principal_id, secret_path_pattern, permissions, conditions?, expires_at? }`) |
| `GET`    | `/v1/vaults/{id}/policies`       | List policies for vault                                                                                        |
| `PUT`    | `/v1/vaults/{id}/policies/{pid}` | Update policy (permissions, conditions, expires_at only)                                                       |
| `DELETE` | `/v1/vaults/{id}/policies/{pid}` | Delete policy → `204`                                                                                          |

### Sharing

| Method   | Path                      | Description                                     |
| -------- | ------------------------- | ----------------------------------------------- |
| `POST`   | `/v1/secrets/{id}/share`  | Create share link                               |
| `GET`    | `/v1/shares/outbound`     | List shares you created                         |
| `GET`    | `/v1/shares/inbound`      | List shares sent to you                         |
| `POST`   | `/v1/shares/{id}/accept`  | Accept an inbound share                         |
| `POST`   | `/v1/shares/{id}/decline` | Decline an inbound share                        |
| `DELETE` | `/v1/share/{id}`          | Revoke a share                                  |
| `GET`    | `/v1/share/{id}`          | Access a share (public, may require passphrase) |

### Intents API (requires `intents_api_enabled`)

| Method   | Path                                               | Description                                                                                       |
| -------- | -------------------------------------------------- | ------------------------------------------------------------------------------------------------- |
| `POST`   | `/v1/agents/{id}/transactions`                     | Submit transaction for signing. Optional `Idempotency-Key` header for replay protection (24h TTL) |
| `POST`   | `/v1/agents/{id}/transactions/sign`                | Sign transaction without broadcasting (returns `signed_tx`, `tx_hash`, `from`)                    |
| `POST`   | `/v1/agents/{id}/sign`                             | Unified signing intent: `personal_sign` (EIP-191), `typed_data` (EIP-712), or `transaction` (types 0–4) |
| `GET`    | `/v1/agents/{id}/transactions`                     | List agent's transactions. `signed_tx` redacted unless `?include_signed_tx=true`                  |
| `GET`    | `/v1/agents/{id}/transactions/{txid}`              | Get transaction details. `signed_tx` redacted unless `?include_signed_tx=true`                    |
| `POST`   | `/v1/agents/{id}/transactions/simulate`            | Simulate single transaction                                                                       |
| `POST`   | `/v1/agents/{id}/transactions/simulate-bundle`     | Simulate transaction bundle                                                                       |
| `POST`   | `/v1/agents/{id}/signing-keys`                     | Provision a multi-chain signing key (`{ chain }`) — human-only                                    |
| `GET`    | `/v1/agents/{id}/signing-keys`                     | List all signing keys for an agent                                                                |
| `POST`   | `/v1/agents/{id}/signing-keys/{chain}/rotate`      | Rotate signing key for a chain — human-only                                                       |
| `DELETE` | `/v1/agents/{id}/signing-keys/{chain}`             | Deactivate signing key for a chain — human-only                                                   |

### Shroud Activity

| Method | Path                       | Description                                          |
| ------ | -------------------------- | ---------------------------------------------------- |
| `GET`  | `/v1/shroud/activity`      | List recent Shroud inspection events                 |
| `POST` | `/v1/shroud/activity`      | Query filtered Shroud activity                       |
| `GET`  | `/v1/shroud/threat-summary`| Shroud threat detection summary                      |

### Audit

| Method | Path                                                  | Description        |
| ------ | ----------------------------------------------------- | ------------------ |
| `GET`  | `/v1/audit/events?limit=N&action=...&from=...&to=...` | Query audit events |

### Billing

| Method  | Path                               | Description                                |
| ------- | ---------------------------------- | ------------------------------------------ |
| `GET`   | `/v1/billing/subscription`         | Subscription status, usage, credit balance |
| `GET`   | `/v1/billing/llm-token-billing`    | LLM add-on status; optional `credit_balance`, `billing_cycle_usage.metered_lines` (Stripe preview) |
| `GET`   | `/v1/billing/credits/balance`      | Credit balance + expiring credits          |
| `GET`   | `/v1/billing/credits/transactions` | Credit transaction ledger                  |
| `PATCH` | `/v1/billing/overage-method`       | Set overage method (`credits` or `x402`)   |
| `GET`   | `/v1/billing/usage`                | Usage summary (current month)              |
| `GET`   | `/v1/billing/history`              | Usage event history                        |

### Chains

| Method | Path                      | Description           |
| ------ | ------------------------- | --------------------- |
| `GET`  | `/v1/chains`              | List supported chains |
| `GET`  | `/v1/chains/{name_or_id}` | Get chain details     |

### Treasury (Safe multisig, agent access)

| Method   | Path                                                                 | Description                                      |
| -------- | -------------------------------------------------------------------- | ------------------------------------------------ |
| `POST`   | `/v1/treasury`                                                       | Create treasury (Safe multisig)                  |
| `GET`    | `/v1/treasury`                                                       | List treasuries                                  |
| `GET`    | `/v1/treasury/{treasury_id}`                                         | Get treasury details                             |
| `PATCH`  | `/v1/treasury/{treasury_id}`                                         | Update name and/or threshold                       |
| `DELETE` | `/v1/treasury/{treasury_id}`                                         | Delete treasury                                    |
| `POST`   | `/v1/treasury/{treasury_id}/signers`                                | Add signer to treasury                           |
| `DELETE` | `/v1/treasury/{treasury_id}/signers/{signer_id}`                     | Remove signer from treasury                      |
| `POST`   | `/v1/treasury/{treasury_id}/access-requests`                         | Request access (agent-only; requires EVM address) |
| `GET`    | `/v1/treasury/{treasury_id}/access-requests`                         | List access requests → `{ requests: [...] }`       |
| `POST`   | `/v1/treasury/{treasury_id}/access-requests/{request_id}/approve`    | Approve access request                           |
| `POST`   | `/v1/treasury/{treasury_id}/access-requests/{request_id}/deny`       | Deny access request                               |

### Other

| Method             | Path                           | Description                                        |
| ------------------ | ------------------------------ | -------------------------------------------------- |
| `GET`              | `/v1/health`                   | Health check → `{ status, service, version }`      |
| `GET`              | `/v1/health/hsm`               | HSM health → `{ status, hsm_provider, connected }` |
| `POST/GET/DELETE`  | `/v1/auth/api-keys[/{id}]`     | Manage personal API keys                           |
| `GET/POST/DELETE`  | `/v1/security/ip-rules[/{id}]` | Manage IP allowlist/blocklist                      |
| `GET/PATCH/DELETE` | `/v1/org/members[/{id}]`       | Manage org members                                 |

---

## SDK Method Reference

All methods return `Promise<OneclawResponse<T>>`. Access via `client.<resource>.<method>(...)`.

| Resource  | Method                                                                                                       | Description                            |
| --------- | ------------------------------------------------------------------------------------------------------------ | -------------------------------------- |
| `vaults`  | `create({ name, description? })`                                                                             | Create vault                           |
| `vaults`  | `get(vaultId)`                                                                                               | Get vault                              |
| `vaults`  | `list()`                                                                                                     | List vaults                            |
| `vaults`  | `delete(vaultId)`                                                                                            | Delete vault                           |
| `secrets` | `set(vaultId, key, value, { type?, metadata?, expires_at?, max_access_count? })`                             | Store/update secret                    |
| `secrets` | `get(vaultId, key)`                                                                                          | Read secret (decrypted)                |
| `secrets` | `list(vaultId, prefix?)`                                                                                     | List secret metadata                   |
| `secrets` | `delete(vaultId, key)`                                                                                       | Delete secret                          |
| `secrets` | `rotate(vaultId, key, newValue)`                                                                             | Rotate secret to new version           |
| `agents`  | `create({ name, description?, scopes?, expires_at?, intents_api_enabled?, token_ttl_seconds?, vault_ids? })` | Create agent → returns agent + api_key |
| `agents`  | `get(agentId)`                                                                                               | Get agent                              |
| `agents`  | `list()`                                                                                                     | List agents                            |
| `agents`  | `update(agentId, { is_active?, scopes?, intents_api_enabled?, tx_*? })`                                      | Update agent                           |
| `agents`  | `delete(agentId)`                                                                                            | Delete agent                           |
| `agents`  | `rotateKey(agentId)`                                                                                         | Rotate agent API key                   |
| `agents`  | `submitTransaction(agentId, { to, value, chain, ... })`                                                      | Submit EVM transaction                 |
| `agents`  | `simulateTransaction(agentId, { to, value, chain, ... })`                                                    | Simulate transaction                   |
| `agents`  | `simulateBundle(agentId, bundle)`                                                                            | Simulate transaction bundle            |
| `agents`  | `getTransaction(agentId, txId)`                                                                              | Get transaction                        |
| `agents`  | `listTransactions(agentId)`                                                                                  | List agent transactions                |
| `agents`  | `signIntent(agentId, { intent_type, chain, message?, typed_data?, tx_type?, ... })`                          | Unified signing (EIP-191, EIP-712, EIP-2718 types 0–4) |
| `signingKeys` | `create(agentId, { chain })`                                                                             | Provision a multi-chain signing key    |
| `signingKeys` | `list(agentId)`                                                                                          | List all signing keys for an agent     |
| `signingKeys` | `rotate(agentId, chain)`                                                                                 | Rotate signing key for a chain         |
| `signingKeys` | `deactivate(agentId, chain)`                                                                             | Deactivate signing key                 |
| `access`  | `grantAgent(vaultId, agentId, permissions, { path?, conditions?, expires_at? })`                             | Grant agent access                     |
| `access`  | `grantHuman(vaultId, userId, permissions, { path?, conditions?, expires_at? })`                              | Grant user access                      |
| `access`  | `listGrants(vaultId)`                                                                                        | List policies                          |
| `access`  | `update(vaultId, policyId, { permissions?, conditions?, expires_at? })`                                      | Update policy                          |
| `access`  | `revoke(vaultId, policyId)`                                                                                  | Revoke policy                          |
| `sharing` | `create(secretId, { recipient_type, recipient_id?, expires_at, max_access_count? })`                         | Create share                           |
| `sharing` | `access(shareId)`                                                                                            | Access shared secret                   |
| `sharing` | `listOutbound()`                                                                                             | Shares you created                     |
| `sharing` | `listInbound()`                                                                                              | Shares sent to you                     |
| `sharing` | `accept(shareId)`                                                                                            | Accept inbound share                   |
| `sharing` | `decline(shareId)`                                                                                           | Decline inbound share                  |
| `sharing` | `revoke(shareId)`                                                                                            | Revoke outbound share                  |
| `audit`   | `query({ action?, actor_id?, from?, to?, limit?, offset? })`                                                 | Query audit events                     |
| `billing` | `usage()`                                                                                                    | Current month usage                    |
| `billing` | `history(limit?)`                                                                                            | Usage event history                    |
| `billing` | `llmTokenBilling()`, `subscribeLlmTokenBilling()`, `disableLlmTokenBilling()`                               | LLM token billing add-on (Stripe AI Gateway) |
| `auth`    | `login({ email, password })`                                                                                 | Human login                            |
| `auth`    | `agentToken({ agent_id, api_key })`                                                                          | Agent JWT exchange                     |
| `auth`    | `logout()`                                                                                                   | Revoke token                           |
| `apiKeys` | `create({ name, scopes?, expires_at? })`                                                                     | Create personal API key                |
| `apiKeys` | `list()`                                                                                                     | List API keys                          |
| `apiKeys` | `revoke(keyId)`                                                                                              | Revoke key                             |
| `chains`  | `list()`                                                                                                     | List supported chains                  |
| `chains`  | `get(identifier)`                                                                                            | Get chain by name or ID                |
| `treasury`| `create({ name, safe_address, chain?, chain_id?, threshold?, signers? })`                                     | Create treasury (Safe multisig)         |
| `treasury`| `list()`, `get(treasuryId)`, `update(treasuryId, { name?, threshold? })`, `delete(treasuryId)`               | List/get/update/delete treasuries      |
| `treasury`| `addSigner(treasuryId, { signer_type, signer_id, signer_address })`                                            | Add signer to treasury                 |
| `treasury`| `removeSigner(treasuryId, signerId)`                                                                         | Remove signer                          |
| `treasury`| `requestAccess(treasuryId, { reason })`                                                                      | Request access (agent-only)            |
| `treasury`| `listAccessRequests(treasuryId)`                                                                             | List access requests                   |
| `treasury`| `approveAccess(treasuryId, requestId)`, `denyAccess(treasuryId, requestId)`                                   | Approve or deny access request        |
| `org`     | `listMembers()`                                                                                              | List org members                       |
| `org`     | `updateMemberRole(userId, role)`                                                                             | Update member role                     |
| `org`     | `removeMember(userId)`                                                                                       | Remove member                          |

### OpenAPI spec for custom SDKs

The API spec is published as an npm package for generating clients in any language:

```bash
npm install @1claw/openapi-spec
```

Ships `openapi.yaml` and `openapi.json`. Use with any OpenAPI 3.1 codegen tool:

```bash
# TypeScript
npx openapi-typescript node_modules/@1claw/openapi-spec/openapi.yaml -o ./types.ts

# Python
openapi-generator generate -i node_modules/@1claw/openapi-spec/openapi.yaml -g python -o ./oneclaw-py

# Go
oapi-codegen -package oneclaw node_modules/@1claw/openapi-spec/openapi.yaml > oneclaw.go
```

SDK also re-exports generated types: `import type { ApiSchemas } from "@1claw/sdk"`.

---

## Supported Chains

Default chain registry (query `GET /v1/chains` for live list):

| Name         | Chain ID | Testnet |
| ------------ | -------- | ------- |
| ethereum     | 1        | no      |
| base         | 8453     | no      |
| optimism     | 10       | no      |
| arbitrum-one | 42161    | no      |
| polygon      | 137      | no      |
| sepolia      | 11155111 | yes     |
| base-sepolia | 84532    | yes     |

Use chain names (e.g. `"base"`, `"sepolia"`) or numeric chain IDs in transaction requests.

---

## Access Control Model

Agents do **not** get blanket access. A human must create a policy to grant an agent access to specific secret paths.

- **Path patterns**: Glob syntax — `api-keys/*`, `db/**`, `**` (all)
- **Permissions**: `read`, `write` (delete requires `write`)
- **Conditions**: IP allowlist, time windows (JSON)
- **Expiry**: Optional ISO 8601 date

If no policy matches → **403 Forbidden**. Vault creators always have full access (owner bypass).

### Vault binding and token scoping

Agents can be restricted beyond policies:

- **`vault_ids`**: Restrict the agent to specific vaults. If non-empty, any request to a vault not in the list returns 403.
- **`token_ttl_seconds`**: Custom JWT expiry per agent (e.g., 300 for 5-minute tokens).
- **Scopes from policies**: JWT scopes are derived from the agent's access policies. If an agent has no policies and no explicit scopes, it has zero access.

Set via dashboard, CLI (`--token-ttl`, `--vault-ids`), SDK, or API.

### Customer-Managed Encryption Keys (CMEK)

Enterprise opt-in feature (Business tier and above). A human generates a 256-bit AES key in the dashboard — the key never leaves their device. Only its SHA-256 fingerprint is stored on the server.

- Enable: `POST /v1/vaults/{id}/cmek` with `{ fingerprint }`
- Disable: `DELETE /v1/vaults/{id}/cmek`
- Rotate: `POST /v1/vaults/{id}/cmek-rotate` (server-assisted, batched in 100s)
- Secrets stored in a CMEK vault have `cmek_encrypted: true` in responses

Agents reading from a CMEK vault receive the encrypted blob. The CMEK key is required to decrypt client-side. This is designed for organizations with compliance requirements — the default HSM encryption is already strong.

### Intents API

When `intents_api_enabled = true` (set by a human):

1. Agent **gains** transaction signing via the Intents API (keys stay in HSM)
2. Agent is **blocked** from reading `private_key` and `ssh_key` secrets directly (403)

Default signing key path: `keys/{chain}-signer`. Override with `signing_key_path` (restricted to `keys/*`, `wallets/*`, `agents/{id}/keys/*`, or `agents/{id}/chains/*` — other paths are rejected to prevent arbitrary secret exfiltration).

#### Multi-chain signing keys (v0.18)

Agents can have per-chain signing keys for 6 blockchains: Ethereum (secp256k1), Bitcoin (secp256k1), Solana (Ed25519), XRP (Ed25519), Cardano (Ed25519), Tron (secp256k1). Private keys stored in `__agent-keys` vault at `agents/{id}/chains/{chain}/private_key`. Provisioned by humans only. Use `provision_signing_key` MCP tool or `client.signingKeys.create()`.

#### Extended signing intents (v0.18)

Unified `POST /v1/agents/{id}/sign` with `intent_type`:
- `personal_sign` — EIP-191 message signing (requires `message_signing_enabled`)
- `typed_data` — EIP-712 typed data signing (deny-by-default; dangerous types like Permit always require `eip712_domain_allowlist`)
- `transaction` — EIP-2718 types 0–4 (legacy, EIP-2930, EIP-1559, EIP-4844, EIP-7702)

Use `sign_message` and `sign_typed_data` MCP tools, or `client.agents.signIntent()`.

#### Replay protection (Idempotency-Key)

Include an `Idempotency-Key: <unique-string>` header on `POST /v1/agents/{id}/transactions`. The server SHA-256 hashes the key and caches the result for 24 hours. Duplicate submissions with the same key return the cached response instead of re-signing and re-broadcasting. If two concurrent requests share a key, one returns 409 (retry after a moment).

#### Server-side nonce serialization

When `nonce` is omitted from a transaction request, the server resolves it automatically via `eth_getTransactionCount` (pending) and serializes concurrent callers with `SELECT FOR UPDATE`. This prevents two in-flight submissions from the same agent+chain+address from receiving the same nonce. You can still pass an explicit `nonce` to override.

#### signed_tx field gating

GET endpoints (`/v1/agents/{id}/transactions` and `/v1/agents/{id}/transactions/{txid}`) **redact** the `signed_tx` field by default to reduce exfiltration risk. To include it, pass `?include_signed_tx=true`. The initial POST response always includes `signed_tx` for the originating caller.

### Transaction guardrails

Human-configured, server-enforced limits on what the Intents API allows:

| Guardrail            | Field                | Effect                                                |
| -------------------- | -------------------- | ----------------------------------------------------- |
| Allowed destinations | `tx_to_allowlist`    | Only listed addresses permitted. Empty = unrestricted |
| Max value per tx     | `tx_max_value_eth`   | Single-tx cap in ETH. NULL = unlimited                |
| Daily spend limit    | `tx_daily_limit_eth` | Rolling 24h cumulative cap. NULL = unlimited          |
| Allowed chains       | `tx_allowed_chains`  | Chain names. Empty = all chains                       |

Agents **cannot** modify their own guardrails. Violations return 403 with a descriptive error.

### OIDC Federation (1Claw as Identity Provider)

1claw publishes a standard OpenID Connect issuer at `https://api.1claw.xyz`, so external relying parties (Anthropic Workload Identity Federation, GCP STS, AWS STS, Stytch, etc.) can validate 1claw-issued JWTs without static API keys.

- **Discovery:** `GET https://api.1claw.xyz/.well-known/openid-configuration` advertises `issuer`, `jwks_uri`, `id_token_signing_alg_values_supported: ["EdDSA","RS256"]`, and grant types incl. `urn:ietf:params:oauth:grant-type:token-exchange`.
- **JWKS:** `GET https://api.1claw.xyz/.well-known/jwks.json` lists every active EdDSA + RS256 KMS key version, each keyed by a deterministic `kid` (`eddsa-vN`, `rs256-vN`). Cached for 5 minutes; CORS `*`.
- **Token exchange:** `POST /v1/auth/federated-token` (RFC 8693). Subject token can be a regular agent JWT or an `ocv_` API key. Returns an **RS256-signed** JWT (HSM-backed RSA 2048) with the requested `aud`. Default TTL 15 min, hard cap 60 min.

**Per-agent guardrails (zero-trust by default):**

| Field                          | Type     | Default | Description                                                            |
| ------------------------------ | -------- | ------- | ---------------------------------------------------------------------- |
| `federation_enabled`           | boolean  | false   | When true, agent may call `/v1/auth/federated-token`                    |
| `federation_audiences`         | string[] | `[]`    | Allowlist of acceptable `aud` values. Empty = deny all federation requests |
| `federated_token_ttl_seconds`  | number?  | null    | Per-agent TTL override (60–3600s). NULL falls back to global default    |

**SDK:**

```typescript
const tokenResp = await client.auth.exchangeFederatedToken({
    audience: "https://api.anthropic.com",
    // subjectToken defaults to current client token / apiKey if omitted
});
console.log(tokenResp.data?.access_token); // RS256 JWT
```

**CLI:**

```bash
1claw auth federated-token --audience https://api.anthropic.com
1claw auth federated-token -a https://api.anthropic.com --raw  # script-friendly
```

**Anthropic WIF flow:**

1. Human enables `federation_enabled = true` and adds Anthropic to `federation_audiences` in the dashboard.
2. Agent calls `POST /v1/auth/federated-token` (or `client.auth.exchangeFederatedToken`) with `audience: "https://api.anthropic.com"`.
3. Agent posts the resulting JWT to Anthropic's WIF endpoint, which returns a short-lived `sk-ant-oat01-…` token.
4. Agent calls Claude with that Anthropic token. **No static `ANTHROPIC_API_KEY` ever leaves 1claw or sits in env.**

End-to-end demo: [`examples/anthropic-wif`](https://github.com/1clawAI/1claw-examples/tree/main/anthropic-wif).

### Shroud per-agent LLM proxy

When `shroud_enabled = true` (set by a human), the agent's LLM traffic is routed through Shroud (`shroud.1claw.xyz`) for secret redaction, PII scrubbing, prompt injection defense, threat detection, and policy enforcement inside a TEE.

`shroud_config` is an optional JSON object that lets humans fine-tune the proxy behavior per agent:

#### Basic settings

| Field                         | Type                                             | Description                                   |
| ----------------------------- | ------------------------------------------------ | --------------------------------------------- |
| `pii_policy`                  | `"block"` \| `"redact"` \| `"warn"` \| `"allow"` | How PII in LLM traffic is handled             |
| `injection_threshold`         | number (0.0–1.0)                                 | Prompt injection detection sensitivity        |
| `context_injection_threshold` | number (0.0–1.0)                                 | Context injection detection sensitivity       |
| `allowed_providers`           | string[]                                         | LLM providers the agent may use (empty = all) |
| `allowed_models`              | string[]                                         | Models the agent may use (empty = all)        |
| `denied_models`               | string[]                                         | Models explicitly blocked                     |
| `max_tokens_per_request`      | number                                           | Token cap per LLM request                     |
| `max_requests_per_minute`     | number                                           | Per-minute rate limit                         |
| `max_requests_per_day`        | number                                           | Per-day rate limit                            |
| `daily_budget_usd`            | number                                           | Daily LLM spend cap in USD                    |
| `enable_secret_redaction`     | boolean                                          | Redact vault secrets from LLM context         |
| `enable_response_filtering`   | boolean                                          | Filter sensitive data from LLM responses      |

#### Threat detection settings

Multi-layered detection for prompt injection, command injection, social engineering, and data exfiltration attempts:

| Field                          | Type   | Description                                                         |
| ------------------------------ | ------ | ------------------------------------------------------------------- |
| `unicode_normalization`        | object | Homoglyph/zero-width character normalization (see below)            |
| `command_injection_detection`  | object | Detect shell commands, path traversal, reverse shells               |
| `social_engineering_detection` | object | Detect urgency, authority claims, secrecy requests, bypass attempts |
| `encoding_detection`           | object | Detect base64, hex, Unicode escapes that may hide payloads          |
| `network_detection`            | object | Detect blocked domains, IP URLs, data exfiltration patterns         |
| `filesystem_detection`         | object | Detect sensitive paths (/etc/passwd, .ssh/, .env, etc.)             |
| `sanitization_mode`            | string | `"block"` (reject threats), `"surgical"` (strip), `"log_only"` (log) |
| `threat_logging`               | boolean| Log detected threats for audit (default: true)                      |

**Extended inspection pipeline** — Beyond the threat detectors above, `shroud_config` also supports: `tool_call_inspection` (scan function/tool call arguments, block credential exfiltration — `block_credential_exfil` defaults to **`true`**), `output_policy` (block harmful content, patterns, and entities in LLM responses), `secret_injection_detection` (detect secrets injected into prompts/responses), `advanced_redaction` (detect base64-encoded, split, or prefix-leaked secrets), and `semantic_policy` (enforce allowed/denied topics and tasks at the intent level). `flagged_request_retention_days` controls how long flagged requests are retained. Dashboard: `/shroud-activity` (overview), `/shroud-activity/threats`, `/shroud-activity/live` (real-time inspector).

**Bi-directional inspection (Shroud v0.5.0+)** — The inspection pipeline runs on the LLM **response** as well as the request. Response-side detectors catch: echoed / indirect prompt injection (model paraphrases "ignore previous instructions"), markdown-image exfil (`![x](https://evil/?token=…)`), data-URI exec blobs (`data:text/html;base64,…`), unexpected fenced code blocks (when `semantic_policy.allowed_tasks` does not include `code`), and exfil URLs in model output. Populates new audit fields: `response_injection_score`, `response_context_injection_score`, `response_injection_categories`, `external_urls_flagged`, `unexpected_code_blocks`. Default action: `Block` when score ≥ 0.7 and `output_policy.action = "block"`.

**`unicode_normalization` object:**

| Field                | Type    | Default | Description                                    |
| -------------------- | ------- | ------- | ---------------------------------------------- |
| `enabled`            | boolean | true    | Enable Unicode normalization                   |
| `strip_zero_width`   | boolean | true    | Remove zero-width characters (U+200B, U+200C)  |
| `normalize_homoglyphs` | boolean | true | Convert look-alike characters (Cyrillic а → a) |
| `normalization_form` | string  | `"NFKC"` | Unicode form: `"NFC"`, `"NFKC"`, `"NFD"`, `"NFKD"` |

**`command_injection_detection` object:**

| Field       | Type   | Default   | Description                                    |
| ----------- | ------ | --------- | ---------------------------------------------- |
| `action`    | string | `"block"` | `"block"`, `"sanitize"`, or `"warn"`           |
| `strictness`| string | `"default"` | `"strict"` (more patterns), `"default"`, `"relaxed"` |

**`social_engineering_detection` object:**

| Field       | Type   | Default  | Description                              |
| ----------- | ------ | -------- | ---------------------------------------- |
| `action`    | string | `"warn"` | `"block"` or `"warn"`                    |
| `sensitivity` | string | `"medium"` | `"low"` (more triggers), `"medium"`, `"high"` |

**`encoding_detection` object:**

| Field          | Type    | Default | Description                           |
| -------------- | ------- | ------- | ------------------------------------- |
| `action`       | string  | `"warn"` | `"block"`, `"decode"`, or `"warn"`   |
| `detect_base64`| boolean | true    | Detect base64 encoded content         |
| `detect_hex`   | boolean | true    | Detect \xNN hex escapes               |
| `detect_unicode` | boolean | true  | Detect \uNNNN Unicode escapes         |

**`network_detection` object:**

| Field             | Type     | Default                  | Description                        |
| ----------------- | -------- | ------------------------ | ---------------------------------- |
| `action`          | string   | `"warn"`                 | `"block"` or `"warn"`              |
| `blocked_domains` | string[] | pastebin, ngrok, etc.    | Domains to block (subdomains auto) |
| `allowed_domains` | string[] | []                       | Allowlist (empty = blocklist mode) |

**`filesystem_detection` object:**

| Field          | Type     | Default              | Description                       |
| -------------- | -------- | -------------------- | --------------------------------- |
| `action`       | string   | `"log"`              | `"block"`, `"sanitize"`, or `"log"` |
| `blocked_paths`| string[] | /etc/passwd, .ssh/, .env, etc. | Paths to detect            |

**SDK:**

```typescript
await client.agents.create({
    name: "my-agent",
    shroud_enabled: true,
    shroud_config: {
        pii_policy: "redact",
        injection_threshold: 0.8,
        allowed_providers: ["openai", "anthropic"],
        max_requests_per_day: 1000,
        daily_budget_usd: 10.0,
        enable_secret_redaction: true,
        // Threat detection
        unicode_normalization: { enabled: true, normalize_homoglyphs: true },
        command_injection_detection: { action: "block", strictness: "default" },
        social_engineering_detection: { action: "warn", sensitivity: "medium" },
        encoding_detection: { action: "warn", detect_base64: true },
        network_detection: { action: "warn", blocked_domains: ["pastebin.com"] },
        filesystem_detection: { action: "log" },
        sanitization_mode: "block",
        threat_logging: true,
    },
});

await client.agents.update(agentId, {
    shroud_enabled: true,
    shroud_config: { pii_policy: "block", injection_threshold: 0.9 },
});
```

**CLI:**

```bash
1claw agent create my-agent --shroud
1claw agent update <agent-id> --shroud true
1claw agent update <agent-id> --shroud false
```

**MCP:** When `shroud_enabled` is true, the agent can send LLM requests through `shroud.1claw.xyz`. Vault puts `shroud_config` on the **agent JWT**; Shroud applies it in **PolicyEngine** after the inspection pipeline (re-exchange credentials after changing Shroud settings). MCP vault tools are unchanged; LLM traffic does not go through MCP.

---

## Share with Your Human

Agents can share secrets back with the human who created or enrolled them. Use `recipient_type: "creator"` — no email or user ID needed.

**Via MCP:**

```
share_secret(secret_id: "...", recipient_type: "creator", expires_at: "2026-12-31T00:00:00Z")
```

**Via SDK:**

```typescript
await client.sharing.create(secretId, {
    recipient_type: "creator",
    expires_at: "2026-12-31T00:00:00Z",
    max_access_count: 5,
});
```

The human sees the share in their Inbound shares and accepts it. This is the primary pattern for agents that discover or generate credentials and need to report them to their human.

---

## Fleet Patterns

When many agents operate in the same organization:

- **Vault organization:** Use a shared vault with path-scoped policies (e.g. `agents/{name}/**`) or per-agent vaults for strict isolation.
- **Bulk provisioning:** Use the authenticated `POST /v1/agents` endpoint with a human API key to create many agents, or stagger self-enrollment calls to respect the 10-min per-email cooldown.
- **Vault binding:** Set `vault_ids` on each agent to restrict JWT scope beyond what policies allow.
- **Token TTL:** Shorten to 5 min for ephemeral tasks (`token_ttl_seconds: 300`), keep default 1h for long-running agents.
- **Transaction guardrails:** Apply `tx_max_value_eth`, `tx_daily_limit_eth`, and `tx_allowed_chains` to all Intents API agents.
- **Monitoring:** Filter the audit log by agent ID to track per-agent activity. Use `billing usage` to monitor org-wide consumption.

---

## Security Model

- **Credentials are configured by the human**, not the agent. The MCP server reads them from env vars.
- **The agent never sees its own credentials.** The MCP server authenticates on the agent's behalf.
- **Access is deny-by-default.** Even with valid credentials, only policy-allowed secrets are accessible.
- **Secret values are fetched just-in-time** and must never be stored, echoed, or included in summaries.
- **Agents cannot create email-based shares** (prevents unsolicited email sharing).
- **Intents API is opt-in.** When enabled, raw key reads are blocked.
- **Transaction guardrails are human-controlled and server-enforced.**
- **Token revocation:** `DELETE /v1/auth/token` (or SDK `auth.logout()`) revokes the current Bearer token; revoked tokens return 401.
- **Agent token auto-revocation:** When a policy is created, updated, or deleted for an agent, all active JWTs for that agent are revoked immediately (stale-scope protection via `agent_active_tokens` table).
- **KMS key rotation scheduling:** GCP KMS keys support scheduled automatic rotation; production uses HSM protection level (`protection_level: 2`).
- **CRC32C integrity verification:** KMS encrypt/decrypt responses are verified with CRC32C checksums to detect data corruption in transit.
- **Audit insert hardening:** Direct `INSERT` on `audit_events` is revoked from the application DB role; all audit writes go through a `SECURITY DEFINER` function (`insert_audit_event`) to prevent RLS bypass.
- **Account lockout:** 10 failed login attempts → 15-minute lock per user; resets on success.
- **Session revocation:** Password change or reset invalidates all existing JWTs for the user (`revoked_before` column).
- **Agent self-update guard:** Agents cannot `PATCH /v1/agents/{id}` on their own record — only human callers can modify agent settings.
- **x402 unauthenticated amount verification:** The x402 middleware verifies payment amounts even for unauthenticated requests, preventing underpayment on public paid routes.
- **Request body limit:** 5MB max; larger requests return 413.

---

## Scaling & Performance (v0.17)

- **Database pool**: Configurable via `ONECLAW_POOL_MAX_CONNECTIONS` (default 5), `ONECLAW_POOL_MIN_CONNECTIONS` (default 0). Set `ONECLAW_POOL_DISABLE_STMT_CACHE=1` for Supavisor transaction-mode. Pool stats logged every 30s.
- **Rate limiting**: Two-layer — in-memory L1 + optional Redis L2 (`ONECLAW_REDIS_URL`).
- **DEK cache**: 60s TTL, 1000-entry DashMap cache for unwrapped DEKs. Cuts KMS calls ~80%.
- **Usage batching**: Events buffered in memory, batch-INSERTs every 5s or 100 events.
- **Manifest optimization**: `ETag`/`304` and `?since=` on `GET /v1/admin/secrets/manifest`.
- **Cron leader election**: `pg_try_advisory_lock` prevents duplicate nightly jobs across replicas.
- **Quota header caching**: 30s TTL per-org cache eliminates per-request DB lookups.
- **Nonce serialization**: Shroud calls `POST /v1/admin/nonces/reserve` for DB-backed atomic nonce reservation (eliminates multi-pod collisions).
- **HPA**: Custom `shroud_requests_per_second` metric via prometheus-adapter.

---

## Error Handling

| Code | Meaning                                                    | Action                                                                                                                                                                                            |
| ---- | ---------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 400  | Bad request                                                | Check request body format                                                                                                                                                                         |
| 401  | Not authenticated                                          | Token expired — re-authenticate                                                                                                                                                                   |
| 402  | Quota exhausted / payment required                         | Body may include `required_usd`, `message`. Intents submit over quota: 0.25% of tx value; top up credits or send X-PAYMENT for required amount. Otherwise upgrade at `1claw.xyz/settings/billing` |
| 403  | No permission                                              | Ask user to grant access via a policy. Or: guardrail violation (check error detail)                                                                                                               |
| 403  | Resource limit reached (`type: "resource_limit_exceeded"`) | Tier limit on vaults/secrets/agents hit — ask user to upgrade at `1claw.xyz/settings/billing`                                                                                                     |
| 404  | Not found                                                  | Check path with `list_secrets`                                                                                                                                                                    |
| 405  | Method not allowed                                         | Wrong HTTP verb for this endpoint                                                                                                                                                                 |
| 409  | Conflict                                                   | Resource already exists (e.g. duplicate vault name)                                                                                                                                               |
| 410  | Gone                                                       | Secret expired or max access count reached — ask user to store a new version                                                                                                                      |
| 422  | Validation error or simulation reverted                    | Check input. For `simulate_first`: transaction would revert                                                                                                                                       |
| 413  | Payload too large                                          | Request body over 5MB — reduce payload size                                                                                                                                                       |
| 429  | Rate limited / account locked                              | Wait and retry. Auth routes: 5 req burst, 1/sec. Share creation: 10/min/org. Login lockout: 15 min after 10 failed attempts                                                                       |

All error responses include a `detail` field with a human-readable message.

---

## Best Practices

1. **Fetch secrets just-in-time.** Call `get_secret` immediately before the API call that needs the credential.
2. **Never echo secret values.** Say "I retrieved the API key and used it" — never include raw values in responses.
3. **Use `describe_secret` first** to check existence or validity before fetching the full value.
4. **Use `list_secrets` to discover** available credentials before guessing paths.
5. **Rotate after regeneration.** If you regenerate an API key at a provider, immediately `rotate_and_store` the new value.
6. **Use `grant_access` for vault-level sharing** — creates a fine-grained policy with path patterns.
7. **Use `share_secret` for one-off sharing** — creates a time-limited, access-counted share link.
8. **Simulate before signing.** Always use `simulate_first: true` (default) or call `simulate_transaction` before `submit_transaction`.
9. **Check `list_vaults` before creating.** Avoid creating duplicate vaults.
10. **Handle 402 gracefully.** Billing/quota errors should be surfaced to the user, not retried.

---

## Billing Tiers

| Tier       | Requests/mo | Vaults    | Secrets   | Agents    | Price                                        |
| ---------- | ----------- | --------- | --------- | --------- | -------------------------------------------- |
| Free       | 1,000       | 3         | 50        | 2         | $0                                           |
| Pro        | 25,000      | 25        | 500       | 10        | $29/mo                                       |
| Team       | 100,000     | 100       | 5,000     | 50        | $299/mo (SSO)                                |
| Business   | 500,000     | Unlimited | Unlimited | 200       | $999/mo (+ CMEK, Intents, Shroud Enterprise) |
| Enterprise | Custom      | Unlimited | Unlimited | Unlimited | Contact                                      |

Overage methods: **prepaid credits** (top up via Stripe, deducted per request) or **x402 micropayments** (per-query on-chain payments on Base).

Audit, org, security, chain, billing, and auth endpoints are **free and never consume quota**.

---

## Links

- Dashboard: [1claw.xyz](https://1claw.xyz)
- Docs: [docs.1claw.xyz](https://docs.1claw.xyz)
- Status: [1claw.xyz/status](https://1claw.xyz/status)
- API: `https://api.1claw.xyz`
- SDK: [@1claw/sdk on npm](https://www.npmjs.com/package/@1claw/sdk)
- OpenAPI Spec: [@1claw/openapi-spec on npm](https://www.npmjs.com/package/@1claw/openapi-spec)
- MCP Server: [@1claw/mcp on npm](https://www.npmjs.com/package/@1claw/mcp)
- CLI: [@1claw/cli on npm](https://www.npmjs.com/package/@1claw/cli)
- GitHub: [github.com/1clawAI](https://github.com/1clawAI)
- Support: [ops@1claw.xyz](mailto:ops@1claw.xyz)