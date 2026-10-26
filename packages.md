# Packages

Everything to install on argos and arpano. Names are checked against the
core/extra/multilib databases, the AUR and mason.nvim's registry.

- **pacman**: official repos plus the CachyOS repos (`linux-cachyos*`; setup
  in system.md). Enable `[multilib]` in `/etc/pacman.conf` on argos (Steam
  and the `lib32-*` packages).
- **AUR**: needs an AUR helper, e.g. `paru` (bootstrap:
  `git clone https://aur.archlinux.org/paru-bin.git && cd paru-bin && makepkg -si`).
- **mason**: Neovim installs these itself on first start
  (`~/.config/nvim/lua/plugins/mason.lua`); Doom Emacs uses the same binaries.

## Install lists

### Both machines

```bash
sudo pacman -S --needed \
  base-devel stow git bash zsh vim wget gcc make cmake e2fsprogs parted plocate pacman-contrib \
  lazygit ripgrep fd bind duckdb btop github-cli unzip 7zip file jq tree \
  zsh-autosuggestions zsh-syntax-highlighting zsh-history-substring-search \
  eza fzf zoxide starship yazi poppler resvg chafa imagemagick ffmpeg \
  bat tuicr jujutsu openssh tmux \
  neovim tree-sitter-cli curl tar gzip \
  clang cppcheck rustup zig php nodejs npm pnpm python uv \
  emacs-wayland libvterm libtool systemd-lsp ttf-nerd-fonts-symbols ttf-nerd-fonts-symbols-mono \
  graphviz tidy composer isync pandoc-cli scrot \
  mangowm xorg-xwayland noctalia ghostty satty \
  grim slurp hyprpicker brightnessctl wl-clipboard wtype gpu-screen-recorder \
  qt5-wayland qt6-wayland xdg-desktop-portal xdg-desktop-portal-wlr xdg-desktop-portal-gtk \
  pipewire pipewire-alsa pipewire-pulse pipewire-jack wireplumber \
  dconf gvfs mesa vulkan-icd-loader xdg-utils polkit gsettings-desktop-schemas \
  adw-gtk-theme nwg-look papirus-icon-theme qt6ct breeze \
  noto-fonts noto-fonts-cjk noto-fonts-emoji ttf-jetbrains-mono-nerd ttf-cascadia-code-nerd \
  otf-geist-mono-nerd ttf-iosevka-nerd ttf-material-symbols-variable \
  evince playerctl torbrowser-launcher telegram-desktop librewolf signal-desktop sequoia-sq mpv \
  dolphin ark kio-fuse ffmpegthumbs kdegraphics-thumbnailers kconfig archlinux-xdg-menu \
  gwenview kimageformats \
  keepassxc syncthing gnome-keyring gcr-4 libsecret \
  ninja valgrind man-pages man-db gdb gef pkgconf \
  tor torsocks proxychains-ng openvpn wireshark-qt docker nftables iptables \
  networkmanager tailscale zram-generator \
  linux-cachyos linux-cachyos-headers amd-ucode linux-firmware limine plymouth \
  sddm kwin qt6-svg qt6-virtualkeyboard qt6-multimedia-ffmpeg accountsservice \
  qemu-desktop libvirt virt-manager virt-viewer dnsmasq swtpm virtiofsd edk2-ovmf spice-gtk \
  guestfs-tools libguestfs \
  nmap openbsd-netcat inetutils arp-scan bc tcpdump hydra samba cifs-utils wpscan exploitdb \
  metasploit python-jsbeautifier sqlmap hashcat john openssl impacket perl-image-exiftool \
  sslscan ghidra openldap binwalk

rustup default stable
rustup component add rust-analyzer clippy rustfmt

paru -S --needed \
  carapace-bin bibata-cursor-theme-bin ttf-twemoji-color ttf-all-the-icons ttf-symbola mu \
  helium-browser-bin pi-coding-agent-bin mpv-modernz vesktop-bin onlyoffice-bin localsend-bin \
  limine-mkinitcpio-hook sddm-silent-theme \
  virtio-win quickemu foundry-bin \
  burpsuite ffuf smbmap whatweb seclists rockyou pspy cewl-git ruby-evil-winrm hashid
```

Optional: `nix` (pacman) for Nix devshells. nvim and Doom already support
`.nix` files (alejandra, statix; add AUR `nixd` if you want the LSP).

### argos (NVIDIA, gaming)

```bash
sudo pacman -S --needed \
  linux-cachyos-nvidia-open nvidia-utils lib32-nvidia-utils nvidia-settings libva-nvidia-driver nvtop \
  steam gamescope gamemode lib32-gamemode protontricks umu-launcher \
  vulkan-tools mesa-utils libnotify lib32-pipewire lib32-vulkan-icd-loader

rustup target add i686-unknown-linux-gnu   # lib32-extest is Rust built for 32-bit
paru -S --needed proton-ge-custom-bin heroic-games-launcher-bin lib32-extest iptvnator-bin
```

### arpano (AMD ROCm, printing, Bluetooth)

```bash
sudo pacman -S --needed \
  rocm-core hip-runtime-amd rocm-opencl-runtime radeontop nvtop \
  cups gutenprint avahi nss-mdns bluez bluez-utils blender
```

### Not packaged

- **PadBuster**: `git clone https://github.com/AonCyberLabs/PadBuster`; the
  Perl script needs `perl-libwww perl-uri` (pacman) and `perl-crypt-ssleay` (AUR).

## Reference

What each group is for, in the same order as the lists.

### Base and CLI

| Package | Repo | For |
| --- | --- | --- |
| base-devel, stow, git | pacman | building AUR packages, these dotfiles |
| plocate | pacman | `locate` (enable `plocate-updatedb.timer`) |
| pacman-contrib | pacman | `paccache.timer` |
| bind | pacman | `dig`, `nslookup` |
| github-cli | pacman | `gh` |
| 7zip | pacman | `7z` |
| tree | pacman | fzf's Alt+C directory preview |
| eza, fzf, zoxide | pacman | `ls` aliases, fuzzy finder, `cd` (zoxide) |
| zsh-autosuggestions, zsh-syntax-highlighting, zsh-history-substring-search | pacman | zsh plugins (sourced from `/usr/share/zsh/plugins`) |
| carapace-bin | AUR | shell completions |
| starship | pacman | zsh prompt |
| yazi + poppler, resvg, chafa, imagemagick, ffmpeg | pacman | file manager and its previews |
| bat, tuicr, jujutsu, tmux | pacman | pager, code review TUI (`gd` alias), jj, multiplexer (config meant for servers, no plugins) |

### Editors and toolchain

| Package | Repo | For |
| --- | --- | --- |
| neovim, tree-sitter-cli | pacman | Neovim; nvim-treesitter compiles parsers with tree-sitter + gcc |
| curl, tar, gzip, unzip | pacman | lazy.nvim and mason downloads |
| clang | pacman | clangd, clang-format, clang-tidy |
| cppcheck | pacman | C/C++ linting (nvim-lint) |
| rustup | pacman | cargo, rustc, rustfmt, clippy, rust-analyzer (also builds blink.cmp / fff.nvim) |
| zig | pacman | Zig (zls comes from mason, matching its version) |
| php | pacman | runtime for phpactor / php-cs-fixer |
| nodejs, npm, pnpm, python, uv | pacman | mason's npm/pypi tools, global npm installs, Python |
| foundry-bin | AUR | `forge fmt` for Solidity (extra's `foundry` is an unrelated GNOME tool) |
| emacs-wayland | pacman | Emacs (pgtk build) for Doom |
| libvterm, libtool, cmake | pacman | Doom compiles vterm |
| systemd-lsp | pacman | LSP for systemd unit files in Doom |
| ttf-nerd-fonts-symbols(-mono), ttf-all-the-icons | pacman, AUR | Doom's icons |
| pi-coding-agent-bin | AUR | pi coding agent |
| graphviz, tidy, composer, pandoc-cli, scrot | pacman | Doom: org-roam graphs, HTML formatting, PHP, markdown preview/org export, org-download check |
| isync, mu | pacman, AUR | Doom's mu4e: mail sync (`mbsync`) and indexing |
| ttf-symbola | AUR | Emacs' fallback font for symbols |

User-level, outside pacman (Doom doctor): `GOBIN=~/.local/bin go install
github.com/x-motemen/gore/cmd/gore@latest github.com/jessfraz/dockfmt@latest`,
`uv tool install pytest`, `uv tool install pipenv`, `uv tool install pynose`
(`nosetests`; nose itself is dead on Python 3.12+), `npm i -g ethlint` (`solium`).

mason installs: ruff, basedpyright, black, gopls, gomodifytags, gotests,
stylelint, nixfmt, biome, vtsls, typescript-language-server,
astro-language-server, prettier, yaml-language-server, json-lsp, html-lsp,
css-lsp, phpactor, php-cs-fixer, alejandra, statix, neocmakelsp, cmakelint,
gersemi, zls, solidity (solc), vscode-solidity-server, lua-language-server,
stylua, bash-language-server, shellcheck, shfmt, dockerfile-language-server,
docker-compose-language-service, hadolint.

### Desktop: Mango + Noctalia

| Package | Repo | For |
| --- | --- | --- |
| mangowm, xorg-xwayland | pacman | compositor |
| noctalia | pacman | bar, launcher, notifications, lock screen, wallpaper |
| ghostty | pacman | terminal (D-Bus-activated by Mango's Super+Return; pulls in its terminfo and shell integration) |
| satty, grim, slurp | pacman | screenshots and annotation |
| hyprpicker, brightnessctl, wl-clipboard, wtype | pacman | color picker, brightness, clipboard, Super+C/X key injection |
| gpu-screen-recorder | pacman | Noctalia's screen recorder plugin |
| qt5-wayland, qt6-wayland | pacman | Qt apps on Wayland |
| xdg-desktop-portal, -wlr, -gtk | pacman | portals (screencast via wlr, the rest via gtk) |
| sddm, kwin, sddm-silent-theme (+ qt6-svg, qt6-virtualkeyboard, qt6-multimedia-ffmpeg), accountsservice | pacman + AUR | login screen (system.md) |

### Session, audio, appearance

| Package | Repo | For |
| --- | --- | --- |
| pipewire, pipewire-alsa, pipewire-pulse, pipewire-jack, wireplumber | pacman | audio |
| dconf, gvfs, mesa, vulkan-icd-loader, xdg-utils, polkit, gsettings-desktop-schemas | pacman | desktop plumbing |
| adw-gtk-theme, nwg-look, papirus-icon-theme | pacman | GTK theme, its settings GUI, icons |
| bibata-cursor-theme-bin | AUR | cursor |
| qt6ct, breeze | pacman | Qt theming (Caelus palette) |
| noto-fonts, noto-fonts-cjk, noto-fonts-emoji | pacman | base fonts |
| ttf-jetbrains-mono-nerd, ttf-cascadia-code-nerd, otf-geist-mono-nerd, ttf-iosevka-nerd | pacman | Nerd Fonts (Iosevka: Ghostty/Doom; GeistMono: Noctalia) |
| ttf-material-symbols-variable, ttf-twemoji-color | pacman, AUR | icon and emoji fonts |

### Apps

| Package | Repo | For |
| --- | --- | --- |
| librewolf | pacman | default browser (theme: README) |
| helium-browser-bin | AUR | Chromium for tools that need one (`helium-browser`, Mango keybinds) |
| torbrowser-launcher | pacman | Tor Browser |
| telegram-desktop, signal-desktop, vesktop-bin | pacman, AUR | chat |
| evince, onlyoffice-bin | pacman, AUR | PDF (OnlyOffice is the default) and office |
| mpv, mpv-modernz | pacman, AUR | video player and its OSC |
| playerctl, iptvnator-bin | pacman, AUR | media keys; IPTV (argos) |
| dolphin, ark, kio-fuse, ffmpegthumbs, kdegraphics-thumbnailers | pacman | file manager, archives, thumbnails |
| kconfig, archlinux-xdg-menu | pacman | `kwriteconfig6` (README), Dolphin's "Open With" outside Plasma |
| gwenview, kimageformats | pacman | image viewer (+ AVIF, HEIF, JXL, RAW…) |
| keepassxc, syncthing | pacman | passwords, synced to `~/Passwords` |
| gnome-keyring, gcr-4, libsecret | pacman | keyring, SSH agent, `secret-tool` (API keys) |
| sequoia-sq | pacman | OpenPGP |
| localsend-bin | AUR | LAN file sharing |
| blender | pacman | arpano |

### Development

| Package | Repo | For |
| --- | --- | --- |
| ninja, valgrind, gdb, gef, pkgconf | pacman | build, debugging |
| man-pages, man-db | pacman | man pages (includes the POSIX ones) |
| lazygit, duckdb, btop, jq, ripgrep, fd | pacman | the usual CLI tools |
| nix | pacman | optional, for Nix devshells |

### Network, security, VMs

| Package | Repo | For |
| --- | --- | --- |
| networkmanager, tailscale, openssh | pacman | network, VPN mesh, sshd |
| nftables, iptables | pacman | firewall; the libvirt/Docker forward unit (system.md) |
| tor, torsocks, proxychains-ng | pacman | local Tor client and wrappers |
| openvpn | pacman | lab VPNs |
| wireshark-qt | pacman | packet capture |
| docker | pacman | containers |
| zram-generator | pacman | compressed swap in RAM |
| linux-cachyos, linux-cachyos-headers, amd-ucode, linux-firmware | CachyOS, pacman | kernel (headers for any DKMS module), microcode |
| limine, limine-mkinitcpio-hook | pacman, AUR | bootloader |
| plymouth | pacman | boot splash (default theme) |
| qemu-desktop, libvirt, virt-manager, virt-viewer, dnsmasq | pacman | VMs with NAT networking |
| swtpm, virtiofsd, edk2-ovmf, spice-gtk | pacman | TPM, shared folders, UEFI, USB redirection |
| guestfs-tools, libguestfs | pacman | `virt-*` disk image tools |
| virtio-win, quickemu | AUR | Windows drivers ISO; quick VM downloads |

### Pentesting

| Package | Repo | For |
| --- | --- | --- |
| nmap, openbsd-netcat, inetutils, arp-scan, tcpdump, bc | pacman | network basics |
| hydra, hashcat, john | pacman | cracking |
| samba, cifs-utils | pacman | `smbclient`, mounting shares |
| wpscan, exploitdb, metasploit, sqlmap, sslscan | pacman | scanners and frameworks |
| impacket, perl-image-exiftool, python-jsbeautifier | pacman | Windows protocols, `exiftool`, `js-beautify` |
| openssl, openldap, binwalk, ghidra | pacman | crypto, LDAP tools, firmware, reversing |
| burpsuite, ffuf, smbmap, whatweb, pspy, cewl-git, ruby-evil-winrm, hashid | AUR | web proxy, fuzzing, SMB, recon, process spying, wordlist generation, WinRM, hash identification |
| seclists, rockyou | AUR | wordlists: `/usr/share/seclists`, `/usr/share/dict/rockyou.txt` |

### argos

| Package | Repo | For |
| --- | --- | --- |
| linux-cachyos-nvidia-open, nvidia-utils, lib32-nvidia-utils, nvidia-settings, libva-nvidia-driver, nvtop | CachyOS, pacman, multilib | NVIDIA driver, VA-API, GPU monitor |
| steam, gamescope, protontricks, umu-launcher | multilib, pacman | games |
| proton-ge-custom-bin, heroic-games-launcher-bin, lib32-extest | AUR | Proton-GE, Epic/GOG, Steam Input on Wayland |
| gamemode, lib32-gamemode, libnotify | pacman, multilib | GameMode (and its start/end notifications) |
| vulkan-tools, mesa-utils, lib32-pipewire, lib32-vulkan-icd-loader | pacman, multilib | `vulkaninfo`/`glxinfo`, 32-bit audio and Vulkan |

### arpano

| Package | Repo | For |
| --- | --- | --- |
| rocm-core, hip-runtime-amd, rocm-opencl-runtime | pacman | ROCm (HIP + OpenCL) |
| radeontop, nvtop | pacman | GPU monitors |
| cups, gutenprint, avahi, nss-mdns | pacman | printing and printer discovery |
| bluez, bluez-utils | pacman | Bluetooth |
