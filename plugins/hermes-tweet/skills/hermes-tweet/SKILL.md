---
name: hermes-tweet
description: Use Hermes Tweet for Hermes Agent X/Twitter workflows with read-first endpoint discovery, approval-gated actions, and safe runtime configuration.
---

# Hermes Tweet

Use Hermes Tweet when a Claude Code session needs to prepare, validate, or operate Hermes Agent workflows for X/Twitter through Xquik.

## When to Use

Use this skill for social listening, launch monitoring, support triage, creator research, brand research, giveaway audits, community audits, and controlled publishing workflows.

Use `tweet_explore` first when the user asks for a capability, endpoint, route, or Xquik API surface. Use `tweet_read` only after a read-only endpoint is known. Use `tweet_action` only after the user requests a write, private read, monitor, webhook, extraction job, giveaway draw, or media operation that requires action permissions.

## Workflow

1. Use `tweet_explore` to find the endpoint.
2. Use `tweet_read` for public read-only endpoints.
3. Use `tweet_action` only for writes or private reads after stating the exact endpoint and payload.

## Decision Rules

- IF the task is endpoint discovery, THEN call `tweet_explore` with a short query.
- IF the endpoint method is `GET` and the catalog does not mark it as an action, THEN call `tweet_read`.
- IF the endpoint method is not `GET`, or the route touches private account state, THEN call `tweet_action` only when actions are enabled and the user has approved the operation.
- IF `tweet_action` is unavailable or disabled, THEN explain that action tools are intentionally gated by `HERMES_TWEET_ENABLE_ACTIONS=true`.
- IF `XQUIK_API_KEY` is missing, THEN ask the user to set it in the Hermes runtime environment without requesting the key value in chat.
- IF Hermes lists the plugin as `not enabled`, THEN tell the user to run `hermes plugins enable hermes-tweet` or reinstall with `--enable`.

## Safety

- Never ask for or reveal API keys, signing keys, passwords, cookies, or TOTP secrets.
- Never pass credentials in tool arguments.
- Use only catalog-listed `/api/v1/...` endpoints.
- Copied endpoint URLs are accepted only when they resolve to catalog-listed paths.
- Do not use account connection, re-authentication, API key, billing, credit top-up, or support-ticket endpoints.
- For posting, deleting, following, DMs, profile changes, monitors, webhooks, extraction jobs, and draws, summarize the action before calling `tweet_action`.

## Pitfalls

- Do not guess endpoint paths. Always use the catalog returned by `tweet_explore`.
- Do not treat a slash command prompt as proof that Hermes registered the command. Verify slash commands through an active Hermes session or plugin registry test.
- Do not use bare `hermes tools` for scripted diagnostics. Run `hermes tools list` instead.
- Do not assume installation means execution. Current Hermes Agent versions discover third-party plugins before they are enabled.
- Do not retry writes through alternate routes after a policy, auth, or account state error.
- Do not include secrets in examples, logs, prompts, issue bodies, or tool input.

## Testing

After installing or upgrading the upstream Hermes Tweet plugin in Hermes Agent:

1. Run `hermes plugins enable hermes-tweet` unless the install used `--enable`.
2. Run `hermes plugins list` and confirm the plugin is `enabled`.
3. Run `hermes tools list` and confirm the `hermes-tweet` toolset is enabled.
4. Confirm `tweet_explore` is available without `XQUIK_API_KEY`.
5. Confirm `tweet_read` appears only when `XQUIK_API_KEY` is configured.
6. Confirm `tweet_action` stays hidden or disabled unless `HERMES_TWEET_ENABLE_ACTIONS=true`.
