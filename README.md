# echavarria.com

Family site. Static, no build step.

- **Host:** GitHub Pages, `main` / root
- **Registrar:** Porkbun (DNS stays at Porkbun; apex A/AAAA point at GitHub Pages)
- **Live:** https://echavarria.com (HTTPS enforced)

## Pages

| File | Purpose |
|---|---|
| `index.html` | Access-code screen |
| `home.html` | Four family buttons |
| `papati.html` `mamati.html` `pablito.html` `sofiti.html` | Per-person pages |
| `assets/style.css` | Shared styles (light/dark aware) |
| `assets/auth.js` | Gate logic, session, page guard |

## The access code

The gate is **obscurity, not security**. This repo is public, so every page
behind it is readable directly at its URL. Don't put anything private here.

`assets/auth.js` stores only a SHA-256 hash of the code. To change it:

```powershell
$c = 'newcode'
$s = [Security.Cryptography.SHA256]::Create()
(($s.ComputeHash([Text.Encoding]::UTF8.GetBytes($c)) | % { $_.ToString('x2') }) -join '')
```

Paste the result into `CODE_HASH`. Changing it also invalidates everyone's
saved session, since the stored token *is* the hash.

## Deploy

```
git add -A
git commit -m "..."
git push
```

Live in ~30 seconds.
