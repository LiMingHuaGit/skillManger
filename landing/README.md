# Skill Manager landing page

Static product landing page for `https://skill-manager.liminghua.fyi/`.

## Local preview

```bash
python3 -m http.server 4173 --directory landing
```

## Deploy

Run from this directory with the locally authenticated Wrangler CLI:

```bash
wrangler deploy
```

The custom domain is declared in `wrangler.jsonc` and is hosted through Cloudflare Workers Static Assets.
