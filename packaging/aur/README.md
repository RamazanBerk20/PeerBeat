# AUR packaging

Two packages:

- **`peerbeat`** — builds from the tagged source release (needs the Flutter +
  Rust toolchain at build time).
- **`peerbeat-bin`** — installs the prebuilt Linux tarball from the GitHub
  Release (no toolchain needed). Recommended for most users.

## Publishing (maintainer only)

The AUR deploy SSH key lives **only** on the maintainer machine
(`~/.ssh/aur`) and is never committed or put in CI. After a `vX.Y.Z` GitHub
Release exists with its artifacts:

```bash
# For each package dir (peerbeat-bin, then peerbeat):
cd packaging/aur/<pkg>

# 1. bump pkgver and fill real sha256sums
updpkgsums                       # pulls sources, writes real sums
makepkg -f                       # local build smoke-test
namcap PKGBUILD                  # lint
makepkg --printsrcinfo > .SRCINFO

# 2. push to the AUR (master branch only)
GIT_SSH_COMMAND='ssh -i ~/.ssh/aur -o IdentitiesOnly=yes' \
  git -C /path/to/aur-clone push origin master
```

First-time setup of an AUR clone:

```bash
GIT_SSH_COMMAND='ssh -i ~/.ssh/aur' \
  git clone ssh://aur@aur.archlinux.org/peerbeat-bin.git
# copy PKGBUILD + .SRCINFO in, commit, push
```

The registered public key is:

```
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILZ9znYKHG1dOxaoXTtEX91P6/1JMJ6/Xuk5pp8O9rf3
```

`.SRCINFO` **must** be regenerated whenever `PKGBUILD` changes or the AUR will
reject/ignore the update.
