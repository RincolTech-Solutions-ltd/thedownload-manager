#!/bin/bash
set -e

APP_DIR="/opt/tdman"
DESKTOP_DIR="/usr/share/applications"
BIN_DIR="/usr/local/bin"
FF_HOST_DIR="$HOME/.mozilla/native-messaging-hosts"
CHROME_HOST_DIR="$HOME/.config/google-chrome/NativeMessagingHosts"
CHROMIUM_HOST_DIR="$HOME/.config/chromium/NativeMessagingHosts"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/../XDM/XDM.Gtk.UI/bin/Release/net8.0"
HOST_BUILD_DIR="$SCRIPT_DIR/../XDM/XDM.App.Host/bin/Release/net8.0"

echo "Installing TheDownload Manager..."

sudo mkdir -p "$APP_DIR" "$APP_DIR/XDM.App.Host"
sudo cp -r "$BUILD_DIR/." "$APP_DIR/"
sudo cp -r "$HOST_BUILD_DIR/." "$APP_DIR/XDM.App.Host/"

# Wrapper script for main app (NTFS has no exec bit, /opt does)
sudo tee "$APP_DIR/xdm-app" > /dev/null <<'WRAPPER'
#!/bin/bash
export GTK_USE_PORTAL=1
exec dotnet /opt/tdman/xdm-app.dll "$@"
WRAPPER
sudo chmod +x "$APP_DIR/xdm-app"

# Wrapper script for native messaging host
sudo tee "$APP_DIR/XDM.App.Host/xdm-app-host" > /dev/null <<'WRAPPER'
#!/bin/bash
exec dotnet /opt/tdman/XDM.App.Host/xdm-app-host.dll "$@"
WRAPPER
sudo chmod +x "$APP_DIR/XDM.App.Host/xdm-app-host"

# Launcher in PATH
sudo tee "$BIN_DIR/tdman" > /dev/null <<'LAUNCHER'
#!/bin/bash
export GTK_USE_PORTAL=1
exec dotnet /opt/tdman/xdm-app.dll "$@"
LAUNCHER
sudo chmod +x "$BIN_DIR/tdman"

# Desktop entry
sudo tee "$DESKTOP_DIR/tdman.desktop" > /dev/null <<'DESKTOP'
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

# Register native messaging host for Firefox
mkdir -p "$FF_HOST_DIR"
cat > "$FF_HOST_DIR/xdmff.native_host.json" <<JSON
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

# Register for Chrome/Chromium
mkdir -p "$CHROME_HOST_DIR" "$CHROMIUM_HOST_DIR"
cat > "$CHROME_HOST_DIR/xdm_chrome.native_host.json" <<JSON
{
  "name": "xdm_chrome.native_host",
  "description": "Native messaging host for TheDownload Manager by Rincol Tech",
  "path": "/opt/tdman/XDM.App.Host/xdm-app-host",
  "type": "stdio",
  "allowed_origins": [
    "chrome-extension://akdmdglbephckgfmdffcdebnpjgamofc/"
  ]
}
JSON
cp "$CHROME_HOST_DIR/xdm_chrome.native_host.json" "$CHROMIUM_HOST_DIR/xdm_chrome.native_host.json"

sudo update-desktop-database "$DESKTOP_DIR" 2>/dev/null || true

echo ""
echo "Done. Run with:  tdman"
echo "Or launch from the applications menu: TheDownload Manager"
echo ""
echo "Firefox extension: install from the .xpi in the releases folder."
echo "After installing the extension, restart Firefox."
