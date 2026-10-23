# System configuration (not stowed)

Stow only manages `$HOME`. This is the system-level setup for the two
machines, as a checklist to go through by hand after installing: the file to
write or the command to run for each piece.

Packages are in [packages.md](packages.md); the home config is in the stow
packages (see [README.md](README.md)).

| Machine | What it is | Sections |
| --- | --- | --- |
| monad | Desktop, Ryzen 5 3600 + NVIDIA, gaming, encrypted data HDD | Both machines, monad |
| arpano | AMD workstation (ROCm), printing, Bluetooth; work-only | Both machines, arpano |

---

## Both machines

### Locale and time

- Time zone: `ln -sf /usr/share/zoneinfo/Europe/Madrid /etc/localtime`
- Uncomment `en_US.UTF-8 UTF-8` and `es_ES.UTF-8 UTF-8` in `/etc/locale.gen`,
  then `locale-gen`.
- `/etc/locale.conf`:

  ```ini
  LANG=en_US.UTF-8
  LC_ADDRESS=es_ES.UTF-8
  LC_IDENTIFICATION=es_ES.UTF-8
  LC_MEASUREMENT=es_ES.UTF-8
  LC_MONETARY=es_ES.UTF-8
  LC_NAME=es_ES.UTF-8
  LC_NUMERIC=es_ES.UTF-8
  LC_PAPER=es_ES.UTF-8
  LC_TELEPHONE=es_ES.UTF-8
  LC_TIME=es_ES.UTF-8
  ```

### User account

- UID 1000 and primary group `users` (GID 100), so files on disks you keep
  (monad's data HDD) still belong to you: ownership follows the UID, not the
  name. Arch's `useradd` would otherwise create a separate per-user group:

  ```bash
  useradd -m -u 1000 -g users -G wheel,video,render -s /usr/bin/zsh <user>
  ```

  (or `chsh -s /usr/bin/zsh` if the installer already created the user).
- Groups (they exist once the package that creates them is installed):

  | Group | For | Machines |
  | --- | --- | --- |
  | wheel, video, render | sudo, GPU access | both |
  | wireshark | capturing without root | both |
  | docker | docker without sudo | both |
  | libvirt, kvm | virt-manager / QEMU | both |
  | gamemode | GameMode's renice | monad |

  `usermod -aG wheel,video,render,wireshark,docker,libvirt,kvm <user>`
  (plus `gamemode` on monad).

### Base services

- `systemctl enable plocate-updatedb.timer` (`locate`).
- `systemctl enable paccache.timer` (`pacman-contrib`: trims the package
  cache weekly).
- `dconf`, `gvfs` and the Mesa/Vulkan loaders only need to be installed.

### Audio

PipeWire with ALSA, PulseAudio and JACK compatibility: install `pipewire
pipewire-alsa pipewire-pulse pipewire-jack wireplumber` (plus
`lib32-pipewire` on monad). The user units start by themselves.

### Keyring and SSH agent

- GNOME Keyring unlocks at login through PAM: Arch's `/etc/pam.d/sddm`
  already has the `pam_gnome_keyring.so` lines.
- SSH keys are served by **gcr-ssh-agent** (gcr-4):
  `systemctl --user enable gcr-ssh-agent.socket`. `SSH_AUTH_SOCK` is set in
  `~/.config/zsh/.zshenv` (and in systemd by the socket unit itself). Don't
  enable OpenSSH's own `ssh-agent`.
- git and jj sign with `~/.ssh/id_ed25519.pub`: restore your SSH keys.
- The API keys live in the same keyring (README → "API keys").

### Tor (client only)

A local Tor client on `127.0.0.1:9050` for explicitly proxied apps: no
relay/exit, no control port, no open ports, no DNS change, no transparent
proxying. Tor Browser keeps its own bundled Tor.

`/etc/tor/torrc` (replace Arch's sample; the first three lines are from
Arch's stock torrc and are needed because its unit starts as root):

```ini
User tor
Log notice syslog
DataDirectory /var/lib/tor

SOCKSPort 127.0.0.1:9050 IsolateDestAddr IsolateSOCKSAuth
ClientOnly 1
## SafeSocks would reject IP-only SOCKS requests. It is a global option, and
## Telegram always connects to its DCs by raw IP, so it must be off.
SafeSocks 0
## Warn (don't reject) when an app hands Tor a bare IP.
WarnUnsafeSocks 0

BridgeRelay 0
ExitPolicy reject *:*
PublishServerDescriptor 0
AutomapHostsSuffixes .onion,.exit
ShutdownWaitLength 30
```

`systemctl enable --now tor`, and wait for "Bootstrapped 100%"
(`journalctl -u tor -b`).

- Browsing: launch `torbrowser-launcher` directly, not through
  proxychains/torsocks.
- CLI: `torsocks curl https://check.torproject.org/api/ip`, or
  `curl --proxy socks5h://127.0.0.1:9050 …`. The `h` matters: it makes Tor
  resolve the name, so DNS doesn't leak.
- Limits: these wrappers are not a VPN, sandbox or kill switch. Tor carries
  TCP only (no ping, UDP or SYN scans), and static binaries or apps with
  their own networking may bypass them. Use the lab VPN for lab targets,
  not Tor exits.

### ProxyChains-NG

Strict single SOCKS5 hop to Tor with proxied DNS; connections fail instead
of going direct if Tor is down. `/etc/proxychains.conf`:

```ini
strict_chain

proxy_dns

remote_dns_subnet 224
tcp_read_time_out 15000
tcp_connect_time_out 8000
localnet 127.0.0.0/255.0.0.0
[ProxyList]
socks5 127.0.0.1 9050
```

Usage: `proxychains4 -f /etc/proxychains.conf curl https://check.torproject.org/api/ip`.

### Docker, Wireshark, OpenVPN

- `systemctl enable --now docker.service` + the `docker` group. Ports 80/443
  from `docker0` are opened in the firewall below.
- `wireshark-qt` + the `wireshark` group.
- OpenVPN: just the package; connections are started by hand.

### Firewall

Drop by default, with these openings:

| | |
| --- | --- |
| TCP | 22 (ssh), 80, 443, 4444, 22000 (Syncthing), 53317 (LocalSend) |
| UDP | 21027, 22000 (Syncthing), 41641 (Tailscale), 53317 (LocalSend) |
| Trusted interfaces | lo, tailscale0, virbr0, virbr1 |
| Per interface | docker0: TCP 80, 443 · virbr0: UDP 53, 67 (DNS/DHCP for VMs) |
| Other | ping allowed, loose reverse-path filter, refused connections not logged |

`/etc/nftables.conf`. It replaces only its own table, never `flush ruleset`,
so `systemctl reload nftables` doesn't wipe Docker's, libvirt's or
Tailscale's rules (checked with `nft -c`). Enable with
`systemctl enable --now nftables`.

```nft
#!/usr/bin/nft -f
destroy table inet dotfiles-fw

table inet dotfiles-fw {
  chain rpfilter {
    type filter hook prerouting priority mangle + 10; policy drop;

    meta nfproto ipv4 udp sport . udp dport { 67 . 68, 68 . 67 } accept comment "DHCPv4 client/server"
    fib saddr . mark oif exists accept comment "loose reverse-path filter"
  }

  chain input {
    type filter hook input priority filter; policy drop;

    iifname { "lo", "tailscale0", "virbr0", "virbr1" } accept comment "trusted interfaces"

    # Some ICMPv6 types like NDP are untracked
    ct state vmap {
      invalid : drop,
      established : accept,
      related : accept,
      new : jump input-allow,
      untracked : jump input-allow,
    }
  }

  chain input-allow {
    tcp dport { 22, 80, 443, 4444, 22000, 53317 } accept
    udp dport { 21027, 22000, 41641, 53317 } accept
    iifname "docker0" tcp dport { 80, 443 } accept comment "Docker"
    iifname "virbr0" udp dport { 53, 67 } accept comment "libvirt NAT: DNS/DHCP from guests"
    icmp type echo-request accept comment "ping"
    icmpv6 type != { nd-redirect, 139 } accept comment "Accept all ICMPv6 messages except redirects and node information queries (type 139). See RFC 4890, section 4.4."
    ip6 daddr fe80::/64 udp dport 546 accept comment "DHCPv6 client"
  }
}
```

### Kernel, bootloader, initramfs

Zen kernel, Limine on UEFI, a systemd-based quiet initramfs, Plymouth with
adi1090x's **splash** theme, AMD microcode.

- Packages: `linux-zen linux-zen-headers amd-ucode linux-firmware limine plymouth`,
  and from the AUR `limine-mkinitcpio-hook` (keeps `/boot/limine.conf`
  entries in sync with installed kernels) and `plymouth-themes-adi1090x-git`.
- Kernel command line: `quiet splash loglevel=0` plus the root. With
  limine-mkinitcpio-hook it goes in `/etc/default/limine`, e.g.
  `KERNEL_CMDLINE[default]="rd.luks.name=<LUKS-UUID>=cryptroot rd.luks.options=discard root=/dev/mapper/cryptroot rootflags=subvol=@ rw quiet splash loglevel=0"`
  (`discard` only on monad's SSD; check the hook's docs for the exact
  variable names).
- `/etc/mkinitcpio.conf.d/10-initrd.conf`:

  ```bash
  HOOKS=(systemd autodetect microcode modconf kms keyboard sd-vconsole block plymouth sd-encrypt filesystems fsck)
  ```

- `/etc/plymouth/plymouthd.conf`:

  ```ini
  [Daemon]
  Theme=splash
  ```

  then `mkinitcpio -P`.

### Display manager: SDDM + SilentSDDM

SDDM on Wayland with the Silent theme (AUR `sddm-silent-theme`, installed to
`/usr/share/sddm/themes/silent`). The greeter runs on KWin (`kwin` package);
`weston --shell=kiosk` works too. `/etc/sddm.conf.d/10-silent.conf`:

```ini
[General]
DisplayServer=wayland
GreeterEnvironment=QML2_IMPORT_PATH=/usr/share/sddm/themes/silent/components/,QT_IM_MODULE=qtvirtualkeyboard
InputMethod=qtvirtualkeyboard
Numlock=none

[Theme]
Current=silent

[Wayland]
CompositorCommand=kwin_wayland --no-global-shortcuts --no-kactivities --no-lockscreen --locale1
EnableHiDPI=true
```

`systemctl enable sddm`. Profile picture, through AccountsService:

```bash
sudo install -Dm644 ~/dotfiles/face/.face.png /var/lib/AccountsService/icons/$USER
printf '[User]\nIcon=/var/lib/AccountsService/icons/%s\n' "$USER" | sudo install -Dm600 /dev/stdin /var/lib/AccountsService/users/$USER
```

### Networking: NetworkManager + Quad9 over TLS

- `systemctl enable --now NetworkManager systemd-resolved`
- `ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf`
- `/etc/systemd/resolved.conf.d/quad9.conf`:

  ```ini
  [Resolve]
  DNS=9.9.9.9#dns.quad9.net 149.112.112.112#dns.quad9.net
  FallbackDNS=9.9.9.9#dns.quad9.net 149.112.112.112#dns.quad9.net
  Domains=~.
  DNSSEC=true
  DNSOverTLS=true
  ```

- `/etc/NetworkManager/conf.d/50-dns-wifi.conf`:

  ```ini
  [main]
  dns=systemd-resolved

  [connection]
  # Wi-Fi power saving off
  wifi.powersave=2
  ```

### OpenSSH server

`systemctl enable --now sshd` and `/etc/ssh/sshd_config.d/50-hardening.conf`:

```
PermitRootLogin no
PasswordAuthentication no
```

`KbdInteractiveAuthentication` stays at its default (yes), which still
allows PAM password prompts. Add `KbdInteractiveAuthentication no` for keys
only.

### Tailscale

`systemctl enable --now tailscaled`, then `tailscale up`. UDP 41641 and
`tailscale0` are handled in the firewall.

### zram swap

zstd, 100% of RAM. `/etc/systemd/zram-generator.conf`:

```ini
[zram0]
zram-size = ram
compression-algorithm = zstd
```

Reboot (or `systemctl daemon-reload && systemctl start systemd-zram-setup@zram0`).

### Virtual machines: libvirt / QEMU / virt-manager

- `systemctl enable --now libvirtd.socket libvirt-guests.service`, groups
  `libvirt` and `kvm`.
- Guests only start if marked autostart, and shut down cleanly with the
  host. `/etc/conf.d/libvirt-guests`:

  ```bash
  ON_BOOT=ignore
  ON_SHUTDOWN=shutdown
  ```

- Nested virtualization, `/etc/modprobe.d/kvm-nested.conf`:

  ```
  options kvm_amd nested=1
  options kvm_intel nested=1
  ```

- Default NAT network, once:
  `virsh -c qemu:///system net-autostart default && virsh -c qemu:///system net-start default`
  (needs `dnsmasq`).
- UEFI/Secure Boot guests → `edk2-ovmf`; TPM 2.0 (Windows 11) → `swtpm`;
  shared folders → `virtiofsd`; USB redirection → `spice-gtk`. The Windows
  virtio drivers ISO (AUR `virtio-win`) is at
  `/var/lib/libvirt/images/virtio-win.iso`.
- Docker sets iptables' FORWARD policy to DROP, which breaks the guests' NAT.
  `/etc/systemd/system/libvirt-docker-forward.service`:

  ```ini
  [Unit]
  Description=Allow libvirt NAT (virbr0) forwarding past Docker's FORWARD policy
  After=docker.service libvirtd.service nftables.service
  Wants=docker.service

  [Service]
  Type=oneshot
  RemainAfterExit=yes
  ExecStart=/usr/bin/iptables -I FORWARD -i virbr0 -j ACCEPT
  ExecStart=/usr/bin/iptables -I FORWARD -o virbr0 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
  ExecStop=-/usr/bin/iptables -D FORWARD -i virbr0 -j ACCEPT
  ExecStop=-/usr/bin/iptables -D FORWARD -o virbr0 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

  [Install]
  WantedBy=multi-user.target
  ```

  `systemctl enable --now libvirt-docker-forward`.

---

## monad (NVIDIA desktop, gaming)

### NVIDIA

Open kernel module, modesetting (+fbdev), VRAM preserved across suspend,
VA-API through libva-nvidia-driver.

- Packages: `nvidia-open-dkms` (DKMS because of the Zen kernel),
  `nvidia-utils lib32-nvidia-utils nvidia-settings libva-nvidia-driver nvtop`.
  `nvidia-utils` already blacklists nouveau.
- `/etc/modprobe.d/nvidia.conf`:

  ```
  options nvidia NVreg_PreserveVideoMemoryAllocations=1 NVreg_UseKernelSuspendNotifiers=1
  options nvidia-drm modeset=1 fbdev=1
  softdep nvidia post: nvidia-uvm
  ```

- `systemctl enable nvidia-suspend nvidia-hibernate nvidia-resume`
- `/etc/environment`:

  ```bash
  LIBVA_DRIVER_NAME=nvidia
  NVD_BACKEND=direct
  # NVIDIA's default shader cache is ~1 GB and gets evicted: recompiles and
  # stutter. DXVK/VKD3D pipelines live here too.
  __GL_SHADER_DISK_CACHE_SIZE=12000000000
  __GL_SHADER_DISK_CACHE_SKIP_CLEANUP=1
  ```

### Gaming

- Enable `[multilib]` in `/etc/pacman.conf` for the 32-bit graphics and
  audio libraries (`lib32-nvidia-utils`, `lib32-pipewire`,
  `lib32-vulkan-icd-loader`, `lib32-gamemode`).
- Steam with Proton-GE, protontricks, gamescope (a gamescope session is
  `gamescope -- steam -gamepadui`), Heroic, umu-launcher: see packages.md.
- Steam Input on Wayland: AUR `lib32-extest`, then start Steam with
  `LD_PRELOAD=/usr/lib32/libextest.so`.
- GameMode + the `gamemode` group. `/etc/gamemode.ini`:

  ```ini
  [general]
  renice=10
  softrealtime=auto
  inhibit_screensaver=1

  [custom]
  start=notify-send 'GameMode started'
  end=notify-send 'GameMode ended'
  ```

- NTSYNC for Wine/Proton (`linux-zen` has the module):
  - `/etc/modules-load.d/ntsync.conf` → `ntsync`
  - `/etc/udev/rules.d/99-ntsync.rules` → `KERNEL=="ntsync", MODE="0660", TAG+="uaccess"`
- No split-lock mitigation slowdown, `/etc/sysctl.d/99-gaming.conf`:
  `kernel.split_lock_mitigate = 0`

### Storage layout

- LUKS `cryptroot` (discards allowed) with btrfs subvolumes, all
  `compress=zstd,noatime`: `@` → `/`, `@home` → `/home`, `@log` →
  `/var/log`, `@swap` → `/swap` (`nofail`, holds `/swap/swapfile`). ESP at
  `/boot` (`fmask=0077,dmask=0077`).
- `systemctl enable fstrim.timer`
- Second disk: below.

### Encrypted data HDD

The second disk (LUKS + btrfs, mounted at `/data`) is kept across the
reinstall. The steps, including where its key lives, are in your local notes
(`~/Documents/arch-install-guide.md`), not in this repo.

---

## arpano (AMD workstation, work-only)

- **AMD GPU / ROCm**: amdgpu in the initramfs for early KMS,
  `/etc/mkinitcpio.conf.d/20-amdgpu.conf` → `MODULES=(amdgpu)` (then
  `mkinitcpio -P`). ROCm runtime + OpenCL, radeontop, nvtop (packages).
  `/etc/environment`:

  ```bash
  HSA_OVERRIDE_GFX_VERSION=11.0.0
  HIP_PATH=/opt/rocm
  ROCM_PATH=/opt/rocm
  ```

  Arch's `blender` package supports HIP rendering.
- **Printing**: CUPS with Gutenprint drivers, Avahi for discovery.
  - `systemctl enable --now cups.socket avahi-daemon`
  - `/etc/nsswitch.conf`: add `mdns_minimal [NOTFOUND=return]` before
    `resolve` on the `hosts:` line.
  - Avahi and resolved both want port 5353: with Avahi, set
    `MulticastDNS=no` in a resolved drop-in.
  - Printer discovery needs UDP 5353, which isn't in the nftables file above;
    add it on arpano if needed.
- **Bluetooth**: `systemctl enable --now bluetooth`; `AutoEnable=true` under
  `[Policy]` in `/etc/bluetooth/main.conf` powers it on at boot (bluez's
  default already).
- **NIC after resume**: reload the Realtek driver and restart
  NetworkManager, as a systemd sleep hook,
  `/usr/lib/systemd/system-sleep/r8125-reload` (executable):

  ```sh
  #!/bin/sh
  case "$1" in
    post)
      modprobe -r r8125
      modprobe r8125
      sleep 2
      systemctl restart NetworkManager.service
      ;;
  esac
  ```

  `r8125` isn't an in-tree module (the kernel drives RTL8125 with `r8169`):
  check `lspci -k` and reload whichever driver the NIC really uses, or
  install AUR `r8125-dkms` for Realtek's own driver.
- **Storage**: LUKS `cryptroot` with btrfs subvolume `@` mounted on `/`
  **and** on `/home` (both `subvol=@`, which looks unintended: give `/home`
  its own `@home` this time). ESP at `/boot` (`fmask=0022,dmask=0022`), no
  swap besides zram.
- **Work-only**: none of the gaming packages or settings on arpano.
