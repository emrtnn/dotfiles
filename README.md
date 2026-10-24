# dotfiles

Home configuration for my two Arch Linux machines, **argos** (NVIDIA desktop)
and **arpano** (AMD workstation), managed with GNU Stow: Mango + Noctalia,
zsh, tmux, Neovim, Doom Emacs and the Caelus theme everywhere.

- [packages.md](packages.md): what to install (pacman, AUR, mason).
- [system.md](system.md): system-level setup (boot, firewall, DNS, Tor,
  SDDM, NVIDIA, libvirt, the data HDD…), as a manual checklist.

Nothing here is scripted: you stow the packages and go through the steps
below by hand.

## Layout

Every top-level directory is a stow package that mirrors `$HOME`
(`zsh/.config/zsh/.zshrc` → `~/.config/zsh/.zshrc`), except:

- `librewolf/`: the LibreWolf theme (`userChrome.css`, `userContent.css`,
  `user.js`). It goes inside the browser profile by hand (see "LibreWolf
  theme" below); **don't stow it**.
- `README.md`, `packages.md`, `system.md`, `.luarc.json` (Lua LSP globals),
  `.stowrc` (target `~`), `.gitignore`.

### Two kinds of packages

- **Linked directories**: `nvim`, `doom`, `mango`. Stowed normally, stow
  "folds" them: `~/.config/nvim` becomes a single symlink to
  `~/dotfiles/nvim/.config/nvim`, so edits and new files apply immediately
  and `lazy-lock.json` updates land in the repo.
- **Everything else** is stowed with `--no-folding`: real directories in
  `$HOME`, one symlink per file. Many of those directories also hold state
  that must not end up in the repo (zsh history in `~/.config/zsh`, the
  `gtk.css`/`noctalia.css`/bat theme Noctalia writes, the `.wants/` links
  `systemctl --user enable` creates). After adding a *new* file to one of
  these packages, restow it: `stow -R --no-folding <pkg>`.

Before the **first** stow on a fresh install, create the directories that
must stay real (otherwise stow would fold all of `~/.config` into the first
package):

```bash
mkdir -p ~/.config/systemd/user ~/.local/bin ~/.local/share ~/Pictures
```

## Stowing

Same on both machines:

```bash
cd ~/dotfiles
stow nvim doom mango
stow --no-folding zsh git jj tmux yazi bat tuicr face wallpapers \
  gtk cursor qt dolphin mimeapps emacs mpv xdg-desktop-portal cliphist foot noctalia satty
stow --no-folding steam      # argos only (gaming)
```

Remove a package with `stow -D <pkg>`. Stow never overwrites existing files:
if it reports a conflict, move the file away and run it again.

## Packages

| Package | Puts in `$HOME` | What |
| --- | --- | --- |
| `zsh` | `~/.zshenv`, `~/.config/zsh/{.zshenv,.zshrc}` | environment variables (`.zshenv`, see below); zsh with eza, fzf, zoxide, carapace, yazi; vi mode; history; aliases |
| `git` | `~/.config/git/{config,allowed_signers}` | identity, SSH commit/tag signing, defaults, aliases |
| `jj` | `~/.config/jj/config.toml` | Jujutsu: same identity and signing key, ediff merge tool |
| `tmux` | `~/.config/tmux/tmux.conf` | `C-a` prefix, vi mode, Caelus status bar, smart-splits navigation, resurrect + continuum via TPM |
| `nvim` *(linked)* | `~/.config/nvim` | lazy.nvim config; `lua/plugins/mason.lua` installs the language servers/formatters/linters |
| `yazi` | `~/.config/yazi/{yazi.toml,theme.toml,caelus.tmTheme,plugins/full-border.yazi}` | file manager with the Caelus theme |
| `bat` | `~/.config/bat/{config,themes/caelus.tmTheme}` | pager theme |
| `tuicr` | `~/.config/tuicr/{config.toml,themes/}` | code review TUI with the Caelus theme |
| `face` | `~/.face.png` | account picture |
| `wallpapers` | `~/Pictures/Wallpapers` | wallpapers (Noctalia reads this folder) |
| `gtk` | `~/.config/gtk-{3,4}.0/settings.ini`, `~/.config/gtk-4.0/gtk.css`, `~/.gtkrc-2.0` | adw-gtk3 dark, Papirus, Bibata cursor |
| `cursor` | `~/.icons/default/index.theme`, `~/.local/share/icons/default/index.theme`, `~/.Xresources` | default cursor for X and XWayland apps |
| `qt` | `~/.config/qt6ct/{qt6ct.conf,colors/Caelus.conf}` | Qt: Breeze style, Caelus palette, Papirus |
| `dolphin` | `~/.local/share/color-schemes/Caelus.colors`, `~/.local/share/kio/servicemenus/open-in-yazi.desktop` | KDE color scheme and "Open in Yazi" (settings: below) |
| `mimeapps` | `~/.config/mimeapps.list` (+ the legacy `~/.local/share/applications` copy) | default apps: LibreWolf, Dolphin, Gwenview, OnlyOffice |
| `emacs` | `~/.config/systemd/user/emacs.service`, `~/.local/bin/emacs-ediff` | Emacs daemon with the graphical session; jj's merge tool |
| `doom` *(linked)* | `~/.config/doom` | Doom Emacs config and the Caelus theme |
| `mpv` | `~/.config/mpv/mpv.conf` | ModernZ instead of the built-in OSC |
| `mango` *(linked)* | `~/.config/mango` | compositor config |
| `xdg-desktop-portal` | `~/.config/xdg-desktop-portal/mango-portals.conf`, `~/.config/xdg-desktop-portal-wlr/config` | portals: wlr for screencast/screenshots, gtk for the rest |
| `cliphist` | `cliphist.service`, `cliphist-images.service` | clipboard history for Noctalia |
| `foot` | `~/.config/foot/foot.ini` | terminal |
| `noctalia` | `~/.config/noctalia/{config.toml,palettes/Caelus.json}` | shell: bar, launcher, notifications, lock, palette |
| `satty` | `~/.config/satty/config.toml` | screenshot annotation |
| `steam` | `~/.local/share/applications/steam.desktop` | Steam launcher with `LD_PRELOAD` of lib32-extest (Steam Input on Wayland; argos only) |

## Environment variables

Each variable lives where its scope is:

| File | Read by | Holds |
| --- | --- | --- |
| `~/.config/zsh/.zshenv` | every zsh (interactive or not, login or not) | PATH, EDITOR/VISUAL, XDG base dirs, `SSH_AUTH_SOCK`, `TMUX_TMPDIR`, npm prefix, `CHROME_PATH`/Puppeteer |
| `~/.config/zsh/.zshrc` | interactive zsh only | fzf options, aliases |
| `~/.config/mango/config/env.conf` | Mango and everything it starts | toolkit backends, Qt theme (qt6ct + Breeze), `XDG_MENU_PREFIX`, the Java fix, `BROWSER` (cursor: `misc.conf`) |

How they reach everything:

- SDDM starts Mango from a **non-interactive login zsh**, so Mango inherits
  `.zshenv` (but not `.zshrc`, which is why nothing session-wide goes there),
  then adds `env.conf` on top.
- Mango only passes the display and cursor variables to systemd. Apps
  Noctalia launches run as **systemd units**, so `autostart.conf` runs
  `dbus-update-activation-environment --systemd --all` to hand them Mango's
  whole environment (one of the methods on the Arch wiki's systemd/User page).
- `emacs.service` gets `SSH_AUTH_SOCK` from `gcr-ssh-agent.socket`, and
  `config.el` adds mason's bin to `exec-path` itself.

After changing `.zshenv` or `env.conf`, log out and back in.

## After stowing (manual steps)

Do these once per machine, after installing the packages from
[packages.md](packages.md) and going through [system.md](system.md).

### API keys

The keys live in your **login keyring** (GNOME Keyring: encrypted with your
login password, unlocked by PAM when SDDM logs you in). Nothing exports them
into the environment: the program that needs a key asks the keyring for it
when it needs it.

Store each key once per machine (`secret-tool` reads the value from the
prompt, so it doesn't end up in your shell history):

```bash
secret-tool store --label='Brave Search API key' env BRAVE_API_KEY
secret-tool store --label='Exa API key' env EXA_API_KEY
secret-tool store --label='Anthropic API key' env ANTHROPIC_API_KEY     # arpano, if not using /login
```

pi resolves `!command` values itself, at the moment it needs the key, and
keeps the result inside its own process:

- `~/.config/pi/web-search.json` (pi-web-access):

  ```json
  {
    "provider": "exa",
    "exaApiKey": "!secret-tool lookup env EXA_API_KEY",
    "braveApiKey": "!secret-tool lookup env BRAVE_API_KEY"
  }
  ```

- `~/.pi/agent/auth.json`, only for an Anthropic API key (with `/login` pi
  stores OAuth tokens there instead):

  ```json
  { "anthropic": { "type": "api_key", "key": "!secret-tool lookup env ANTHROPIC_API_KEY" } }
  ```

These files aren't stowed on purpose: pi writes to them, and a key pasted
into pi's settings would otherwise land in the repo.

For anything else that wants a key in its environment, give it to that one
command only: `FOO_API_KEY="$(secret-tool lookup env FOO_API_KEY)" some-tool`.

Check with `secret-tool lookup env BRAVE_API_KEY`, remove with
`secret-tool clear env BRAVE_API_KEY`; Seahorse shows them too.

### User services

```bash
systemctl --user daemon-reload
systemctl --user enable --now gcr-ssh-agent.socket syncthing.service
systemctl --user enable cliphist.service cliphist-images.service emacs.service
```

The Foot server isn't a service: Mango's `autostart.conf` runs `foot -s`.

### bat

```bash
bat cache --build      # registers the caelus theme
```

### Dolphin / KDE settings

Dolphin saves tabs, geometry and panels in `kdeglobals` and `dolphinrc`, so
these are set with `kwriteconfig6` instead of being stowed:

```bash
kwriteconfig6 --file kdeglobals --group General --key ColorScheme Caelus
kwriteconfig6 --file kdeglobals --group General --key TerminalApplication foot
kwriteconfig6 --file kdeglobals --group General --key TerminalService foot.desktop
kwriteconfig6 --file kdeglobals --group Icons --key Theme Papirus-Dark
kwriteconfig6 --file kdeglobals --group KDE --key SingleClick false

kwriteconfig6 --file dolphinrc --group General --key RememberOpenedTabs true
kwriteconfig6 --file dolphinrc --group General --key OpenExternallyCalledFolderInNewTab true
kwriteconfig6 --file dolphinrc --group General --key AlwaysShowTabBar true
kwriteconfig6 --file dolphinrc --group General --key ShowFullPath true
kwriteconfig6 --file dolphinrc --group General --key ShowToolTips true
kwriteconfig6 --file dolphinrc --group General --key ShowZoomSlider true
kwriteconfig6 --file dolphinrc --group General --key BrowseThroughArchives true
kwriteconfig6 --file dolphinrc --group IconsMode --key IconSize 48
kwriteconfig6 --file dolphinrc --group IconsMode --key PreviewSize 64
kwriteconfig6 --file dolphinrc --group PreviewSettings --key Plugins "directorythumbnail,imagethumbnail,jpegthumbnail,svgthumbnail,ffmpegthumbs,gsthumbnail"
kwriteconfig6 --file dolphinrc --group UiSettings --key ColorScheme Caelus
```

Outside Plasma, Dolphin's "Open With" list is empty unless KService has a
menu file: `archlinux-xdg-menu` provides it, selected by
`XDG_MENU_PREFIX=arch-` in Mango's `env.conf`. Rebuild the cache once after
installing apps: `XDG_MENU_PREFIX=arch- kbuildsycoca6 --noincremental`.

### GTK / dconf

```bash
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
gsettings set org.gnome.desktop.interface gtk-theme 'adw-gtk3'
gsettings set org.gnome.desktop.interface icon-theme 'Papirus-Dark'
gsettings set org.gnome.desktop.interface cursor-theme 'Bibata-Modern-Ice'
gsettings set org.gnome.desktop.interface cursor-size 24
```

### LibreWolf theme

LibreWolf names its profile folder randomly, so the theme is installed by
hand once the profile exists:

1. Start LibreWolf once and quit it; that creates the profile.
2. Find the folder: `about:support` → "Profile Folder" → *Open Folder*
   (or `about:profiles`, "Root Directory"). Usually
   `~/.config/librewolf/librewolf/<random>.default-default`.
3. Copy the theme in (use `ln -s` instead of `cp` for the two CSS files if
   you want edits in the repo to apply directly):

   ```bash
   profile=~/.config/librewolf/librewolf/XXXXXXXX.default-default   # yours
   mkdir -p "$profile/chrome"
   cp ~/dotfiles/librewolf/userChrome.css ~/dotfiles/librewolf/userContent.css "$profile/chrome/"
   cp ~/dotfiles/librewolf/user.js "$profile/"
   ```

   `user.js` turns on `toolkit.legacyUserProfileCustomizations.stylesheets`
   (without it LibreWolf ignores `chrome/`) and keeps the Browser Toolbox
   off. If the profile already has a `user.js`, append to it instead
   (`cat … >> "$profile/user.js"`), or set the three prefs in `about:config`.
4. Start LibreWolf. The CSS is read at startup, so restart after any change.

### Neovim

First start: lazy.nvim installs the plugins, then mason-tool-installer
installs the language servers, formatters and linters in the background
(`:Mason` shows progress). Updates: `:Lazy update`, `:MasonToolsUpdate`.

### Doom Emacs

```bash
git clone --depth 1 --recurse-submodules --shallow-submodules https://github.com/doomemacs/doomemacs ~/.config/emacs
~/.config/emacs/bin/doom sync
systemctl --user enable --now emacs.service
```

Doom (lsp-mode, apheleia) uses the binaries mason installed for Neovim: the
`~/.config/zsh/.zshenv` puts `~/.local/share/nvim/mason/bin` on PATH and
`config.el` adds it to `exec-path`, so start Neovim once first. Tree-sitter
grammars are built by Doom when a mode first needs them.

### tmux

TPM clones itself into `~/.local/share/tmux/plugins` on the first start and
installs resurrect + continuum. `prefix + U` updates them.

### Syncthing

As on the [Arch wiki](https://wiki.archlinux.org/title/Syncthing): the
package's user unit (`syncthing.service`, enabled above) runs it, and you
configure it in the web GUI at <http://127.0.0.1:8384>:

- **Devices** ("Auto Accept" off): arpano, argos and iphone. Their
  device IDs are in your local notes, not in this repo: with global
  discovery on, a device ID is enough to look up that device's current IP.
- **Folder**: ID and label `keepass`, path `~/Passwords`, Send & Receive,
  shared with all four devices, File Versioning *Staggered* with a maximum
  age of 90 days (keeps replaced databases in `~/Passwords/.stversions`).
- **Settings → General → Anonymous Usage Reporting**: off.

A fresh install gets a new device ID that every other device must re-add.
To keep the old one, restore `cert.pem` and `key.pem` into
`~/.local/state/syncthing/` before the first start.

## Caelus palette

Hand-copied into the files that can't import anything (Neovim, Doom,
LibreWolf CSS, Mango, tmux, foot, Noctalia…); keep them in sync with this
table.

| Role | Name | Hex |
| --- | --- | --- |
| background | bg | `#0f0f0f` |
| sunken: status/tab bars | gray0 | `#141514` |
| raised: popups, inputs, cursor line | gray1 | `#1e1f1e` |
| hover, selected rows | gray2 | `#272a28` |
| selection, borders | gray3 | `#3b403c` |
| inactive borders, line numbers | gray4 | `#585f5b` |
| disabled text | gray5 | `#6c756f` |
| comments, muted text | gray6 | `#888e7b` |
| secondary text | gray7 | `#9a9c8b` |
| operators, punctuation | gray8 | `#b6b69a` |
| dimmed foreground | gray9 | `#d9cdb5` |
| foreground | fg | `#f4decd` |
| THE accent: focus, selection, keywords | orange / orangeLight | `#ef934d` / `#f4b585` |
| functions, warnings | yellow | `#efbf71` |
| errors, deletions, urgent | red / redLight | `#f16e65` / `#ef968f` |
| strings, additions | green / greenLight | `#72ca68` / `#98d694` |
| types, hints | cyan / cyanLight | `#7ec9a3` / `#abd4bf` |
| modules, info, links / fields | blue / blueLight | `#71b4d6` / `#b0d4e8` |
| numbers, constants | magenta / magentaLight | `#e28dc6` / `#ebadd6` |
| diff/message tints (15% over bg) | greenTint, redTint, blueTint, orangeTint | `#1e2b1c`, `#311d1c`, `#1e282d`, `#312318` |

Terminal ANSI order (black red green yellow blue magenta cyan white):
normal `bg red green orange blue magenta cyan gray9`, bright
`gray3 redLight greenLight orangeLight blueLight magentaLight cyanLight fg`.
