# Plume Static Support Site

This directory contains the public support and privacy pages for Plume.

Live App Store URLs:

- `https://plume.turfterrace.com/support/`
- `https://plume.turfterrace.com/privacy/`

Cloudflare Pages settings:

- Project name: `plume`
- Production hostname: `plume-aep.pages.dev`
- Project root: `site`
- Build command: none
- Build output directory: `.`
- Production custom domain: `plume.turfterrace.com`
- Fallback Pages hostname: `plume-aep.pages.dev`

Deploy command:

```bash
wrangler pages deploy site --project-name plume --branch main --commit-hash "$(git rev-parse --short HEAD)" --commit-message "Deploy Plume App Store support and privacy pages" --commit-dirty=true
```

DNS is configured with a proxied CNAME from `plume.turfterrace.com` to `plume-aep.pages.dev`. Cloudflare Pages validation is active, and `/support/` plus `/privacy/` return `200`.

The pages intentionally avoid JavaScript, analytics, cookies, external embeds, and third-party assets so they stay aligned with Plume's App Store privacy posture.
