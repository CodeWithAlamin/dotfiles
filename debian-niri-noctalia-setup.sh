#!/usr/bin/env bash
set -euo pipefail

REPO_URL="https://github.com/lazarh/niri-noctalia-debian-script.git"
REPO_DIR="$HOME/niri-noctalia-debian-script"

echo "======================================"
echo " Debian 13 + Niri + Noctalia Setup"
echo "======================================"

echo
echo "[1/6] Updating Debian..."
sudo apt update
sudo apt upgrade -y

echo
echo "[2/6] Installing required packages..."
sudo apt install -y \
    git \
    wget \
    curl \
    clang \
    libclang-dev \
    ca-certificates

echo
echo "[3/6] Getting Niri installer..."

if [ -d "$REPO_DIR/.git" ]; then
    git -C "$REPO_DIR" pull --ff-only
else
    git clone "$REPO_URL" "$REPO_DIR"
fi

cd "$REPO_DIR"

echo
echo "[4/6] Installing dependencies and Niri..."
printf "1\n2\n" | ./install.sh --menu

echo
echo "Installing Niri desktop entry..."
./install.sh --install-desktop-entry

echo
echo "[5/6] Installing Noctalia..."

wget -O /tmp/nickh-archive-keyring.deb \
    https://pkg.noctalia.dev/deb/nickh-archive-keyring.deb

sudo dpkg -i /tmp/nickh-archive-keyring.deb

sudo wget -O \
    /etc/apt/sources.list.d/noctalia-trixie.sources \
    https://pkg.noctalia.dev/deb/noctalia-trixie.sources

sudo apt update
sudo apt install -y noctalia

echo
echo "[6/6] Installing LightDM + Slick Greeter..."

sudo apt install -y lightdm slick-greeter

sudo mkdir -p /etc/lightdm

sudo tee /etc/lightdm/lightdm.conf >/dev/null <<'EOF'
[Seat:*]
greeter-session=slick-greeter
user-session=niri
EOF

sudo tee /etc/lightdm/slick-greeter.conf >/dev/null <<'EOF'
[Greeter]
show-clock=true
show-a11y=false
show-power=true
show-session-menu=true
show-language-selector=false
EOF

sudo dpkg-reconfigure lightdm
sudo systemctl enable lightdm

echo
echo "======================================"
echo " Setup complete!"
echo "======================================"
echo
echo "Installed:"
echo "  ✓ Niri"
echo "  ✓ Noctalia"
echo "  ✓ Niri desktop entry"
echo "  ✓ LightDM"
echo "  ✓ Slick Greeter"
echo
echo "Noctalia Greeter was intentionally skipped."
echo
echo "Reboot with:"
echo "    sudo reboot"
