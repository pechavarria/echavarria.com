# echavarria.com

Personal website. Static, no build step.

- **Host:** Cloudflare Pages, deployed from `main` (repo stays private)
- **Registrar:** Porkbun; DNS delegated to Cloudflare
- **Source:** `index.html` is self-contained (inline CSS)

## Deploy

```
git add -A
git commit -m "..."
git push
```

Cloudflare builds and publishes automatically. No build command, output directory is the repo root.
