#!/bin/bash
set -e

VERSION=8.0.25
PKG_NAME="tdman_${VERSION}_amd64"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/../XDM/XDM.Gtk.UI/bin/Release/net8.0"
HOST_BUILD_DIR="$SCRIPT_DIR/../XDM/XDM.App.Host/bin/Release/net8.0"
FIREFOX_EXT_DIR="$SCRIPT_DIR/../XDM/firefox-amo"
OUT_DIR="$HOME/tdman-packages"

# Build on real filesystem (NTFS blocks chmod, dpkg-deb requires it)
WORK_DIR="/tmp/tdman-build"
rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR"
mkdir -p "$OUT_DIR"

echo "Building TheDownload Manager deb package v${VERSION}..."

cd "$WORK_DIR"
mkdir -p "$PKG_NAME/DEBIAN"
mkdir -p "$PKG_NAME/opt/tdman"
mkdir -p "$PKG_NAME/opt/tdman/XDM.App.Host"
mkdir -p "$PKG_NAME/usr/bin"
mkdir -p "$PKG_NAME/usr/share/applications"
mkdir -p "$PKG_NAME/usr/lib/mozilla/native-messaging-hosts"

# Copy app and host binaries
cp -r "$BUILD_DIR/." "$PKG_NAME/opt/tdman/"
cp -r "$HOST_BUILD_DIR/." "$PKG_NAME/opt/tdman/XDM.App.Host/"

# Main app wrapper
cat > "$PKG_NAME/opt/tdman/xdm-app" <<'WRAPPER'
#!/bin/bash
export GTK_USE_PORTAL=1
exec dotnet /opt/tdman/xdm-app.dll "$@"
WRAPPER

# Native messaging host wrapper
cat > "$PKG_NAME/opt/tdman/XDM.App.Host/xdm-app-host" <<'WRAPPER'
#!/bin/bash
exec dotnet /opt/tdman/XDM.App.Host/xdm-app-host.dll "$@"
WRAPPER

# PATH launcher
cat > "$PKG_NAME/usr/bin/tdman" <<'LAUNCHER'
#!/bin/bash
export GTK_USE_PORTAL=1
exec dotnet /opt/tdman/xdm-app.dll "$@"
LAUNCHER

# Desktop entry
cat > "$PKG_NAME/usr/share/applications/tdman.desktop" <<'DESKTOP'
[Desktop Entry]
Version=1.0
Encoding=UTF-8
Type=Application
Terminal=false
Name=TheDownload Manager
Comment=Fast download manager by Rincol Tech
Exec=env GTK_USE_PORTAL=1 /opt/tdman/xdm-app %U
Icon=/opt/tdman/xdm-logo.svg
Categories=Network;FileTransfer;
MimeType=x-scheme-handler/tdman;
StartupNotify=true
DESKTOP

# System-wide Firefox native messaging host
cat > "$PKG_NAME/usr/lib/mozilla/native-messaging-hosts/xdmff.native_host.json" <<'JSON'
{
  "name": "xdmff.native_host",
  "description": "Native messaging host for TheDownload Manager by Rincol Tech",
  "path": "/opt/tdman/XDM.App.Host/xdm-app-host",
  "type": "stdio",
  "allowed_extensions": [
    "tdm-browser-helper@rincoltech.com"
  ]
}
JSON

# DEBIAN control
cat > "$PKG_NAME/DEBIAN/control" <<CTRL
Package: tdman
Version: ${VERSION}
Architecture: amd64
Depends: libgtk-3-0 (>= 3.22), dotnet-runtime-8.0, ffmpeg
Maintainer: Rincol Tech <support@rincoltech.com>
Homepage: https://www.rincoltech.com
Description: TheDownload Manager by Rincol Tech
 Fast, open-source download accelerator and video downloader.
 Supports YouTube, HTTP multi-segment downloads, and browser integration.
CTRL

# postinst — set permissions and register desktop
cat > "$PKG_NAME/DEBIAN/postinst" <<'POSTINST'
#!/bin/bash
chmod +x /opt/tdman/xdm-app
chmod +x /opt/tdman/XDM.App.Host/xdm-app-host
chmod +x /usr/bin/tdman
update-desktop-database /usr/share/applications 2>/dev/null || true
POSTINST

chmod 755 "$PKG_NAME/DEBIAN/postinst"

dpkg-deb --build --root-owner-group -Z xz "$PKG_NAME"
cp "${PKG_NAME}.deb" "$OUT_DIR/"
echo ""
echo "Built: $OUT_DIR/${PKG_NAME}.deb"
echo "Install with:  sudo dpkg -i $OUT_DIR/${PKG_NAME}.deb"

# Also build the Firefox .xpi
echo ""
echo "Building Firefox extension .xpi..."
XPI_DIR="$OUT_DIR"
cd "$FIREFOX_EXT_DIR"
zip -r "$XPI_DIR/tdm-browser-helper.xpi" . -x "*.DS_Store" -x "__MACOSX/*" > /dev/null
echo "Built: $XPI_DIR/tdm-browser-helper.xpi"
echo "Install in Firefox: about:addons > gear icon > Install Add-on From File"
