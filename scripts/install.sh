#!/bin/sh
# Install rootplc on Linux or macOS:
#   curl -fsSL https://raw.githubusercontent.com/xiaojunyang0805/RootPLC/main/scripts/install.sh | sh
# Options (environment): ROOTPLC_VERSION=v0.1.0 (default: latest release),
#                        ROOTPLC_INSTALL_DIR=/path (default: $HOME/.local/bin)
# Without a release for your platform it falls back to building with cargo.
set -eu

REPO="xiaojunyang0805/RootPLC"
DIR="${ROOTPLC_INSTALL_DIR:-$HOME/.local/bin}"
VERSION="${ROOTPLC_VERSION:-latest}"

case "$(uname -s)-$(uname -m)" in
  Linux-x86_64)               TARGET=x86_64-unknown-linux-gnu ;;
  Linux-aarch64|Linux-arm64)  TARGET=aarch64-unknown-linux-gnu ;;
  Darwin-arm64)               TARGET=aarch64-apple-darwin ;;
  Darwin-x86_64)              TARGET=x86_64-apple-darwin ;;
  *)                          TARGET="" ;;
esac

fallback() {
  echo "rootplc: no release binary for this platform; building from source with cargo." >&2
  command -v cargo >/dev/null || { echo "install Rust first: https://rustup.rs" >&2; exit 1; }
  cargo install --locked --git "https://github.com/$REPO" rootplc
  exit 0
}

[ -n "$TARGET" ] || fallback
if [ "$VERSION" = latest ]; then
  BASE="https://github.com/$REPO/releases/latest/download"
else
  BASE="https://github.com/$REPO/releases/download/$VERSION"
fi
ASSET="rootplc-$TARGET.tar.gz"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

curl -fsSL "$BASE/$ASSET" -o "$TMP/$ASSET" || fallback
curl -fsSL "$BASE/$ASSET.sha256" -o "$TMP/$ASSET.sha256" || fallback
( cd "$TMP"
  if command -v sha256sum >/dev/null; then sha256sum -c "$ASSET.sha256" >/dev/null
  else shasum -a 256 -c "$ASSET.sha256" >/dev/null; fi ) || { echo "rootplc: checksum mismatch" >&2; exit 1; }

tar xzf "$TMP/$ASSET" -C "$TMP"
mkdir -p "$DIR"
install -m 755 "$TMP/rootplc" "$DIR/rootplc"
echo "rootplc installed to $DIR/rootplc"
case ":$PATH:" in *":$DIR:"*) ;; *) echo "add $DIR to your PATH" ;; esac
"$DIR/rootplc" --version
