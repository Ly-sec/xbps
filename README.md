# void-repo — Custom Void Linux packages repository

A minimal overlay repository for maintaining custom Void Linux package
templates and selected upstream overrides without vendoring the entire
[void-packages](https://github.com/void-linux/void-packages) tree.

## How it works

1. Your package templates live under `pkgs/<pkgname>/template`.
2. During a build the upstream `void-packages` repo is shallow-cloned.
3. Your custom templates are **overlaid** into
   `void-packages/srcpkgs/`, replacing any upstream version.
4. Packages are built with Void's `xbps-src`.
5. The resulting `.xbps` files are collected into `repo/` and turned into
   a valid XBPS repository index.
6. The repository is signed with your Ed25519 key and published as a
   static repository over HTTP.

Because only your templates are committed, the repo stays small and
focused.

## Quick start

```bash
# 1. Clone
git clone <your-repo-url>
cd void-repo

# 2. Configure
cp etc/build.conf.example etc/build.conf
cp etc/signing.conf.example etc/signing.conf
# edit etc/build.conf and etc/signing.conf

# 3. Generate a signing key (or provide your own)
openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:4096 -out keys/priv.pem
openssl pkey -in keys/priv.pem -pubout -out keys/pub.pem

# 4. Set up build environment
bash scripts/setup.sh

# 5. Overlay custom packages
bash scripts/overlay-packages.sh

# 6. Build everything
bash scripts/build.sh

# 7. Sign the repository
bash scripts/sign-repo.sh
```

## Directory layout

```
.
├── pkgs/                       # Your custom package templates
│   ├── example-hello/          #   new package example
│   │   ├── template
│   │   ├── update              #   optional update-check script
│   │   └── patches/            #   optional patches
│   └── example-override/       #   upstream override example
│       └── template
├── scripts/                    # Build & automation scripts
│   ├── setup.sh                # Bootstrap the build environment
│   ├── overlay-packages.sh     # Copy templates into upstream tree
│   ├── build.sh                # Build packages with xbps-src
│   ├── sign-repo.sh            # Sign the repository index
│   ├── publish.sh              # Publish to GitHub Releases
│   ├── check-updates.sh        # Check for upstream package updates
│   └── update-package.sh       # Auto-update a package template
├── etc/                        # Configuration templates
│   ├── build.conf.example
│   └── signing.conf.example
├── keys/                       # Signing keys (git-ignored in .gitignore)
│   └── README.md
├── repo/                       # Published .xbps files + index
│   └── README.md
└── .github/workflows/          # CI/CD
    ├── build.yml
    └── update-checks.yml
```

## Adding a new package

1. Create `pkgs/<pkgname>/template` following [Void Linux template
   conventions](https://github.com/void-linux/void-packages/blob/master/CONTRIBUTING.md).
2. Optionally add `pkgs/<pkgname>/update` for custom update-check
   behaviour.
3. Optionally add `pkgs/<pkgname>/patches/*.patch` for source patches.
4. Build it: `bash scripts/build.sh <pkgname>`

See the `pkgs/example-hello/` directory for a complete example.

## Overriding an upstream package

To override a package that exists in the upstream `void-packages` tree,
simply create `pkgs/<pkgname>/template` with your custom version. The
overlay script replaces the upstream version automatically.

See `pkgs/example-override/` for an example.

## CI/CD

Two GitHub Actions workflows are provided:

- **build.yml** — triggered on pushes that modify `pkgs/`. Clones
   upstream, overlays templates, builds packages, signs the repo,
   publishes the raw repository files to GitHub Pages, and optionally
   publishes a GitHub Release.
- **update-checks.yml** — runs on a schedule (default: weekly). Checks
  all packages for newer upstream versions and opens an issue when an
  update is found.

### Required secrets for CI

| Secret | Description |
|--------|-------------|
| `XBPS_PRIVKEY` | Ed25519 private key (PEM) for signing the repo |
| `XBPS_PUBKEY` | Ed25519 public key (PEM) — optional, can be derived |
| `XBPS_SIGNEDBY` | Signer identity string, e.g. `"Your Name <you@example.com>"` |

## Adding the repository on a Void Linux system

Built packages are always collected locally in `repo/` during a build.
In CI, that directory is published verbatim to GitHub Pages so XBPS can
read it as a normal static repository.

Once packages are published, configure XBPS on the target machine:

```bash
# 1. Install the public key
# Download keys/pub.pem from your published repo and place it in
# /var/db/xbps/keys/ using the filename expected by xbps.

# 2. Add the repository
# Example for GitHub Pages:
xbps-install -R "https://<owner>.github.io/<repo>" -S
```

The repository root serves the `.xbps` packages and repodata files, and
the public key is published at `https://<owner>.github.io/<repo>/keys/pub.pem`.

## Architecture support

The default configuration builds for `x86_64` (masterdir). To target
`aarch64` (or other architectures), change `XBPS_TARGET_ARCH` in
`etc/build.conf` and use the `-a` flag:

```bash
XBPS_TARGET_ARCH="aarch64"
# Then run:
(cd void-packages && ./xbps-src -a aarch64 pkg <pkgname>)
```

Cross-compilation requires the appropriate cross-toolchain bootstrap:

```bash
(cd void-packages && ./xbps-src -a aarch64 binary-bootstrap)
```

## License

Unless otherwise noted, the contents of this repository are available
under the same terms as the upstream `void-packages` repository (BSD
2-Clause). See the LICENSE file for details.
