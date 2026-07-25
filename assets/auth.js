// Client-side access gate.
//
// NOTE: this is obscurity, not security. The repo is public, so every page
// behind this gate is readable directly at its URL by anyone who looks.
// Treat it as a "please don't wander in", not as protection.
//
// To change the code, replace CODE_HASH with the SHA-256 of the new code:
//   PowerShell:
//     $c='newcode'
//     $s=[Security.Cryptography.SHA256]::Create()
//     (($s.ComputeHash([Text.Encoding]::UTF8.GetBytes($c))|%{$_.ToString('x2')})-join'')

const CODE_HASH = '33e4b311390fb53f9d79540d2127011178afbdfa334a77b942a22ac962022efd';

const STORE_KEY = 'echavarria.access';

async function sha256(text) {
  const bytes = new TextEncoder().encode(text);
  const digest = await crypto.subtle.digest('SHA-256', bytes);
  return [...new Uint8Array(digest)].map(b => b.toString(16).padStart(2, '0')).join('');
}

// Storing the hash itself means changing the code invalidates old sessions.
function isUnlocked() {
  try {
    return localStorage.getItem(STORE_KEY) === CODE_HASH;
  } catch {
    return false;
  }
}

function unlock() {
  try {
    localStorage.setItem(STORE_KEY, CODE_HASH);
  } catch {
    // Private browsing with storage blocked — the session just won't persist.
  }
}

function lock() {
  try {
    localStorage.removeItem(STORE_KEY);
  } catch {
    /* nothing to clean up */
  }
}

// Bounce to the login screen unless already unlocked. Called by gated pages.
function requireAccess() {
  if (!isUnlocked()) {
    location.replace('index.html');
  }
}

// Wire up the login form on index.html.
function initLogin({ form, input, error, next }) {
  if (isUnlocked()) {
    location.replace(next);
    return;
  }

  form.addEventListener('submit', async event => {
    event.preventDefault();
    error.textContent = '';

    const entered = input.value.trim();
    if (!entered) return;

    if (await sha256(entered) === CODE_HASH) {
      unlock();
      location.replace(next);
    } else {
      error.textContent = 'Código incorrecto. Intenta de nuevo.';
      input.value = '';
      input.focus();
    }
  });
}
