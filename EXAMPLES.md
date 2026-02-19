# 1Claw Skill — Example Conversations

## Example 1: Fetching an API key for an external service

**User:** "Use the Stripe API to check my account balance"

**Agent thinking:** I need the Stripe API key. Let me check what's available in the vault.

```
→ list_secrets(prefix: "api-keys/")
Found 2 secret(s):
- api-keys/stripe  (type: api_key, version: 3)
- api-keys/openai  (type: api_key, version: 1)
```

```
→ get_secret(path: "api-keys/stripe")
{"path":"api-keys/stripe","type":"api_key","version":3,"value":"sk_live_..."}
```

**Agent:** "I retrieved your Stripe API key and checked your account. Your current balance is $1,234.56."

(The raw key value is never shown to the user.)

## Example 2: Storing a newly generated credential

**User:** "I just created a new Twilio account. Here's my API key: SK1234567890abcdef. Store it securely."

```
→ put_secret(path: "api-keys/twilio", value: "SK1234567890abcdef", type: "api_key", metadata: {"provider": "twilio"})
Secret stored at 'api-keys/twilio' (version 1, type: api_key).
```

**Agent:** "Done — I stored your Twilio API key securely in the vault at `api-keys/twilio`. You can access it anytime."

## Example 3: Sharing a secret with a teammate

**User:** "Share the database password with alice@company.com"

```
→ list_secrets(prefix: "passwords/")
Found 1 secret(s):
- passwords/production-db  (type: password, version: 2, id: cf592...)
```

```
→ share_secret(secret_id: "cf592...", email: "alice@company.com", expires_at: "2026-04-01T00:00:00Z", max_access_count: 5)
Secret shared with alice@company.com. Share ID: df703...
```

**Agent:** "I shared the production database password with alice@company.com. She'll receive an email and can access it after signing in. The share expires April 1 and allows up to 5 accesses."

## Example 4: Rotating a key after regeneration

**User:** "I regenerated my OpenAI API key. The new one is sk-proj-newkey123"

```
→ rotate_and_store(path: "api-keys/openai", value: "sk-proj-newkey123")
Rotated secret at 'api-keys/openai'. New version: 2.
```

**Agent:** "Updated — the OpenAI API key in the vault is now version 2 with your new key."

## Example 5: Loading environment variables

**User:** "Set up the production environment for the deploy script"

```
→ get_env_bundle(path: "config/prod-env")
{
  "DATABASE_URL": "postgres://...",
  "REDIS_URL": "redis://...",
  "API_KEY": "sk_..."
}
```

**Agent:** "I loaded 3 environment variables from the production config. The deploy script is ready to run."
