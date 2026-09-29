#!/usr/bin/env bash
set -euo pipefail

sudo apt update
sudo apt install -y ca-certificates curl wget git gpg unzip nodejs npm thunar gedit gthumb kitty fastfetch zsh xfconf tumbler tumbler-plugins-extra

sudo install -d -m 0755 /etc/apt/keyrings
if [ ! -f /etc/apt/keyrings/microsoft.gpg ]; then
  wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor -o /etc/apt/keyrings/microsoft.gpg
  sudo chmod 644 /etc/apt/keyrings/microsoft.gpg
fi
sudo tee /etc/apt/sources.list.d/vscode.sources >/dev/null <<'SRC'
Types: deb
URIs: https://packages.microsoft.com/repos/code
Suites: stable
Components: main
Architectures: amd64,arm64,armhf
Signed-By: /etc/apt/keyrings/microsoft.gpg
SRC

sudo install -d -m 0755 /usr/share/keyrings
if [ ! -f /usr/share/keyrings/vivaldi-browser.gpg ]; then
  wget -qO- https://repo.vivaldi.com/archive/linux_signing_key.pub | gpg --dearmor | sudo tee /usr/share/keyrings/vivaldi-browser.gpg >/dev/null
  sudo chmod 644 /usr/share/keyrings/vivaldi-browser.gpg
fi
echo "deb [signed-by=/usr/share/keyrings/vivaldi-browser.gpg arch=$(dpkg --print-architecture)] https://repo.vivaldi.com/archive/deb/ stable main" | sudo tee /etc/apt/sources.list.d/vivaldi.list >/dev/null
sudo apt update
sudo apt install -y code vivaldi-stable

if dpkg-query -W -f='${db:Status-Status}' jopdf 2>/dev/null | grep -qx installed; then
  echo 'JOPDF already installed.'
else
  f=/tmp/jopdf-linux-amd64_setup.deb
  wget -O "$f" https://cdn.jopdf.com/download/jopdf/jopdf-linux-amd64_setup.deb
  sudo apt install -y "$f"
  rm -f "$f"
fi

ZSH_DIR="$HOME/.zsh"
mkdir -p "$ZSH_DIR"
for pair in \
  "$ZSH_DIR/zsh-autosuggestions|https://github.com/zsh-users/zsh-autosuggestions.git" \
  "$ZSH_DIR/zsh-syntax-highlighting|https://github.com/zsh-users/zsh-syntax-highlighting.git"; do
  dir="${pair%%|*}"; url="${pair#*|}"
  if [ -d "$dir/.git" ]; then git -C "$dir" pull --ff-only; else rm -rf "$dir"; git clone --depth=1 "$url" "$dir"; fi
done

P10K_DIR="$HOME/powerlevel10k"
if [ -d "$P10K_DIR/.git" ]; then git -C "$P10K_DIR" pull --ff-only; else rm -rf "$P10K_DIR"; git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$P10K_DIR"; fi

touch "$HOME/.zshrc"
add_line() { grep -Fqx "$1" "$HOME/.zshrc" || printf '%s\n' "$1" >> "$HOME/.zshrc"; }
add_line '# Powerlevel10k'
add_line 'source "$HOME/powerlevel10k/powerlevel10k.zsh-theme"'
add_line '# Zsh autosuggestions'
add_line 'source "$HOME/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh"'
add_line '# Zsh syntax highlighting'
add_line 'source "$HOME/.zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"'
add_line '# Fastfetch'
add_line 'fastfetch'

xfconf-query -c thunar -p /misc-thumbnail-mode -n -t uint -s 3 2>/dev/null || xfconf-query -c thunar -p /misc-thumbnail-mode -s 3
xfconf-query -c thunar -p /last-restore-tabs -n -t bool -s true 2>/dev/null || xfconf-query -c thunar -p /last-restore-tabs -s true

UCA_DIR="$HOME/.config/Thunar"
UCA_FILE="$UCA_DIR/uca.xml"
mkdir -p "$UCA_DIR"
[ -f "$UCA_FILE" ] || printf '%s\n' '<?xml version="1.0" encoding="UTF-8"?><actions></actions>' > "$UCA_FILE"
add_action() {
  name="$1"; action="$2"
  grep -Fq "<name>$name</name>" "$UCA_FILE" && return
  python3 - "$UCA_FILE" "$action" <<'PY'
import sys
from pathlib import Path
p=Path(sys.argv[1]); action=sys.argv[2]; s=p.read_text()
if '</actions>' not in s: raise SystemExit('Invalid Thunar uca.xml')
p.write_text(s.replace('</actions>', action+'\n</actions>', 1))
PY
}
add_action 'Open Terminal Here' '  <action><icon>utilities-terminal</icon><name>Open Terminal Here</name><unique-id>chatgpt-open-terminal-here</unique-id><command>kitty --directory %f</command><description>Open Kitty in the selected directory</description><patterns>*</patterns><directories/></action>'
add_action 'Open as Root' '  <action><icon>system-file-manager</icon><name>Open as Root</name><unique-id>chatgpt-open-as-root</unique-id><command>pkexec env WAYLAND_DISPLAY="$WAYLAND_DISPLAY" XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" GDK_BACKEND=wayland thunar %f</command><description>Open the selected directory as root</description><patterns>*</patterns><directories/></action>'

printf '\nAdditional packages (space-separated, Enter to skip): '
read -r -a EXTRA
[ "${#EXTRA[@]}" -eq 0 ] || sudo apt install -y "${EXTRA[@]}"

thunar -q 2>/dev/null || true

ZSH_PATH="$(command -v zsh)"
[ "$SHELL" = "$ZSH_PATH" ] || chsh -s "$ZSH_PATH"

echo
printf '%s\n' 'Installation complete.' 'Run: p10k configure' 'Log out and back in for the shell change.'
