#!/bin/bash
# Generate index.html for the xbps Void package repository
set -euo pipefail

PUBLIC_DIR="${1:?Usage: $0 <public-directory>}"

[ -d "$PUBLIC_DIR" ] || { echo "Error: directory '$PUBLIC_DIR' not found"; exit 1; }

OUT="$PUBLIC_DIR/index.html"

extract() {
  local file="$1" key="$2"
  grep -E "^${key}=" "$file" 2>/dev/null | head -1 | sed -E "s/^${key}=//; s/^\"//; s/\"$//"
}

# Build set of pkgnames that have an xbps in PUBLIC_DIR
declare -A BUILT
while IFS= read -r f; do
  name=$(basename "$f")
  stripped="${name%.x86_64.xbps}"
  stripped="${stripped%.aarch64.xbps}"
  stripped="${stripped%.noarch.xbps}"
  pkgname="${stripped%-*}"
  BUILT["$pkgname"]=1
done < <(find "$PUBLIC_DIR" -maxdepth 1 -type f -name '*.xbps' 2>/dev/null)

# Read all package templates and separate built vs not built
BUILT_PKGS=()
AVAIL_PKGS=()
while IFS= read -r template; do
  pkgdir=$(dirname "$template")
  pkgname=$(basename "$pkgdir")
  desc=$(extract "$template" short_desc)
  [ -n "$desc" ] || continue
  if [ "${BUILT["$pkgname"]+set}" = "set" ]; then
    BUILT_PKGS+=("$template")
  else
    AVAIL_PKGS+=("$template")
  fi
done < <(find pkgs/ -mindepth 2 -maxdepth 2 -name template -type f | sort)

cat > "$OUT" << 'HTML'
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>xbps - void packages</title>
<style>
  *,*::before,*::after{box-sizing:border-box;margin:0;padding:0}

  :root {
    --bg: #0d1117;
    --bg-alt: #161b22;
    --surface: #1c2128;
    --border: #30363d;
    --text: #e6edf3;
    --text-muted: #8b949e;
    --green: #3fb950;
    --cyan: #58a6ff;
    --orange: #d29922;
    --red: #f85149;
    --radius: 8px;
  }

  html { scroll-behavior: smooth; }

  ::selection { background: rgba(88,166,255,0.25); }
  ::-webkit-scrollbar { width: 6px; }
  ::-webkit-scrollbar-track { background: transparent; }
  ::-webkit-scrollbar-thumb { background: var(--border); border-radius: 3px; }

  body {
    font-family: 'SF Mono','Cascadia Code','Fira Code','JetBrains Mono','Consolas',monospace;
    background: #010409;
    color: var(--text);
    min-height: 100vh;
    display: flex;
    align-items: center;
    justify-content: center;
    padding: 24px;
    line-height: 1.65;
    font-size: 14px;
  }

  .terminal {
    width: 100%;
    max-width: 820px;
    background: var(--bg);
    border: 1px solid var(--border);
    border-radius: 12px;
    overflow: hidden;
    box-shadow: 0 16px 64px rgba(0,0,0,0.5);
  }

  .term-bar {
    display: flex;
    align-items: center;
    gap: 10px;
    padding: 12px 16px;
    background: var(--bg-alt);
    border-bottom: 1px solid var(--border);
    user-select: none;
  }
  .term-title {
    font-size: 0.8rem;
    color: var(--text-muted);
    margin-left: 6px;
    flex: 1;
    text-align: center;
  }

  .term-body {
    padding: 28px 28px 20px;
    overflow-x: hidden;
  }

  .line {
    margin-bottom: 6px;
    display: flex;
    flex-wrap: wrap;
    align-items: baseline;
    gap: 8px;
  }
  .line .prompt {
    color: var(--green);
    user-select: none;
    flex-shrink: 0;
  }
  .line .cmd {
    color: var(--cyan);
  }

  .output {
    display: block;
    margin: 2px 0 18px 0;
    padding-left: 0;
  }
  .output p {
    color: var(--text-muted);
    margin: 0 0 4px;
  }
  .output p strong {
    color: var(--text);
    font-weight: 600;
  }

  .divider {
    border: none;
    border-top: 1px solid var(--border);
    margin: 24px 0;
  }

  pre {
    background: var(--surface);
    border: 1px solid var(--border);
    border-radius: var(--radius);
    padding: 14px 16px;
    overflow-x: auto;
    margin: 8px 0 12px;
    font-size: 0.85rem;
  }
  pre code {
    font-family: inherit;
    color: var(--green);
    line-height: 1.6;
    white-space: pre;
  }
  pre code .prompt {
    color: var(--text-muted);
    user-select: none;
    margin-right: 6px;
  }
  pre code .hl-string {
    color: var(--orange);
  }

  .fingerprint {
    margin: 10px 0 0;
    padding: 12px 16px;
    background: var(--surface);
    border: 1px solid var(--border);
    border-radius: var(--radius);
    font-size: 0.8rem;
    line-height: 1.7;
    word-break: break-all;
  }
  .fingerprint .label {
    color: var(--text-muted);
    user-select: none;
  }
  .fingerprint .signer {
    color: var(--cyan);
    font-weight: 600;
  }
  .fingerprint .key {
    display: block;
    margin-top: 4px;
    color: var(--text);
    letter-spacing: 0.04em;
  }

  .pkg-grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(240px, 1fr));
    gap: 10px;
    margin: 10px 0 0;
  }

  .pkg-item {
    display: flex;
    flex-direction: column;
    gap: 2px;
    padding: 10px 14px;
    background: var(--surface);
    border: 1px solid var(--border);
    border-radius: var(--radius);
    text-decoration: none;
    color: var(--text);
    transition: background 0.15s, border-color 0.15s;
  }
  .pkg-item:hover {
    background: var(--bg-alt);
    border-color: var(--text-muted);
  }

  .pkg-item.built {
    border-left: 3px solid var(--green);
  }

  .pkg-icon {
    flex-shrink: 0;
    width: 14px;
    text-align: center;
    color: var(--cyan);
    font-size: 0.85rem;
    user-select: none;
  }

  .pkg-header {
    display: flex;
    align-items: center;
    gap: 10px;
    width: 100%;
  }
  .pkg-name {
    font-weight: 500;
    word-break: break-word;
  }
  .pkg-version {
    color: var(--text-muted);
    font-size: 0.75rem;
    margin-left: auto;
    flex-shrink: 0;
  }
  .pkg-desc {
    color: var(--text-muted);
    font-size: 0.75rem;
    line-height: 1.4;
    padding-left: 24px;
    word-break: break-word;
  }

  .pkg-section {
    margin: 10px 0 0;
  }
  .section-label {
    color: var(--text-muted);
    font-size: 0.7rem;
    text-transform: uppercase;
    letter-spacing: 0.08em;
    padding: 6px 0 4px;
    user-select: none;
  }
  .pkg-scroll {
    max-height: 260px;
    overflow-y: auto;
    border: 1px solid var(--border);
    border-radius: var(--radius);
    padding: 8px;
  }
  .pkg-scroll .pkg-grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(240px, 1fr));
    gap: 8px;
  }

  .search-bar {
    display: block;
    width: 100%;
    margin: 12px 0 0;
    padding: 8px 12px;
    background: var(--surface);
    border: 1px solid var(--border);
    border-radius: var(--radius);
    color: var(--text);
    font-family: inherit;
    font-size: 0.8rem;
    outline: none;
    transition: border-color 0.15s;
  }
  .search-bar:focus {
    border-color: var(--cyan);
  }
  .search-bar::placeholder {
    color: var(--text-muted);
    user-select: none;
  }

  .cursor-line { margin-top: 18px; }
  .cursor {
    display: inline-block;
    width: 8px; height: 16px;
    background: var(--text);
    animation: blink 1s step-end infinite;
    vertical-align: text-bottom;
  }
  @keyframes blink { 50% { opacity: 0; } }

  .term-footer {
    padding: 10px 28px 16px;
    text-align: center;
    font-size: 0.75rem;
    color: var(--text-muted);
    border-top: 1px solid var(--border);
  }
  .term-footer a {
    color: var(--cyan);
    text-decoration: none;
  }
  .term-footer a:hover { text-decoration: underline; }

  @media (max-width: 640px) {
    body { padding: 12px; }
    .term-body { padding: 20px 16px 16px; }
    .term-footer { padding: 10px 16px 14px; }
    .pkg-grid { grid-template-columns: 1fr; }
    pre { font-size: 0.8rem; padding: 12px; }
  }

  @media (prefers-reduced-motion: reduce) {
    .cursor { animation: none; opacity: 1; }
  }
</style>
</head>
<body>

<div class="terminal">

  <div class="term-bar">
    <div class="term-title">xbps - lysec@void:~</div>
  </div>

  <div class="term-body">

    <div class="line">
      <span class="prompt">$</span>
      <span class="cmd">cat README</span>
    </div>
    <div class="output">
      <p>Custom <strong>Void Linux</strong> binary packages</p>
      <p>hosted at <a href="https://xbps.lysec.dev/" style="color:var(--cyan)">xbps.lysec.dev</a></p>
    </div>

    <hr class="divider">

    <div class="line">
      <span class="prompt">$</span>
      <span class="cmd">cat INSTALL</span>
    </div>
    <div class="output">
      <p><strong>1. Add the repository</strong></p>
      <pre><code><span class="prompt">$</span> echo <span class="hl-string">"repository=https://xbps.lysec.dev/"</span> | sudo tee /etc/xbps.d/20-lysec.conf</code></pre>

      <p><strong>2. Sync and import the key</strong></p>
      <pre><code><span class="prompt">$</span> sudo xbps-install -S</code></pre>
      <p>XBPS will ask to import our RSA key. Confirm the fingerprint:</p>
      <div class="fingerprint">
        <span class="label">Signed by:</span> <span class="signer">Ly-sec &lt;void@lysec.dev&gt;</span>
        <span class="key">02:7a:c5:f7:1d:02:cc:84:3a:88:a0:64:7f:34:f1:71:3d:77:d1:ff:c2:4a:cd:0b:44:fa:b5:34:68:01:ac:69</span>
      </div>
    </div>

    <hr class="divider">

    <div class="line">
      <span class="prompt">$</span>
      <span class="cmd">ls packages/</span>
    </div>
    <div class="output">
      <input type="text" class="search-bar" placeholder="filter packages..." oninput="filterPackages(this.value)">

HTML

write_card() {
  local template="$1" css_class="$2"
  local pkgdir desc version revision homepage pkgver pkgname
  pkgdir=$(dirname "$template")
  pkgname=$(basename "$pkgdir")
  desc=$(extract "$template" short_desc)
  version=$(extract "$template" version)
  revision=$(extract "$template" revision)
  homepage=$(extract "$template" homepage)
  pkgver="${version}_${revision}"
  cat >> "$OUT" << ITEM
        <a class="pkg-item ${css_class}" href="${homepage:-#}">
          <div class="pkg-header">
            <span class="pkg-icon">#</span>
            <span class="pkg-name">${pkgname}</span>
            <span class="pkg-version">${pkgver}</span>
          </div>
          <span class="pkg-desc">${desc}</span>
        </a>
ITEM
}

if [ ${#BUILT_PKGS[@]} -gt 0 ]; then
  echo '      <div class="pkg-section">' >> "$OUT"
  echo '        <span class="section-label">built</span>' >> "$OUT"
  echo '        <div class="pkg-scroll"><div class="pkg-grid">' >> "$OUT"
  for template in "${BUILT_PKGS[@]}"; do
    write_card "$template" "built"
  done
  echo '        </div></div>' >> "$OUT"
  echo '      </div>' >> "$OUT"
fi

echo '      <div class="pkg-section">' >> "$OUT"
echo '        <span class="section-label">available</span>' >> "$OUT"
echo '        <div class="pkg-scroll"><div class="pkg-grid">' >> "$OUT"
for template in "${AVAIL_PKGS[@]}"; do
  write_card "$template" ""
done
echo '        </div></div>' >> "$OUT"
echo '      </div>' >> "$OUT"

cat >> "$OUT" << 'HTML'
    </div>

    <div class="line cursor-line">
      <span class="prompt">$</span>
      <span class="cursor"></span>
    </div>

  </div>

  <div class="term-footer">
    <a href="https://github.com/lysec/void-repo">GitHub</a> &middot; <a href="keys/pub.pem">Public key</a>
  </div>

</div>

<script>
function filterPackages(query) {
  var q = query.toLowerCase();
  document.querySelectorAll('.pkg-section').forEach(function(section) {
    var cards = section.querySelectorAll('.pkg-item');
    var visible = false;
    cards.forEach(function(card) {
      var name = card.querySelector('.pkg-name').textContent.toLowerCase();
      var desc = card.querySelector('.pkg-desc').textContent.toLowerCase();
      var match = name.indexOf(q) !== -1 || desc.indexOf(q) !== -1;
      card.style.display = match ? '' : 'none';
      if (match) visible = true;
    });
    section.style.display = visible || q === '' ? '' : 'none';
  });
}
</script>

</body>
</html>
HTML

echo "OK  generated  $OUT"
