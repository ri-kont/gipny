#!/usr/bin/env bash
set -euo pipefail

cd /src/ui
npm install
npm run build

cd /src/core
cargo build --release --target x86_64-pc-windows-gnu

VERSION=$(grep '^version' /src/core/Cargo.toml | head -1 | cut -d'"' -f2)
OUT=/src/release-artifacts
mkdir -p "$OUT"

BIN=/src/target/x86_64-pc-windows-gnu/release/gipny.exe
if [[ ! -f "$BIN" ]]; then
    echo "[!] gipny.exe not found at $BIN" >&2
    exit 1
fi

WV2_CACHE=/src/.cache/webview2
WV2_DLL="$WV2_CACHE/WebView2Loader.dll"
WV2_SETUP="$WV2_CACHE/MicrosoftEdgeWebView2RuntimeInstallerX64.exe"
mkdir -p "$WV2_CACHE"

if [[ ! -f "$WV2_DLL" ]]; then
    echo "[*] downloading WebView2 SDK"
    wget -q -O "$WV2_CACHE/webview2.nupkg" "https://www.nuget.org/api/v2/package/Microsoft.Web.WebView2"
    unzip -o -q "$WV2_CACHE/webview2.nupkg" -d "$WV2_CACHE/extracted"
    cp "$WV2_CACHE/extracted/build/native/x64/WebView2Loader.dll" "$WV2_DLL"
fi

if [[ ! -f "$WV2_SETUP" ]]; then
    echo "[*] downloading WebView2 Evergreen offline installer (~205 MB)"
    wget -q -O "$WV2_SETUP" "https://go.microsoft.com/fwlink/p/?LinkId=2124701"
fi
echo "[*] offline installer: $(du -h "$WV2_SETUP" | cut -f1)"

STAGE=$(mktemp -d)
cp "$BIN" "$STAGE/gipny.exe"
cp "$WV2_DLL" "$STAGE/WebView2Loader.dll"
cp /src/core/icons/icon.ico "$STAGE/app.ico"

OUT_EXE="$OUT/gipny-${VERSION}-setup.exe"
makensis \
    -DVERSION="$VERSION" \
    -DEXE_PATH="$STAGE/gipny.exe" \
    -DDLL_PATH="$STAGE/WebView2Loader.dll" \
    -DICON_PATH="$STAGE/app.ico" \
    -DWV2_SETUP="$WV2_SETUP" \
    -DOUT_FILE="$OUT_EXE" \
    /usr/local/share/gipny/installer.nsi

ZIP_DIR=$(mktemp -d)
mkdir -p "$ZIP_DIR/gipny-${VERSION}"
cp "$BIN" "$ZIP_DIR/gipny-${VERSION}/gipny.exe"
cp "$WV2_DLL" "$ZIP_DIR/gipny-${VERSION}/WebView2Loader.dll"
cp "$WV2_SETUP" "$ZIP_DIR/gipny-${VERSION}/install-webview2.exe"
cat > "$ZIP_DIR/gipny-${VERSION}/README.txt" <<EOF
gipny ${VERSION} — portable

first run:
  1. double-click install-webview2.exe (installs WebView2 Runtime, ~1 min)
     skip this step only if your Windows already has it (Win11, fresh Win10 20H2+)
  2. double-click gipny.exe

if gipny.exe shows "Could not find the WebView2 Runtime" — run step 1.

install-webview2.exe can be deleted after a successful first launch.
EOF
(cd "$ZIP_DIR" && zip -r -q "$OUT/gipny-${VERSION}-x86_64-portable.zip" "gipny-${VERSION}")

rm -rf "$STAGE" "$ZIP_DIR"

echo
echo "== windows artifacts =="
ls -lh "$OUT/"
