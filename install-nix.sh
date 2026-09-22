#!/usr/bin/env sh
set -eu

if command -v nix >/dev/null 2>&1; then
    echo "Nix is already installed: $(nix --version)"
    exit 0
fi

echo "Installing Nix package manager..."
sh <(curl -L https://nixos.org/nix/install) --daemon

echo
echo "Nix installed. Reload your shell or run:"
echo "  . /etc/profile.d/nix.sh"
echo
echo "Then enter the dev environment:"
echo "  nix develop"
