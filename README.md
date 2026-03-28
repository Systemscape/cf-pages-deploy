# Cloudflare Pages Deploy

Composite action for Forgejo that deploys to Cloudflare Pages and posts a preview URL comment on pull requests — replicating the GitHub-native Cloudflare Pages integration.

## Usage

```yaml
- name: Deploy to Cloudflare Pages
  uses: https://github.com/Systemscape/cf-pages-deploy@v1
  with:
    cloudflare-api-token: ${{ secrets.CLOUDFLARE_API_TOKEN }}
    cloudflare-account-id: ${{ secrets.CLOUDFLARE_ACCOUNT_ID }}
    project-name: my-site
    directory: public
```

On pull requests, the action automatically comments (or updates) a preview URL on the PR:

> ### Cloudflare Pages Preview
>
> | | |
> |---|---|
> | **Preview URL** | https://my-branch.my-site.pages.dev |
> | **Commit** | `abc1234` |
> | **Environment** | preview |

## Inputs

| Input | Required | Default | Description |
|---|---|---|---|
| `cloudflare-api-token` | Yes | | Cloudflare API token with Pages permissions |
| `cloudflare-account-id` | Yes | | Cloudflare account ID |
| `project-name` | Yes | | Cloudflare Pages project name |
| `directory` | Yes | | Directory of static assets to deploy |
| `forgejo-token` | No | `${{ github.token }}` | Forgejo API token for PR comments |
| `comment-marker` | No | `<!-- cf-pages-deploy -->` | HTML comment marker for idempotent comment updates |

## Caching wrangler

The action installs wrangler via `npm ci` on each run. To avoid re-downloading it every time, cache the npm store before this action runs:

```yaml
- uses: actions/cache@v4
  with:
    path: ~/.npm
    key: ${{ runner.os }}-npm-wrangler
```

With a warm cache, the `npm ci` step takes a couple of seconds instead of downloading wrangler from the registry.

## Outputs

| Output | Description |
|---|---|
| `deployment-url` | The deployment URL (hash-based, e.g. `https://abc123.my-site.pages.dev`) |
| `deployment-alias-url` | Branch-specific alias URL (e.g. `https://my-branch.my-site.pages.dev`) |
| `environment` | `production` or `preview` |

## Full workflow example

```yaml
name: Build and deploy

on:
  push:
    branches: [main]
  pull_request:

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: actions/cache@v4
        with:
          path: ~/.npm
          key: ${{ runner.os }}-npm-wrangler

      - name: Build
        uses: https://github.com/shalzz/zola-deploy-action@v0.21.0
        env:
          BUILD_ONLY: true
          OUT_DIR: public

      - name: Deploy to Cloudflare Pages
        uses: https://github.com/Systemscape/cf-pages-deploy@v1
        with:
          cloudflare-api-token: ${{ secrets.CLOUDFLARE_API_TOKEN }}
          cloudflare-account-id: ${{ secrets.CLOUDFLARE_ACCOUNT_ID }}
          project-name: my-site
          directory: public
```

## Setting up the Cloudflare API token

1. Go to the [Cloudflare dashboard API tokens page](https://dash.cloudflare.com/profile/api-tokens)
2. Create a token with the **Cloudflare Pages: Edit** permission
3. Add the token as a secret named `CLOUDFLARE_API_TOKEN` in your Forgejo repository settings

## How it works

1. **Deploy**: Runs `wrangler pages deploy` with the correct `--branch` derived from the CI environment (PR source branch or push branch), avoiding the detached-HEAD alias URL issue common in CI
2. **Comment**: On pull request events, creates or updates a comment on the PR with the preview URL using the Forgejo API. Uses an HTML comment marker to find and update existing comments instead of creating duplicates

## Requirements

The runner image must have `curl`, `jq`, and `node`/`npm` installed.
