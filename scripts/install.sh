#!/bin/sh
# esparformctl インストールスクリプト
# 名前は docs/contracts/release-names.md（COND4）の対応表に従う。
#
# 受け入れ条件:
#   - OS/arch 自動判定
#   - 明示バージョン指定（ESPARFORMCTL_VERSION / -v）。既定は latest
#   - checksum 検証（checksums.txt の sha256）
#   - 失敗時アトミック置換（一時ファイルへ展開し、検証成功後にのみ mv）
#
# 使い方:
#   curl -fsSL https://raw.githubusercontent.com/feedtailor/espar-esparformctl/main/scripts/install.sh | sh
#   ESPARFORMCTL_VERSION=v1.2.3 INSTALL_DIR=$HOME/.local/bin sh install.sh
set -eu

REPO="feedtailor/espar-esparformctl"
BINARY="esparformctl"
VERSION="${ESPARFORMCTL_VERSION:-latest}"
# INSTALL_DIR 既定は OS 判定後に決める（macOS=~/.local/bin / 他=/usr/local/bin）。
# 環境変数・-d で明示された場合はそれを優先する。
INSTALL_DIR="${INSTALL_DIR:-}"

while [ $# -gt 0 ]; do
  case "$1" in
    -v) VERSION="$2"; shift 2 ;;
    -d) INSTALL_DIR="$2"; shift 2 ;;
    *) echo "不明な引数: $1" >&2; exit 64 ;;
  esac
done

# 明示バージョンは Release タグ（vX.Y.Z）に合わせて先頭 v を補う。
# latest はこの後の専用解決に回す。アセット名・タグともに v 付きで統一する。
case "$VERSION" in
  latest|v*) ;;
  *) VERSION="v${VERSION}" ;;
esac

err() { echo "エラー: $*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || err "$1 が必要です"; }

need curl
need tar

# --- OS/arch 判定 ---
os="$(uname -s)"
case "$os" in
  Linux)  OS="linux" ;;
  Darwin) OS="darwin" ;;
  *) err "未対応の OS: $os（Windows は .zip を手動展開してください）" ;;
esac

arch="$(uname -m)"
case "$arch" in
  x86_64|amd64) ARCH="amd64" ;;
  arm64|aarch64) ARCH="arm64" ;;
  *) err "未対応の arch: $arch" ;;
esac

# --- INSTALL_DIR 既定（未指定時のみ OS 別）---
# macOS は /usr/local/bin が sudo 必須のため、書き込み可能な ~/.local/bin を既定にする。
# Linux は従来どおり /usr/local/bin。
if [ -z "$INSTALL_DIR" ]; then
  if [ "$OS" = "darwin" ]; then
    INSTALL_DIR="${HOME}/.local/bin"
  else
    INSTALL_DIR="/usr/local/bin"
  fi
fi

# --- バージョン解決 ---
if [ "$VERSION" = "latest" ]; then
  BASE="https://github.com/${REPO}/releases/latest/download"
else
  BASE="https://github.com/${REPO}/releases/download/${VERSION}"
fi

ASSET="${BINARY}_${VERSION}_${OS}_${ARCH}.tar.gz"
# latest の場合、アセット名には実バージョンが入るため latest 専用 API で解決する。
if [ "$VERSION" = "latest" ]; then
  RESOLVED="$(curl -fsSL -o /dev/null -w '%{url_effective}' "https://github.com/${REPO}/releases/latest" | sed 's#.*/tag/##')"
  [ -n "$RESOLVED" ] || err "最新バージョンを解決できませんでした"
  VERSION="$RESOLVED"
  BASE="https://github.com/${REPO}/releases/download/${VERSION}"
  ASSET="${BINARY}_${VERSION}_${OS}_${ARCH}.tar.gz"
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "ダウンロード: ${BASE}/${ASSET}"
curl -fsSL "${BASE}/${ASSET}" -o "${TMP}/${ASSET}" || err "アーカイブの取得に失敗しました"
curl -fsSL "${BASE}/checksums.txt" -o "${TMP}/checksums.txt" || err "checksums.txt の取得に失敗しました"

# --- checksum 検証 ---
expected="$(grep " ${ASSET}\$" "${TMP}/checksums.txt" | awk '{print $1}')"
[ -n "$expected" ] || err "checksums.txt に ${ASSET} がありません"

if command -v sha256sum >/dev/null 2>&1; then
  actual="$(sha256sum "${TMP}/${ASSET}" | awk '{print $1}')"
elif command -v shasum >/dev/null 2>&1; then
  actual="$(shasum -a 256 "${TMP}/${ASSET}" | awk '{print $1}')"
else
  err "sha256sum / shasum が必要です"
fi

[ "$expected" = "$actual" ] || err "checksum 不一致（期待 $expected / 実際 $actual）"
echo "checksum OK"

# --- 展開 & アトミック置換 ---
tar -xzf "${TMP}/${ASSET}" -C "${TMP}" || err "展開に失敗しました"
[ -f "${TMP}/${BINARY}" ] || err "アーカイブにバイナリ ${BINARY} がありません"
chmod +x "${TMP}/${BINARY}"

DEST="${INSTALL_DIR}/${BINARY}"
if [ -w "$INSTALL_DIR" ] 2>/dev/null || mkdir -p "$INSTALL_DIR" 2>/dev/null; then
  mv -f "${TMP}/${BINARY}" "$DEST"
else
  echo "${INSTALL_DIR} への書き込みに sudo が必要です"
  sudo mv -f "${TMP}/${BINARY}" "$DEST"
fi

echo "インストール完了: ${DEST}"
"$DEST" --version || true

# --- PATH 確認（INSTALL_DIR が PATH に無ければ追加方法を案内）---
case ":${PATH}:" in
  *":${INSTALL_DIR}:"*) ;;
  *)
    echo "" >&2
    echo "注意: ${INSTALL_DIR} は PATH に含まれていません。次を shell の設定（~/.zshrc 等）に追加してください:" >&2
    echo "  export PATH=\"${INSTALL_DIR}:\$PATH\"" >&2
    ;;
esac
