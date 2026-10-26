# INSTALL GUIDE

## **Conventions**

- Until section 11, everything runs as root (live USB or chroot). After that,
  as your user with `sudo` where needed.
- Shell variables (`SYS`, `ESP`, …) only live in the shell where you set
  them. The chroot is a new shell: set them again there.
- Never trust `nvme0`/`nvme1`/`sda` names across reboots: the kernel numbers
  disks in the order they appear, which can change every boot. Identify disks
  by **serial** before partitioning and by **label/UUID** after.

---

## Contents

0. [Before you start](#0-before-you-start)
1. [Live USB](#1-live-usb)
2. [Identify the disks](#2-identify-the-disks)
3. [Partition](#3-partition)
4. [Encrypt root](#4-encrypt-root)
5. [Btrfs subvolumes and mounts](#5-btrfs-subvolumes-and-mounts)
6. [Encrypted swap](#6-encrypted-swap)
7. [Encrypted data disk](#7-encrypted-data-disk)
8. [Bootstrap the system](#8-bootstrap-the-system)
9. [Base configuration (chroot)](#9-base-configuration-chroot)
10. [CachyOS, kernel, initramfs, Limine (chroot)](#10-cachyos-kernel-initramfs-limine-chroot)
11. [First boot](#11-first-boot)
12. [Packages](#12-packages)
13. [Stow the dotfiles](#13-stow-the-dotfiles)
14. [System configuration](#14-system-configuration)
15. [User setup](#15-user-setup)
16. [Snapshots](#16-snapshots)
17. [Secure Boot](#17-secure-boot)
18. [Troubleshooting](#18-troubleshooting)
19. [Reference: repository, environment, palette](#19-reference)

---

## 0. Before you start

**Back up** everything that isn't in this repo. The wipe can't be undone.

- [ ] `~/.ssh` (git and jj sign with `id_ed25519.pub`)
- [ ] GPG keys (`gpg --export-secret-keys --armor`) and `~/.password-store`
- [ ] age key for sops, if any (`~/.config/sops/age/keys.txt`)
- [ ] KeePassXC database (also synced to `~/Passwords`)
- [ ] Anything not pushed, browser profiles

**Firmware (BIOS)**

| Setting | Value | Why |
| --- | --- | --- |
| CSM / Launch CSM / Legacy boot | **Disabled** | With CSM on, the USB can boot in legacy mode; then UEFI entries can't be created and Secure Boot is impossible. |
| Secure Boot | **Disabled** for now | The Arch ISO isn't signed. Enabled in section 17. |
| Fast Boot | Disabled (not "Ultra Fast") | Ultra Fast skips USB init: dead keyboard in Limine and in the BIOS. |

Gigabyte hides the Secure Boot menu until CSM is off. On AMI Aptio boards CSM
is under **Boot** (or **Advanced → CSM Configuration**).

Write the latest Arch ISO to a USB stick. Boot it through the entry named
**"UEFI: <your USB>"**, not the plain one.

---

## 1. Live USB

```
cat /sys/firmware/efi/fw_platform_size
iwctl
timedatectl set-ntp true
```

- `fw_platform_size` must print `64`. "No such file" means the USB booted in
  BIOS mode: reboot and pick the UEFI entry (or disable CSM).
- `iwctl`: Wi-Fi only. Inside: `station wlan0 scan`, `station wlan0 get-networks`,
  `station wlan0 connect "SSID"`. Check with `ping archlinux.org`.
- `timedatectl set-ntp true`: correct clock, or package signature checks fail.

---

## 2. Identify the disks

```
lsblk -o NAME,SIZE,MODEL,SERIAL,FSTYPE,LABEL
free -g
```

- Match each disk by **SERIAL** (also on the drive's sticker). Two identical
  drives show the same MODEL; the serial is the only safe way to tell them
  apart.
- `free -g`: your RAM, used to size the swap partition.

Set the variables for **this boot**:

```
SYS=/dev/nvme0n1     # the system disk, chosen by serial (monad: /dev/sdX)
DATA=/dev/nvme1n1    # the second NVMe. monad: the HDD (do NOT wipe it)
```

Partition names: NVMe appends `p` (`/dev/nvme0n1p1`), SATA doesn't
(`/dev/sda1`).

---

## 3. Partition

Destroys everything on `$SYS`. Check `echo $SYS` against the serial first.

```
wipefs -af $SYS
blkdiscard -f $SYS
cfdisk $SYS
```

- `wipefs -af`: erases all partition-table and filesystem signatures.
- `blkdiscard -f`: TRIMs the whole SSD, so old data is gone through normal
  means. If the drive refuses, carry on: encryption covers you.

In cfdisk (arrows to move, Enter to select):

1. **Select label type** → `gpt`.
2. **Free space** → `[ New ]` → `1G` → `[ Type ]` → **EFI System**.
3. **Free space** → `[ New ]` → the proposed size **minus your RAM** (e.g.
   `930.5G` shown, 16 GB RAM → type `914.5G`). Type stays **Linux filesystem**.
4. **Free space** → `[ New ]` → Enter (the rest, ≈ RAM size) → `[ Type ]` →
   **Linux swap**.
5. `[ Write ]` → `yes`. Nothing touches the disk before this. `[ Quit ]`.

Set the partition variables and check:

```
ESP=${SYS}p1 ROOT=${SYS}p2 SWAP=${SYS}p3     # SATA: ${SYS}1 ${SYS}2 ${SYS}3
lsblk $SYS
```

Types are labels for tools; they format nothing. cfdisk aligns to 1 MiB,
which suits LUKS with 4K sectors.

---

## 4. Encrypt root

```
cryptsetup luksFormat --type luks2 \
  --cipher aes-xts-plain64 --key-size 512 --hash sha512 \
  --pbkdf argon2id --iter-time 4000 \
  --sector-size 4096 --label cryptroot $ROOT

cryptsetup open --allow-discards \
  --perf-no_read_workqueue --perf-no_write_workqueue \
  --persistent $ROOT cryptroot

cryptsetup luksDump $ROOT | grep -E 'Version|PBKDF|Flags'
```

`luksFormat` (type `YES`, then your passphrase):

- `aes-xts-plain64`, `--key-size 512`: AES-256 in XTS mode (XTS splits the
  key in two), hardware-accelerated by AES-NI.
- `--pbkdf argon2id --iter-time 4000`: the passphrase is stretched with
  memory-hard Argon2id, tuned to ~4 s per attempt on this CPU. You pay it once
  per boot; an attacker pays it per guess.
- `--sector-size 4096`: 4 KiB crypto sectors, matching SSD pages.
- `--label cryptroot`: a name on the LUKS header. Later steps find the
  partition by this label, never by device name.

`open` creates `/dev/mapper/cryptroot`:

- `--allow-discards`: TRIM passes through (keeps the SSD fast; reveals which
  blocks are free, not their contents).
- `--perf-no_*_workqueue`: skip dm-crypt's queues, lower latency on SSDs.
- `--persistent`: stores those flags in the header, so no kernel parameters
  are needed for them.

`luksDump` must show `Version: 2`, `PBKDF: argon2id`, and the three flags.

---

## 5. Btrfs subvolumes and mounts

```
mkfs.fat -F32 -n ESP $ESP
mkfs.btrfs -L arch /dev/mapper/cryptroot

mount /dev/mapper/cryptroot /mnt
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@log
btrfs subvolume create /mnt/@pkg
btrfs subvolume create /mnt/@snapshots
btrfs subvolume list /mnt
umount /mnt
```

Check the `list` output letter by letter: a typo (`@snaqpshots`) only shows
up later as "No such file or directory" when mounting. To rename one: `mv` it
while the top level is mounted.

| Subvolume | Mounted at | Why separate |
| --- | --- | --- |
| `@` | `/` | the system; what you snapshot and roll back |
| `@home` | `/home` | a rollback of `/` never touches your files |
| `@log` | `/var/log` | logs survive rollbacks, so you can see what broke |
| `@pkg` | `/var/cache/pacman/pkg` | the package cache stays out of snapshots |
| `@snapshots` | `/.snapshots` | snapshots live outside `@`, so rolling `@` back keeps them |

```
O=noatime,compress=zstd:1
mount -o $O,subvol=@ /dev/mapper/cryptroot /mnt
mount --mkdir -o $O,subvol=@home      /dev/mapper/cryptroot /mnt/home
mount --mkdir -o $O,subvol=@log       /dev/mapper/cryptroot /mnt/var/log
mount --mkdir -o $O,subvol=@pkg       /dev/mapper/cryptroot /mnt/var/cache/pacman/pkg
mount --mkdir -o $O,subvol=@snapshots /dev/mapper/cryptroot /mnt/.snapshots
mount --mkdir -o fmask=0077,dmask=0077 $ESP /mnt/boot
findmnt -R /mnt
```

- `noatime`: no metadata write on every read. `compress=zstd:1`: fast
  transparent compression.
- `fmask/dmask=0077`: only root can read the ESP (bootctl/Limine warn
  otherwise).
- SSD TRIM (`discard=async`) and `space_cache=v2` are kernel defaults now; no
  options needed.

---

## 6. Encrypted swap

Swap gets its own LUKS2 container, unlocked at boot by a random keyfile that
lives on the encrypted root. You type one passphrase; systemd opens swap with
the keyfile after root is unlocked.

```
mkdir -p /mnt/etc/cryptsetup-keys.d
chmod 700 /mnt/etc/cryptsetup-keys.d
dd if=/dev/urandom of=/mnt/etc/cryptsetup-keys.d/cryptswap.key bs=512 count=8 iflag=fullblock
chmod 600 /mnt/etc/cryptsetup-keys.d/cryptswap.key

cryptsetup luksFormat --type luks2 --cipher aes-xts-plain64 --key-size 512 \
  --pbkdf pbkdf2 --sector-size 4096 --label cryptswap \
  --key-file /mnt/etc/cryptsetup-keys.d/cryptswap.key $SWAP
cryptsetup open --key-file /mnt/etc/cryptsetup-keys.d/cryptswap.key \
  --allow-discards --perf-no_read_workqueue --perf-no_write_workqueue \
  --persistent $SWAP cryptswap

mkswap -L swap /dev/mapper/cryptswap
swapon /dev/mapper/cryptswap
swapon --show
```

- `/etc/cryptsetup-keys.d`: where systemd looks for keyfiles; root-only.
- `dd … count=8`: 4 KiB of random key. Unreadable while the machine is off,
  since it sits on encrypted root.
- `--pbkdf pbkdf2`: a random 4 KiB key can't be brute-forced; Argon2 here
  would only cost boot time.
- `mkswap` goes on `/dev/mapper/cryptswap`, never on the raw partition.
- `swapon` now, so `genfstab` writes the swap line by itself.

`swapon --show` lists `/dev/dm-1` (the kernel's name for the mapper device),
slightly under the partition size because the LUKS header takes 16 MiB.

No hibernation with this setup. zram (section 14) is used first; this
partition is overflow.

---

## 7. Encrypted data disk

```
wipefs -af $DATA
blkdiscard -f $DATA
cfdisk $DATA                          # gpt, one partition, all space, Linux filesystem
DATAPART=${DATA}p1

dd if=/dev/urandom of=/mnt/etc/cryptsetup-keys.d/cryptdata.key bs=512 count=8 iflag=fullblock
chmod 600 /mnt/etc/cryptsetup-keys.d/cryptdata.key

cryptsetup luksFormat --type luks2 --cipher aes-xts-plain64 --key-size 512 \
  --pbkdf pbkdf2 --sector-size 4096 --label cryptdata \
  --key-file /mnt/etc/cryptsetup-keys.d/cryptdata.key $DATAPART
cryptsetup open --key-file /mnt/etc/cryptsetup-keys.d/cryptdata.key \
  --allow-discards --perf-no_read_workqueue --perf-no_write_workqueue \
  --persistent $DATAPART cryptdata

mkfs.btrfs -L data /dev/mapper/cryptdata
mount --mkdir -o noatime,compress=zstd:1 /dev/mapper/cryptdata /mnt/data
```

Same pattern as swap, with Btrfs instead of `mkswap`. **Copy
`cryptdata.key` off the machine**: without it the data disk can't be opened.

Check everything before continuing:

```
lsblk -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINTS
```

---

## 8. Bootstrap the system

```
pacstrap -K /mnt base linux-firmware amd-ucode btrfs-progs cryptsetup \
  networkmanager sudo zsh git stow neovim man-db man-pages

genfstab -U /mnt >> /mnt/etc/fstab
sed -i 's/subvolid=[0-9]*,//' /mnt/etc/fstab
nvim /mnt/etc/fstab
arch-chroot /mnt
```

- No kernel here on purpose: `linux-cachyos` is installed in section 10, after
  the switch to the CachyOS repos. `-K` creates a fresh keyring in the target.
- `amd-ucode`: CPU microcode (an Intel CPU would need `intel-ucode`).
- `genfstab -U`: fstab from the current mounts, by UUID.
- `sed … subvolid`: mount subvolumes by name, so a snapshot rollback that
  replaces `@` keeps working.
- In `nvim`, check you have `/`, `/home`, `/var/log`, `/var/cache/pacman/pkg`,
  `/.snapshots`, `/boot`, `/data` and a swap line. Append `,nofail` to the
  options of the `/data` line, so a dead data disk never blocks boot.

---

## 9. Base configuration (chroot)

You're in a new shell: variables from before are gone.

```
ln -sf /usr/share/zoneinfo/Europe/Madrid /etc/localtime
hwclock --systohc

sed -i -e 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' \
       -e 's/^#es_ES.UTF-8 UTF-8/es_ES.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
tee /etc/locale.conf >/dev/null <<'EOF'
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
EOF
echo 'KEYMAP=us' > /etc/vconsole.conf
echo '<hostname>' > /etc/hostname

passwd
useradd -m -u 1000 -g users -G wheel,video,render -s /usr/bin/zsh emrtnn
passwd emrtnn
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers
visudo -c

systemctl enable NetworkManager systemd-resolved systemd-timesyncd fstrim.timer
```

- English UI (`LANG`) with Spanish formats (`LC_*`). Both locales must be
  generated, or every program warns "Setting locale failed".
- `KEYMAP=us`: console and LUKS prompt. The console has no AltGr-intl
  equivalent, and on ASCII keys both layouts are identical, so the passphrase
  types the same. Don't use `us-acentos`: its dead keys turn `'` and `"` into
  accents. AltGr accents (AltGr+n = ñ) come from Mango's keyboard config
  (layout `us`, variant `altgr-intl`).
- `passwd` (root): without it, emergency mode says "root account is locked"
  and gives you no shell.
- `useradd -u 1000 -g users`: UID 1000 and primary group `users`, so files on
  the kept data disk remain yours (ownership follows the number). Other groups
  are added once their packages exist (section 14).
- `visudo -c`: syntax check after enabling `%wheel`.
- `systemd-resolved` for the DNS setup in section 14, `fstrim.timer` for
  weekly TRIM. Don't touch `/etc/resolv.conf` inside the chroot.

Unlock swap and the data disk at boot. The LUKS UUIDs are looked up by
label; `blkid` prints the outer (LUKS) UUID, which is what crypttab needs:

```
DATAPART=/dev/sdX1        # monad: the HDD partition (check lsblk); skip, the label is used
echo "cryptswap UUID=$(blkid -t LABEL=cryptswap -s UUID -o value) /etc/cryptsetup-keys.d/cryptswap.key luks" >> /etc/crypttab
# 
echo "cryptdata UUID=$(blkid -t LABEL=cryptdata -s UUID -o value) /etc/cryptsetup-keys.d/cryptdata.key luks,nofail" >> /etc/crypttab
# monad (existing HDD, may have no label):
echo "cryptdata UUID=$(blkid -s UUID -o value $DATAPART) /etc/cryptsetup-keys.d/cryptdata.key luks,nofail" >> /etc/crypttab

grep -v '^#' /etc/crypttab
grep -E 'swap|/data' /etc/fstab
```

- Every `UUID=` in crypttab must have a value. An empty one means the label or
  device was wrong.
- crypttab and fstab show **different** UUIDs for the same disk, and that's
  correct: crypttab has the outer LUKS container, fstab the filesystem/swap
  inside it.
- `/etc/crypttab` (not `crypttab.initramfs`) is read after root is unlocked,
  which is when the keyfiles become reachable. `nofail`: boot continues
  without the data disk.

---

## 10. CachyOS, kernel, initramfs, Limine (chroot)

### 10.1 CachyOS repositories

```
sed -i '/^#\[multilib\]/,/^#Include/ s/^#//' /etc/pacman.conf     # monad only (32-bit gaming libs)

cd /root
curl -LO https://mirror.cachyos.org/cachyos-repo.tar.xz
tar xf cachyos-repo.tar.xz && cd cachyos-repo
./cachyos-repo.sh
pacman -Syu
cd /root && rm -rf cachyos-repo cachyos-repo.tar.xz

pacman -Q pacman
grep -n '^\[' /etc/pacman.conf
```

- The script imports CachyOS's key, installs their keyring, mirrorlists and
  patched `pacman`, backs up `pacman.conf`, detects the CPU's x86-64 level
  (v3/v4) and adds the optimized repos.
- `pacman -Syu`: moves installed packages to CachyOS builds.
- **Check:** `pacman -Q pacman` must be CachyOS's build, and every
  `[cachyos…]` section must come **before** `[core]`. If Arch's pacman ever
  replaces CachyOS's, you get `unknown key '%INSTALLED_DB%'` warnings and
  AUR binaries linked against libalpm break.

### 10.2 Kernel and boot packages

```
pacman -S linux-cachyos linux-cachyos-headers plymouth limine limine-mkinitcpio-hook efibootmgr
# monad, in addition:
pacman -S linux-cachyos-nvidia-open nvidia-utils lib32-nvidia-utils
```

- `linux-cachyos-nvidia-open`: the open NVIDIA module prebuilt for exactly
  this kernel. No DKMS, no compile on kernel updates. `nvidia-utils` also
  blacklists nouveau.
- *If amd instead of nvidia gpu` nothing extra. `amdgpu` is part of the kernel.
- `limine-mkinitcpio-hook`: CachyOS's tool that writes `/boot/limine.conf`
  entries whenever a kernel or initramfs changes; provides `limine-install`,
  `limine-mkinitcpio`, `limine-update`.
- mkinitcpio runs during these installs with the default config and may warn.
  Ignore it: 10.4 rebuilds everything.

### 10.3 Initramfs configuration

```
mkdir -p /etc/mkinitcpio.conf.d
tee /etc/mkinitcpio.conf.d/10-initrd.conf >/dev/null <<'EOF'
HOOKS=(systemd autodetect microcode modconf kms keyboard sd-vconsole block plymouth sd-encrypt filesystems)
EOF
```

**Nvidia**

```
echo 'MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)' > /etc/mkinitcpio.conf.d/20-gpu.conf
tee /etc/modprobe.d/nvidia.conf >/dev/null <<'EOF'
options nvidia NVreg_PreserveVideoMemoryAllocations=1 NVreg_UseKernelSuspendNotifiers=1
options nvidia-drm modeset=1 fbdev=1
softdep nvidia post: nvidia-uvm
EOF
```

**AMD**

```
echo 'MODULES=(amdgpu)' > /etc/mkinitcpio.conf.d/20-gpu.conf
```

Check: `cat /etc/mkinitcpio.conf.d/*.conf`. Only files ending in `.conf`
are read. An empty directory means the default hooks, which have no
`sd-encrypt`: the boot then waits forever for `/dev/mapper/cryptroot`.

- Files in `mkinitcpio.conf.d/` override `mkinitcpio.conf` without editing it.
- `systemd`: systemd-based early boot (required by `sd-encrypt`).
  `autodetect`: only this machine's modules. `microcode`: embeds the AMD
  microcode. `modconf`: includes `/etc/modprobe.d`. `kms`: GPU drivers for
  early modesetting. `keyboard`/`sd-vconsole`: keyboard and `KEYMAP` for the
  passphrase. `block`: storage drivers. `plymouth` before `sd-encrypt`: the
  passphrase prompt is graphical. `sd-encrypt`: unlocks root.
  `filesystems`: Btrfs.
- No `fsck` hook: Btrfs doesn't need it, and `fsck.btrfs` only triggers a
  "missing /bin/sh" warning.
- `MODULES`: the GPU driver loads inside the initramfs (early KMS), so
  Plymouth has a display to draw on.
- `nvidia.conf`: keep VRAM across suspend, kernel modesetting with a
  framebuffer, load `nvidia-uvm` after `nvidia`.

### 10.4 Limine

```
LUKS_UUID=$(blkid -t LABEL=cryptroot -s UUID -o value)
echo "$LUKS_UUID"

tee /etc/default/limine >/dev/null <<EOF
ESP_PATH="/boot"
KERNEL_CMDLINE[default]="rd.luks.name=${LUKS_UUID}=cryptroot root=/dev/mapper/cryptroot rootflags=subvol=@ rw"
EOF
cat /etc/default/limine

limine-install
limine-mkinitcpio
grep cmdline /boot/limine.conf
lsinitcpio "$(ls /boot/*/linux-cachyos/initramfs* | head -1)" | grep -c cryptsetup
efibootmgr
```

- `echo "$LUKS_UUID"` must print a UUID. An empty variable produces
  `rd.luks.name==cryptroot`, and nothing ever asks for the passphrase.
- The heredoc is **unquoted** (`<<EOF`) so `${LUKS_UUID}` is filled in. Check
  the spelling in `cat`: it's `rd.luks.name`. A typo (`rd.lunks.name`) is
  silently ignored and the boot times out.
- `rd.luks.name=<UUID>=cryptroot`: unlock that container as `cryptroot`.
  `root=… rootflags=subvol=@ rw`: root is subvolume `@`, read-write.
- `quiet splash` are added after the first successful boot (section 11), so
  you see any error now.
- `limine-install`: copies Limine to the ESP and creates its UEFI boot entry.
  If it prints "The system is not using UEFI", the USB booted in BIOS mode:
  see [18](#18-troubleshooting).
- `limine-mkinitcpio`: builds the initramfs and writes `/boot/limine.conf`.
- `grep cmdline`: your command line with the real UUID.
- `lsinitcpio … | grep -c`: any number above 0 means `sd-encrypt` is inside.
- `efibootmgr`: the Limine entry should be first in `BootOrder` (the listing
  wraps lines; read the numbers).

Limine can't read LUKS, so kernel and initramfs sit unencrypted on the ESP.
Secure Boot (section 17) makes Limine verify them by hash.

```
exit
umount -R /mnt
reboot
```

Remove the USB.

---

## 11. First boot

You get the Limine menu, then a text prompt: "Please enter passphrase for
disk cryptroot" ("…or recovery key" once you add one).

**The screen goes black and the monitor loses signal** right after Limine:
that's the GPU driver changing display mode, and some monitors don't resync.
Power-cycle the monitor. If it's still blank, type the passphrase anyway.

Log in **directly as your user** at the tty (not `su` from root: `su` doesn't
create a login session, so `systemctl --user` and `XDG_RUNTIME_DIR` won't
work, and anything you create may end up owned by root).

```
swapon --show
lsblk -o NAME,FSTYPE,LABEL,MOUNTPOINTS
findmnt /data
```

`cryptswap` in use, `cryptroot` mounted on `/`, `cryptdata` on `/data`.

**Protect the LUKS header and add a recovery key**

```
sudo cryptsetup luksHeaderBackup "$(blkid -t LABEL=cryptroot -o device)" --header-backup-file luks-header.img
sudo systemd-cryptenroll --recovery-key "$(blkid -t LABEL=cryptroot -o device)"
```

- A corrupted header loses the whole disk; the backup restores it (it's only
  usable with a passphrase). Store it off the machine.
- The recovery key is a long generated key in its own slot. Write it down.

**Remove stale firmware boot entries** (old systemd-boot, Windows, an older
Limine):

```
efibootmgr
sudo efibootmgr -b XXXX -B
```

`-b` selects the entry by number, `-B` deletes it. Keep the new Limine entry
and the firmware's "UEFI OS" fallback. Entries for the USB disappear when
it's unplugged; legacy (BBS) entries disappear with CSM off.

**Boot splash**: Plymouth's default theme (`bgrt`: firmware logo with a
spinner) and a quiet boot:

```
sudo plymouth-set-default-theme bgrt
sudo sed -i 's/ rw"/ rw quiet splash"/' /etc/default/limine
grep KERNEL_CMDLINE /etc/default/limine
sudo limine-mkinitcpio
```

- Don't use `plymouth-set-default-theme -R`: it runs plain `mkinitcpio -P`
  instead of the Limine tool.
- `quiet splash`: Plymouth only draws with `splash`; without it you get
  systemd's text prompt.

---

## 12. Packages

As your user. `paru` comes from the CachyOS repo: the AUR's `paru-bin` is
linked against Arch's libalpm and breaks with CachyOS's pacman (`libalpm.so…:
cannot open shared object file`). Same risk for any AUR `-bin` that links
pacman. Run paru as your user; it calls sudo itself (makepkg refuses root).

**pacman: both machines**

```
sudo pacman -S --needed \
  base-devel bash vim wget gcc make cmake e2fsprogs parted plocate pacman-contrib paru \
  lazygit ripgrep fd bind duckdb btop github-cli unzip 7zip file jq tree \
  zsh-autosuggestions zsh-syntax-highlighting zsh-history-substring-search \
  eza fzf zoxide yazi poppler resvg chafa imagemagick ffmpeg \
  bat tuicr jujutsu openssh tmux \
  tree-sitter-cli curl tar gzip \
  clang cppcheck rustup zig php nodejs npm pnpm python uv \
  emacs-wayland libvterm libtool ttf-nerd-fonts-symbols ttf-nerd-fonts-symbols-mono \
  ninja valgrind gdb gef pkgconf \
  mangowm xorg-xwayland noctalia foot foot-terminfo satty \
  grim slurp hyprpicker brightnessctl wl-clipboard wtype cliphist gpu-screen-recorder \
  qt5-wayland qt6-wayland xdg-desktop-portal xdg-desktop-portal-wlr xdg-desktop-portal-gtk \
  sddm kwin qt6-svg qt6-virtualkeyboard qt6-multimedia-ffmpeg accountsservice \
  pipewire pipewire-alsa pipewire-pulse pipewire-jack wireplumber \
  dconf gvfs mesa vulkan-icd-loader xdg-utils polkit gsettings-desktop-schemas \
  adw-gtk-theme nwg-look papirus-icon-theme qt6ct breeze \
  noto-fonts noto-fonts-cjk noto-fonts-emoji ttf-jetbrains-mono-nerd ttf-cascadia-code-nerd \
  otf-geist-mono-nerd ttf-iosevka-nerd ttf-material-symbols-variable \
  evince playerctl torbrowser-launcher telegram-desktop librewolf signal-desktop sequoia-sq mpv \
  dolphin ark kio-fuse ffmpegthumbs kdegraphics-thumbnailers kconfig archlinux-xdg-menu \
  gwenview kimageformats keepassxc syncthing gnome-keyring gcr-4 libsecret \
  tor torsocks proxychains-ng openvpn wireshark-qt docker nftables iptables \
  tailscale zram-generator snapper snap-pac cachyos-settings sbctl \
  qemu-desktop libvirt virt-manager virt-viewer dnsmasq swtpm virtiofsd edk2-ovmf spice-gtk \
  guestfs-tools libguestfs \
  nmap openbsd-netcat inetutils arp-scan bc tcpdump hydra samba cifs-utils wpscan exploitdb \
  metasploit python-jsbeautifier sqlmap hashcat john openssl impacket perl-image-exiftool \
  sslscan ghidra openldap binwalk
```

**pacman: NVIDIA gaming machine**

```
sudo pacman -S --needed \
  nvidia-settings libva-nvidia-driver nvtop \
  steam gamescope gamemode lib32-gamemode protontricks umu-launcher \
  vulkan-tools mesa-utils libnotify lib32-pipewire lib32-vulkan-icd-loader
```

**pacman: AMD Workstation (AMD GPU, ROCm, printing, Bluetooth)**

```
sudo pacman -S --needed \
  vulkan-radeon radeontop nvtop \
  rocm-core hip-runtime-amd rocm-opencl-runtime \
  cups gutenprint avahi nss-mdns bluez bluez-utils blender
```

On AMD, `mesa` provides OpenGL and hardware video decoding (VA-API/VDPAU are
built in), `vulkan-radeon` is the Vulkan driver.

> You can mix both as needed

**AUR: both machines**

```
paru -S --needed \
  carapace-bin bibata-cursor-theme-bin ttf-twemoji-color ttf-all-the-icons \
  helium-browser-bin pi-coding-agent-bin mpv-modernz vesktop-bin onlyoffice-bin localsend-bin \
  sddm-silent-theme virtio-win quickemu nixd foundry-bin \
  burpsuite ffuf smbmap whatweb seclists rockyou wfuzz pspy cewl-git ruby-evil-winrm hashid
```

**AUR**

```
paru -S --needed proton-ge-custom-bin heroic-games-launcher-bin lib32-extest iptvnator-bin
```

**Rust toolchain**

```
rustup default stable
rustup component add rust-analyzer clippy rustfmt
```

If pacman stops at "target not found", check the spelling first
(`qt6-multimedia-ffmpeg`, not `…ffmepg`), then drop the name if it really left
the repos.

<details>
<summary>What each group is for</summary>

| Packages | For |
| --- | --- |
| base-devel, stow, git | building AUR packages, these dotfiles |
| plocate, pacman-contrib | `locate`, `paccache.timer` |
| bind, github-cli, 7zip, tree | `dig`/`nslookup`, `gh`, `7z`, fzf's Alt+C preview |
| eza, fzf, zoxide, carapace-bin | `ls` aliases, fuzzy finder, `cd`, completions |
| zsh-autosuggestions, -syntax-highlighting, -history-substring-search | zsh plugins (from `/usr/share/zsh/plugins`) |
| yazi + poppler, resvg, chafa, imagemagick, ffmpeg | file manager and its previews |
| bat, tuicr, jujutsu, tmux | pager, code review TUI (`gd` alias), jj, multiplexer |
| neovim, tree-sitter-cli, curl, tar, gzip, unzip | Neovim; lazy.nvim/mason downloads; parser builds |
| clang, cppcheck | clangd, clang-format, clang-tidy; C/C++ lint |
| rustup, zig, php, nodejs, npm, pnpm, python, uv | toolchains; runtimes for mason's tools |
| nixd, foundry-bin | Nix LSP (not in mason); `forge fmt` (extra's `foundry` is unrelated) |
| emacs-wayland, libvterm, libtool, cmake, nerd symbols, all-the-icons | Doom Emacs, vterm, icons |
| pi-coding-agent-bin | pi coding agent |
| mangowm, xorg-xwayland, noctalia, foot | compositor, shell (bar, launcher, lock…), terminal |
| satty, grim, slurp, hyprpicker, brightnessctl, wl-clipboard, wtype, cliphist, gpu-screen-recorder | screenshots, picker, brightness, clipboard, key injection, recorder |
| qt5/qt6-wayland, xdg-desktop-portal(-wlr, -gtk) | Qt on Wayland; portals (screencast via wlr) |
| sddm, kwin, sddm-silent-theme, qt6-svg, qt6-virtualkeyboard, qt6-multimedia-ffmpeg, accountsservice | login screen; the theme crashes without the Qt modules |
| pipewire (+ alsa, pulse, jack), wireplumber | audio |
| dconf, gvfs, mesa, vulkan-icd-loader, xdg-utils, polkit, gsettings-desktop-schemas | desktop plumbing |
| adw-gtk-theme, nwg-look, papirus-icon-theme, bibata-cursor-theme-bin, qt6ct, breeze | GTK/Qt theming, icons, cursor |
| noto-fonts(-cjk, -emoji), nerd fonts, material symbols, twemoji | fonts (Iosevka: foot/Doom; GeistMono: Noctalia) |
| librewolf, helium-browser-bin, torbrowser-launcher | browsers |
| telegram-desktop, signal-desktop, vesktop-bin | chat |
| evince, onlyoffice-bin, mpv, mpv-modernz, playerctl | PDF, office, video + OSC, media keys |
| dolphin, ark, kio-fuse, ffmpegthumbs, kdegraphics-thumbnailers, kconfig, archlinux-xdg-menu, gwenview, kimageformats | file manager, archives, thumbnails, `kwriteconfig6`, "Open With", images |
| keepassxc, syncthing, gnome-keyring, gcr-4, libsecret, sequoia-sq | passwords, sync, keyring/SSH agent/`secret-tool`, OpenPGP |
| localsend-bin | LAN file sharing |
| tor, torsocks, proxychains-ng, openvpn, wireshark-qt, docker, nftables, iptables, tailscale | network and security |
| zram-generator, snapper, snap-pac, cachyos-settings, sbctl | compressed swap, snapshots, CachyOS tweaks, Secure Boot |
| qemu-desktop, libvirt, virt-manager, virt-viewer, dnsmasq, swtpm, virtiofsd, edk2-ovmf, spice-gtk, guestfs-tools, virtio-win, quickemu | VMs |
| nmap … binwalk, burpsuite … hashid, seclists, rockyou, wfuzz | pentesting tools and wordlists (`/usr/share/seclists`, `/usr/share/dict/rockyou.txt`) |

</details>

Optional: `nix` (pacman) for Nix devshells; nvim and Doom already handle
`.nix` files.

---

## 13. Stow the dotfiles

As your user, logged in directly. Clone over HTTPS (your SSH keys come back in
section 15):

```
git clone https://github.com/emrtnn/dotfiles ~/dotfiles
mkdir -p ~/.config/systemd/user ~/.local/bin ~/.local/share ~/Pictures
cd ~/dotfiles
stow nvim doom mango
stow --no-folding zsh git jj tmux yazi bat tuicr face wallpapers \
  gtk cursor qt dolphin mimeapps emacs mpv xdg-desktop-portal foot noctalia satty
```

- `mkdir -p …` first: these must be real directories, or stow "folds" all of
  `~/.config` into a symlink to the first package.
- **Folded** (`nvim`, `doom`, `mango`): the whole directory becomes one symlink
  to the repo, so new files and `lazy-lock.json` updates land in git.
- **`--no-folding`** (the rest): real directories with one symlink per file,
  because programs write state next to them that must not reach the repo (zsh
  history, Noctalia's generated `gtk.css`, the `.wants/` links systemctl
  creates). After adding a new file to one of these packages:
  `stow -R --no-folding <pkg>`.
- Stow never overwrites. On a conflict, move the existing file away and rerun.
  Remove a package with `stow -D <pkg>`.
- `librewolf/` is **not** stowed (section 15).

If a `mkdir` in your home says "Permission denied", something was created as
root: `sudo chown -R emrtnn:users /home/emrtnn`.

---

## 14. System configuration

Everything outside `$HOME`. Each block creates its file in full.

### 14.1 Groups

```
sudo usermod -aG wireshark,docker,libvirt,kvm emrtnn     # Gaming: add ,gamemode
```

`-a` appends; without it, existing groups would be replaced. Applies at your
next login (check with `id`).

### 14.2 CachyOS settings

`cachyos-settings` ships its tweaks in `/usr/lib/…` (zram, I/O schedulers,
sysctl, journald limits, THP, ntsync, NVIDIA power options, NetworkManager →
resolved). Files you write in `/etc/…` take precedence, and pacman never
replaces them, so nothing below gets overwritten.

Two things to adjust. In `/etc/pacman.conf`, under `[options]`:

```
NoExtract = usr/bin/sbctl-batch-sign etc/debuginfod/cachyos.urls
```

```
sudo rm -f /usr/bin/sbctl-batch-sign /etc/debuginfod/cachyos.urls
```

- `sbctl-batch-sign` signs kernels, which breaks Limine's hash check under
  Secure Boot. Never run it; `NoExtract` keeps updates from restoring it.
- `cachyos.urls` makes gdb fetch debug symbols from CachyOS's server for
  whatever you debug.
- `pacman -Qkk cachyos-settings` will report those two as missing: expected.
- Their timesyncd uses Cloudflare/Google NTP. To change it, create
  `/etc/systemd/timesyncd.conf.d/10-timesyncd.conf` with `[Time]` and
  `NTP=pool.ntp.org`; a same-named file in `/etc` replaces theirs.

### 14.3 Login: SDDM + Silent theme

```
sudo mkdir -p /etc/sddm.conf.d
sudo tee /etc/sddm.conf.d/10-silent.conf >/dev/null <<'EOF'
[General]
DisplayServer=wayland
GreeterEnvironment=QML2_IMPORT_PATH=/usr/share/sddm/themes/silent/components/,QT_IM_MODULE=qtvirtualkeyboard
InputMethod=qtvirtualkeyboard
Numlock=none

[Theme]
Current=silent

[Wayland]
CompositorCommand=kwin_wayland --no-global-shortcuts --no-kactivities --no-lockscreen
EnableHiDPI=true
EOF

sudo install -Dm644 ~/dotfiles/face/.face.png /var/lib/AccountsService/icons/$USER
printf '[User]\nIcon=/var/lib/AccountsService/icons/%s\n' "$USER" | sudo install -Dm600 /dev/stdin /var/lib/AccountsService/users/$USER

ls /usr/share/wayland-sessions
sudo systemctl enable sddm
```

- `DisplayServer=wayland`: the greeter runs on KWin under Wayland.
  `GreeterEnvironment`/`InputMethod`: the theme's QML components and its
  on-screen keyboard.
- `CompositorCommand`: KWin with its desktop features off. **No
  `--locale1`**: KWin 6.8 rejects it ("Unknown option 'locale1'") and exits,
  so the greeter dies within a second and tty1 stays black.
- The two `install` lines: your picture through AccountsService, which SDDM
  reads.
- `ls`: the `mangowm` package's session file; SDDM lists it.
- `enable` without `--now`: it would take over the screen immediately.
- SDDM starts Mango from a non-interactive login zsh, so Mango inherits
  `~/.zshenv` (see [19.2](#192-environment-variables)). Your login password
  unlocks GNOME Keyring through Arch's `/etc/pam.d/sddm`.

### 14.4 DNS: Quad9 over TLS

```
sudo mkdir -p /etc/systemd/resolved.conf.d
sudo tee /etc/systemd/resolved.conf.d/quad9.conf >/dev/null <<'EOF'
[Resolve]
DNS=9.9.9.9#dns.quad9.net 149.112.112.112#dns.quad9.net
FallbackDNS=9.9.9.9#dns.quad9.net 149.112.112.112#dns.quad9.net
Domains=~.
DNSSEC=true
DNSOverTLS=true
EOF

sudo tee /etc/NetworkManager/conf.d/50-dns-wifi.conf >/dev/null <<'EOF'
[main]
dns=systemd-resolved

[connection]
# Wi-Fi power saving off
wifi.powersave=2
EOF

sudo ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
sudo systemctl restart systemd-resolved NetworkManager

nmcli -t -f NAME,DEVICE connection show --active
sudo nmcli connection modify "<NAME>" ipv4.ignore-auto-dns yes ipv6.ignore-auto-dns yes
sudo nmcli connection up "<NAME>"
resolvectl status
```

- Each key on **one line**, both servers separated by a space; key names are
  case-sensitive (`FallbackDNS`, not `FallbackDns`). A stray line is silently
  ignored.
- `DNS=IP#name`: `#dns.quad9.net` is the name Quad9's TLS certificate must
  match. `Domains=~.`: route every lookup here. `DNSSEC`/`DNSOverTLS`:
  validate and encrypt, no plaintext fallback.
- `ignore-auto-dns`: without it, the connection also hands your ISP's DHCP DNS
  servers to resolved, which keeps querying them. Repeat for each new
  connection (each Wi-Fi network).
- `resolvectl status`: Global shows both Quad9 servers and `+DNSOverTLS`;
  your link shows no DNS servers of its own.

### 14.5 Firewall (nftables)

```
sudo tee /etc/nftables.conf >/dev/null <<'EOF'
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
EOF

sudo nft -c -f /etc/nftables.conf
sudo systemctl enable --now nftables
```

- `destroy table` replaces only this table, never `flush ruleset`, so
  Docker's, libvirt's and Tailscale's rules survive reloads.
- `rpfilter`: drops spoofed sources (loose reverse-path check), lets DHCP in.
- `input`: drop by default; trusted interfaces pass; replies pass; new
  connections go to `input-allow`.
- Open: 22 SSH, 80/443, 4444 (listener), 22000 + 21027 Syncthing, 53317
  LocalSend, 41641 Tailscale, VM DNS/DHCP, ping, required ICMPv6, DHCPv6.
- **printer:** printer discovery needs mDNS: add `5353` to the `udp dport` set.
- `nft -c`: syntax check without applying.

### 14.6 SSH server

The file goes in **`sshd_config.d`** (server). In `ssh_config.d` (client),
these options break every outgoing `ssh` and `git` with "Bad configuration
option".

```
sudo tee /etc/ssh/sshd_config.d/50-hardening.conf >/dev/null <<'EOF'
PermitRootLogin no
PasswordAuthentication no
KbdInteractiveAuthentication no
EOF
sudo sshd -t
sudo systemctl enable --now sshd
```

Keys only, no root login. `KbdInteractiveAuthentication no` stops PAM from
still prompting for a password. `sshd -t` prints nothing when the config is
valid.

### 14.7 Tailscale, timers, Docker

```
sudo systemctl enable --now tailscaled plocate-updatedb.timer paccache.timer docker.service
sudo tailscale up
```

`tailscale up` prints a login URL. `plocate-updatedb.timer`: daily `locate`
database. `paccache.timer`: weekly cache trim. Wireshark needs only its group;
OpenVPN connections are started by hand.

### 14.8 Tor (local client) and ProxyChains

```
sudo tee /etc/tor/torrc >/dev/null <<'EOF'
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
EOF

sudo tee /etc/proxychains.conf >/dev/null <<'EOF'
strict_chain

proxy_dns

remote_dns_subnet 224
tcp_read_time_out 15000
tcp_connect_time_out 8000
localnet 127.0.0.0/255.0.0.0
[ProxyList]
socks5 127.0.0.1 9050
EOF

sudo systemctl enable --now tor
journalctl -u tor -b | grep Bootstrapped
```

- Tor: SOCKS on localhost only, separate circuits per destination and per
  credentials, never a relay/bridge/exit, raw IPs allowed (Telegram).
- ProxyChains: single strict hop to Tor with proxied DNS; fails closed if Tor
  is down.
- Wait for `Bootstrapped 100%`. Test:
  `torsocks curl https://check.torproject.org/api/ip`, or
  `proxychains4 -f /etc/proxychains.conf curl …`, or
  `curl --proxy socks5h://127.0.0.1:9050 …` (the `h` makes Tor resolve DNS).
- Browsing: run `torbrowser-launcher` directly. These wrappers aren't a VPN or
  kill switch; Tor carries TCP only. Use the lab VPN for lab targets.

### 14.9 zram

```
sudo tee /etc/systemd/zram-generator.conf >/dev/null <<'EOF'
[zram0]
zram-size = ram
compression-algorithm = zstd
EOF
sudo systemctl daemon-reload
sudo systemctl start systemd-zram-setup@zram0
swapon --show
```

A compressed swap device in RAM, used before the disk partition: `swapon`
shows `/dev/zram0` with priority 100 and `cryptswap` lower.

### 14.10 VMs (libvirt/QEMU) and Docker forwarding

```
sudo systemctl enable --now libvirtd.socket libvirt-guests.service

sudo tee /etc/conf.d/libvirt-guests >/dev/null <<'EOF'
ON_BOOT=ignore
ON_SHUTDOWN=shutdown
EOF

sudo tee /etc/modprobe.d/kvm-nested.conf >/dev/null <<'EOF'
options kvm_amd nested=1
options kvm_intel nested=1
EOF

sudo virsh -c qemu:///system net-autostart default
sudo virsh -c qemu:///system net-start default

sudo tee /etc/systemd/system/libvirt-docker-forward.service >/dev/null <<'EOF'
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
EOF
sudo systemctl daemon-reload
sudo systemctl enable --now libvirt-docker-forward
```

- Guests start only if marked autostart and shut down cleanly with the host.
- Nested virtualization (applies after reboot).
- `default` NAT network (`virbr0`, served by dnsmasq), trusted by the firewall.
- Docker sets FORWARD to DROP, which silently cuts VMs off the internet; the
  unit re-allows `virbr0` traffic after Docker starts.
- Windows guests: `edk2-ovmf` (UEFI/Secure Boot), `swtpm` (TPM 2.0), virtio
  ISO at `/var/lib/libvirt/images/virtio-win.iso`.

### 14.11 NVIDIA and gaming

```
sudo systemctl enable nvidia-suspend nvidia-hibernate nvidia-resume

sudo tee -a /etc/environment >/dev/null <<'EOF'
LIBVA_DRIVER_NAME=nvidia
NVD_BACKEND=direct
# NVIDIA's default shader cache is ~1 GB and gets evicted: recompiles and
# stutter. DXVK/VKD3D pipelines live here too.
__GL_SHADER_DISK_CACHE_SIZE=12000000000
__GL_SHADER_DISK_CACHE_SKIP_CLEANUP=1
EOF

sudo tee /etc/gamemode.ini >/dev/null <<'EOF'
[general]
renice=10
softrealtime=auto
inhibit_screensaver=1

[custom]
start=notify-send 'GameMode started'
end=notify-send 'GameMode ended'
EOF

sudo tee /etc/udev/rules.d/99-ntsync.rules >/dev/null <<'EOF'
KERNEL=="ntsync", MODE="0660", TAG+="uaccess"
EOF

sudo tee /etc/sysctl.d/99-gaming.conf >/dev/null <<'EOF'
kernel.split_lock_mitigate = 0
EOF
sudo sysctl --system
```

- NVIDIA services: save/restore VRAM around sleep (with the modprobe options
  from 10.3); without them, resume can show a black screen.
- `tee -a` **appends**: `/etc/environment` already exists. VA-API through
  `libva-nvidia-driver`; a 12 GB shader cache that isn't pruned.
- GameMode: use `gamemoderun %command%` in Steam's launch options.
- ntsync: `cachyos-settings` already loads the module; the udev rule gives
  your session access to `/dev/ntsync`.
- Split-lock penalty off for Windows games.
- Steam Input on Wayland: start Steam with
  `LD_PRELOAD=/usr/lib32/libextest.so steam`. A gamescope session:
  `gamescope -- steam -gamepadui`.

### 14.12 ROCm, printing, Bluetooth, NIC

```
sudo tee -a /etc/environment >/dev/null <<'EOF'
HSA_OVERRIDE_GFX_VERSION=11.0.0
HIP_PATH=/opt/rocm
ROCM_PATH=/opt/rocm
EOF

sudo sed -i 's/^hosts: mymachines resolve/hosts: mymachines mdns_minimal [NOTFOUND=return] resolve/' /etc/nsswitch.conf
grep '^hosts' /etc/nsswitch.conf
sudo tee /etc/systemd/resolved.conf.d/no-mdns.conf >/dev/null <<'EOF'
[Resolve]
MulticastDNS=no
EOF
sudo systemctl restart systemd-resolved
sudo systemctl enable --now cups.socket avahi-daemon bluetooth
```

- ROCm: the GFX override makes ROCm accept the GPU; Arch's `blender` renders
  with HIP.
- `nsswitch`: resolve `.local` printer names through Avahi before resolved.
  If `grep` doesn't show `mdns_minimal`, your `hosts:` line differs: insert
  `mdns_minimal [NOTFOUND=return]` before `resolve` by hand.
- `MulticastDNS=no`: Avahi and resolved both want port 5353.
- Bluetooth powers on at boot by default (`AutoEnable=true` in bluez).

NIC after resume: if the Realtek NIC stops working after suspend, a sleep
hook reloads its driver. Check which driver it uses first
(`lspci -k | grep -A3 -i ethernet`; usually `r8169`, in-tree):

```
sudo tee /usr/lib/systemd/system-sleep/nic-reload >/dev/null <<'EOF'
#!/bin/sh
case "$1" in
  post)
    modprobe -r r8169
    modprobe r8169
    sleep 2
    systemctl restart NetworkManager.service
    ;;
esac
EOF
sudo chmod +x /usr/lib/systemd/system-sleep/nic-reload
```

Replace `r8169` with the driver `lspci -k` shows.

Reboot now. You should land on the Silent login screen; pick Mango.

---

## 15. User setup

As your user, logged in to the Mango session (or directly at a tty).

### 15.1 User services

```
systemctl --user daemon-reload
systemctl --user enable --now gcr-ssh-agent.socket syncthing.service
```

- `gcr-ssh-agent.socket`: the SSH agent backed by GNOME Keyring;
  `~/.config/zsh/.zshenv` points `SSH_AUTH_SOCK` at it. Don't enable OpenSSH's
  `ssh-agent`.
- The cliphist and emacs units start with the graphical session. Foot's
  server isn't a unit: Mango's `autostart.conf` runs `foot -s`.
- "Failed to connect to user scope bus": you're in a `su` shell, not a real
  login. Log in directly.

### 15.2 Restore keys

```
cp -r /path/to/backup/.ssh ~/ && chmod 700 ~/.ssh && chmod 600 ~/.ssh/id_ed25519
gpg --import /path/to/backup/secret-keys.asc
mkdir -p ~/.local/state/syncthing
cp /path/to/backup/{cert,key}.pem ~/.local/state/syncthing/
systemctl --user restart syncthing
```

git and jj sign with `~/.ssh/id_ed25519.pub`. Syncthing keeps its old device
ID with the restored `cert.pem`/`key.pem`; otherwise every other device must
re-add the new one. Switch the dotfiles remote to SSH if you like:
`git -C ~/dotfiles remote set-url origin git@github.com:emrtnn/dotfiles.git`.

### 15.3 Look and file manager

```
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
gsettings set org.gnome.desktop.interface gtk-theme 'adw-gtk3'
gsettings set org.gnome.desktop.interface icon-theme 'Papirus-Dark'
gsettings set org.gnome.desktop.interface cursor-theme 'Bibata-Modern-Ice'
gsettings set org.gnome.desktop.interface cursor-size 24

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

XDG_MENU_PREFIX=arch- kbuildsycoca6 --noincremental
bat cache --build
```

- `gsettings`: GTK settings in dconf (dark, adw-gtk3, Papirus, Bibata).
- `kwriteconfig6`: single keys in KDE's files. Not stowed because Dolphin
  rewrites them.
- `kbuildsycoca6`: Dolphin's "Open With" outside Plasma (rerun after
  installing apps).
- `bat cache --build`: registers the Caelus theme.

### 15.4 API keys

Stored in the login keyring (encrypted with your password, unlocked at login).
`secret-tool` reads the value from a prompt, so it never hits shell history:

```
secret-tool store --label='Brave Search API key' env BRAVE_API_KEY
secret-tool store --label='Exa API key' env EXA_API_KEY
secret-tool store --label='Anthropic API key' env ANTHROPIC_API_KEY    # if not using /login
```

pi reads them itself when needed. `~/.config/pi/web-search.json`:

```json
{
  "provider": "exa",
  "exaApiKey": "!secret-tool lookup env EXA_API_KEY",
  "braveApiKey": "!secret-tool lookup env BRAVE_API_KEY"
}
```

`~/.pi/agent/auth.json`, only for an Anthropic API key:

```json
{ "anthropic": { "type": "api_key", "key": "!secret-tool lookup env ANTHROPIC_API_KEY" } }
```

Not stowed (and in `.gitignore`): pi writes to them. For other tools, give the
key to one command only:
`FOO_API_KEY="$(secret-tool lookup env FOO_API_KEY)" some-tool`. Inspect with
`secret-tool lookup`, remove with `secret-tool clear`, or use Seahorse.

### 15.5 Apps

- **Neovim**: start `nvim` once. lazy.nvim installs the plugins, then mason
  installs language servers, formatters and linters in the background
  (`:Mason`). Updates: `:Lazy update`, `:MasonToolsUpdate`. Do this before
  Doom.
- **Doom Emacs**:

  ```
  git clone --depth 1 --recurse-submodules --shallow-submodules https://github.com/doomemacs/doomemacs ~/.config/emacs
  ~/.config/emacs/bin/doom sync
  systemctl --user enable --now emacs.service
  ```

  Doom uses mason's binaries (`.zshenv` puts `~/.local/share/nvim/mason/bin`
  on PATH; `config.el` adds it to `exec-path`).
- **tmux**: start it once; TPM installs resurrect + continuum. `prefix + U`
  updates them.
- **KeePassXC**: it rewrites its ini, so write it once (mode 600):

  ```
  mkdir -p ~/.config/keepassxc
  install -m 600 /dev/stdin ~/.config/keepassxc/keepassxc.ini <<'EOF'
  [Browser]
  Enabled=true

  [GUI]
  CheckForUpdates=false
  MinimizeOnClose=true
  MinimizeToTray=true
  ShowTrayIcon=true

  [Security]
  LockDatabaseIdleSeconds=14400
  EOF
  ```

  Browser Integration: tick **Firefox** (LibreWolf reads the same manifest).
  For Helium, under Advanced, a custom Chromium location:
  `~/.config/net.imput.helium/NativeMessagingHosts`.
- **LibreWolf theme**: start LibreWolf once and quit, then:

  ```
  profile=$(ls -d ~/.config/librewolf/librewolf/*.default-default)
  mkdir -p "$profile/chrome"
  cp ~/dotfiles/librewolf/userChrome.css ~/dotfiles/librewolf/userContent.css "$profile/chrome/"
  cp ~/dotfiles/librewolf/user.js "$profile/"
  ```

  `user.js` enables `toolkit.legacyUserProfileCustomizations.stylesheets`.
  Use `ln -s` instead of `cp` for the CSS to edit it from the repo. Restart
  LibreWolf after CSS changes.
- **Syncthing**: web GUI at <http://127.0.0.1:8384>. Devices (Auto Accept
  off): argos, iphone (IDs in your private notes). Folder ID and
  label `keepass`, path `~/Passwords`, Send & Receive, shared with all four,
  Staggered versioning, 90 days. Anonymous usage reporting off.

---

## 16. Snapshots

`snapper` + `snap-pac` (snapshots before/after every pacman transaction),
stored in the top-level `@snapshots` subvolume:

```
sudo umount /.snapshots
sudo rmdir /.snapshots
sudo snapper -c root create-config /
sudo btrfs subvolume delete /.snapshots
sudo mkdir /.snapshots
sudo mount -a
sudo chmod 750 /.snapshots
findmnt /.snapshots
```

- `create-config` insists on creating its own `.snapshots` nested inside `@`,
  which a rollback of `@` would take with it. So it's deleted and your
  `@snapshots` is mounted there again from fstab.
- `mount -a` also mounts everything else in fstab: an error about `/data`
  means its fstab line points at the raw LUKS partition instead of
  `/dev/mapper/cryptdata`.
- `findmnt` must show `subvol=/@snapshots`.
- Optional: CachyOS's `limine-snapper-sync` adds snapshots to the Limine menu.

---

## 17. Secure Boot

Do this last, once everything boots: with Secure Boot on, `limine.conf` is
locked by checksum and Limine's **E** editor stops working.

With Limine, sbctl signs **only Limine's EFI binary**. Limine itself verifies
the kernel, initramfs and its config by BLAKE2 hash. Never sign kernels by
hand (`sbctl sign`, `sbctl-batch-sign`).

### 17.1 Firmware: clear the keys

| | Gigabyte | AMI Aptio |
| --- | --- | --- |
| Where | BIOS tab → Secure Boot (appears with CSM off) | Security → Secure Boot |
| Mode | Secure Boot Mode → **Custom** | same |
| Clear | Key Management → **Reset To Setup Mode** / Delete All Secure Boot Variables | same; answer **No** to restoring factory keys |
| Also | Factory Key Provision → **Disabled** | same, if shown |

Leave Secure Boot **Disabled**. The screen must show **System Mode: Setup**
and the key stores (PK, KEK, db, dbx) with 0 keys. Save and exit.

This only empties a list in the firmware; disks are untouched, and **Restore
Factory Keys** brings the originals back.

### 17.2 Enroll your keys and lock Limine

```
sudo sbctl status
sudo sbctl create-keys
sudo sbctl enroll-keys --microsoft
sudo sbctl status

echo 'ENABLE_ENROLL_LIMINE_CONFIG=yes' | sudo tee -a /etc/default/limine
sudo limine-enroll-config
sudo limine-update
sudo sbctl list-files
sudo sbctl verify
grep -E 'path|module_path' /boot/limine.conf
```

- First `status`: Setup Mode **Enabled**.
- `create-keys`: your own PK/KEK/db, per machine (`/var/lib/sbctl`).
- `enroll-keys --microsoft`: your keys plus Microsoft's, which GPU and NIC
  option ROMs need (without them an NVIDIA card can leave the screen black).
  **Don't add `--firmware-builtin`**: on Gigabyte (and ASUS) it creates
  duplicate entries and a Secure Boot violation.
- Second `status`: Setup Mode **Disabled**.
- `ENABLE_ENROLL_LIMINE_CONFIG=yes`: every `limine-mkinitcpio` re-embeds the
  config checksum in Limine. `limine-enroll-config` / `limine-update`: do it
  now and install the signed Limine binary.
- `list-files` must contain **only** Limine's EFI files
  (`/boot/EFI/limine/limine_x64.efi`, `/boot/EFI/BOOT/BOOTX64.EFI`). If a
  `vmlinuz` or `initramfs` is listed, remove it:
  `sudo sbctl remove-file <path>`, then `sudo limine-mkinitcpio`. Otherwise
  sbctl re-signs the ESP kernel after Limine hashed it, and every boot warns
  "Blake2b hash … does not match".
- `verify` may show the ESP kernel as signed: fine. mkinitcpio's `[sbctl]`
  post hook signs the kernel at its source **before** limine-entry-tool copies
  it and computes the hash.
- Every `path:`/`module_path:` must end in `#<128-char hash>`.

### 17.3 Turn it on

Firmware → Secure Boot → **Enabled**. Then `sbctl status` shows Secure Boot
enabled. If it won't boot, set it back to Disabled and everything boots as
before.

### 17.4 TPM unlock: not used

`systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=7 --tpm2-with-pin=yes`
would let the TPM release the key after a PIN. Both machines use AMD's
firmware TPM (fTPM), whose secrets can be extracted on Zen 2/Zen 3 by voltage
glitching (faulTPM, 2023, physical access, no fix). Its anti-hammering
lockout then no longer protects a short PIN. The passphrase with Argon2id is
stronger; keep typing it.

---

## 18. Troubleshooting

**Get back into the system from the USB** (Secure Boot must be disabled to
boot the ISO; your keys stay enrolled):

```
lsblk -o NAME,SIZE,FSTYPE,LABEL
cryptsetup open "$(blkid -t LABEL=cryptroot -o device)" cryptroot
mount -o noatime,compress=zstd:1,subvol=@ /dev/mapper/cryptroot /mnt
arch-chroot /mnt
mount -a
```

`mount -a` inside the chroot mounts `/boot` and the other subvolumes from
fstab. Leave with `exit`, `umount -R /mnt`.

| Symptom | Cause | Fix |
| --- | --- | --- |
| `limine-install`: "The system is not using UEFI" | USB booted in legacy (CSM) mode | CSM off, boot "UEFI: <USB>", re-enter from the USB, rerun 10.4 |
| `nvme0n1p2 does not exist`, partitions "moved" to the other disk | NVMe names swap between boots | use labels/serials; the boot config uses UUIDs and is unaffected |
| Boot hangs on "A start job is running for /dev/mapper/cryptroot", no passphrase prompt | `rd.luks.name` empty or misspelled, or no `sd-encrypt` (empty `mkinitcpio.conf.d`) | check `grep cmdline /boot/limine.conf` and `cat /etc/mkinitcpio.conf.d/*.conf`, fix, `limine-mkinitcpio` |
| Same, but a prompt was there | prompt shown on a screen that lost sync | power-cycle the monitor, type the passphrase |
| "Cannot open access to console, the root account is locked" | no root password | set one from the USB chroot (`passwd`) |
| Black screen with a cursor after unlocking; Ctrl+Alt+F2 may still work | SDDM greeter crashes | `journalctl -b _UID=$(id -u sddm)` and `journalctl -b \| grep -iE 'kwin\|greeter'`; known causes: `--locale1` (KWin 6.8), missing `qt6-multimedia-ffmpeg`/`qt6-virtualkeyboard`/`qt6-svg`. Meanwhile `sudo systemctl disable sddm` and start `mango` from tty1 |
| "WARNING: Blake2b hash for … vmlinuz does not match" | sbctl re-signed the ESP kernel after hashing | 17.2: `sbctl remove-file` the kernel, `limine-mkinitcpio` |
| `unknown key '%INSTALLED_DB%' in local database` | Arch's pacman replaced CachyOS's | CachyOS repos above `[core]`, reinstall `pacman` from CachyOS |
| `paru: … libalpm.so.15: cannot open shared object file` | AUR `paru-bin` built for Arch's pacman | `pacman -Rns paru-bin && pacman -S paru` |
| `perl: warning: Setting locale failed` | `es_ES.UTF-8` not generated | uncomment it in `/etc/locale.gen`, `sudo locale-gen` |
| `Bad configuration option: permitrootlogin` on `git clone`/`ssh` | hardening file in `ssh_config.d` | move it to `sshd_config.d` (14.6) |
| `systemctl --user`: "Failed to connect to user scope bus" | shell from `su`/`sudo -u` | log in directly as the user |
| `mkdir: Permission denied` in your home | something created as root | `sudo chown -R emrtnn:users /home/emrtnn` |
| `mount -a`: "wrong fs type" on `/data` | fstab points at the raw LUKS partition | use `/dev/mapper/cryptdata` (or the inner filesystem UUID) |
| Mount fails with "No such file or directory" for a subvolume | typo when creating it | `btrfs subvolume list`, `mv` to rename from the top level (`subvolid=5`) |
| `resolvectl` still lists ISP DNS servers | DHCP DNS on the connection | `nmcli connection modify … ipv4.ignore-auto-dns yes ipv6.ignore-auto-dns yes` |
| mkinitcpio: `Possibly missing firmware for module: 'qat_6xxx'` | Intel QuickAssist driver pulled in by autodetect | harmless |

---

## 19. Reference

### 19.1 Repository layout

Every top-level directory is a stow package mirroring `$HOME`
(`zsh/.config/zsh/.zshrc` → `~/.config/zsh/.zshrc`), except `librewolf/`
(copied into the browser profile by hand). Also: `.luarc.json` (Lua LSP
globals), `.stowrc` (target `~`), `.gitignore` (blocks keys and secrets).

| Package | Puts in `$HOME` | What |
| --- | --- | --- |
| `zsh` | `~/.zshenv`, `~/.config/zsh/{.zshenv,.zshrc}` | environment, zsh with eza/fzf/zoxide/carapace/yazi, vi mode, history, aliases |
| `git` | `~/.config/git/{config,allowed_signers}` | identity, SSH signing, defaults, aliases |
| `jj` | `~/.config/jj/config.toml` | Jujutsu: same identity and key, ediff merge tool |
| `tmux` | `~/.config/tmux/tmux.conf` | `C-a` prefix, vi mode, Caelus bar, smart-splits, resurrect + continuum |
| `nvim` *(folded)* | `~/.config/nvim` | lazy.nvim; `lua/plugins/mason.lua` installs LSPs/formatters/linters |
| `doom` *(folded)* | `~/.config/doom` | Doom Emacs config and Caelus theme |
| `mango` *(folded)* | `~/.config/mango` | compositor config |
| `yazi` | `~/.config/yazi/…` | file manager, Caelus, full-border plugin |
| `bat` | `~/.config/bat/{config,themes/caelus.tmTheme}` | pager theme |
| `tuicr` | `~/.config/tuicr/…` | code review TUI, Caelus |
| `face` | `~/.face.png` | account picture |
| `wallpapers` | `~/Pictures/Wallpapers` | wallpapers (Noctalia reads this folder) |
| `gtk` | `~/.config/gtk-{3,4}.0/…`, `~/.gtkrc-2.0` | adw-gtk3 dark, Papirus, Bibata |
| `cursor` | `~/.icons/default/index.theme`, `~/.local/share/icons/default/index.theme`, `~/.Xresources` | cursor for X/XWayland apps |
| `qt` | `~/.config/qt6ct/…` | Breeze style, Caelus palette, Papirus |
| `dolphin` | `~/.local/share/color-schemes/Caelus.colors`, `…/servicemenus/open-in-yazi.desktop` | KDE colors, "Open in Yazi" |
| `mimeapps` | `~/.config/mimeapps.list` (+ legacy copy) | defaults: LibreWolf, Dolphin, Gwenview, OnlyOffice |
| `emacs` | `~/.config/systemd/user/emacs.service`, `~/.local/bin/emacs-ediff` | Emacs daemon with the session; jj merge tool |
| `mpv` | `~/.config/mpv/mpv.conf` | ModernZ OSC |
| `xdg-desktop-portal` | `mango-portals.conf`, `xdg-desktop-portal-wlr/config` | wlr for screencast/screenshots, gtk for the rest |
| `cliphist` | `cliphist.service`, `cliphist-images.service` | clipboard history for Noctalia |
| `foot` | `~/.config/foot/foot.ini` | terminal |
| `noctalia` | `~/.config/noctalia/{config.toml,palettes/Caelus.json}` | bar, launcher, notifications, lock, palette |
| `satty` | `~/.config/satty/config.toml` | screenshot annotation |

### 19.2 Environment variables

| File | Read by | Holds |
| --- | --- | --- |
| `~/.config/zsh/.zshenv` | every zsh | PATH, EDITOR/VISUAL, XDG dirs, `SSH_AUTH_SOCK`, `TMUX_TMPDIR`, npm prefix, `CHROME_PATH` |
| `~/.config/zsh/.zshrc` | interactive zsh | fzf options, aliases |
| `~/.config/mango/config/env.conf` | Mango and its children | toolkit backends, Qt theme, `XDG_MENU_PREFIX`, Java fix, `BROWSER` (cursor: `misc.conf`) |
| `/etc/environment` | every login | GPU variables (NVIDIA on monad, ROCm) |

SDDM starts Mango from a non-interactive login zsh, so Mango inherits
`.zshenv` (not `.zshrc`, so nothing session-wide goes there) and adds
`env.conf`. Noctalia launches apps as systemd units, so `autostart.conf` runs
`dbus-update-activation-environment --systemd --all` to hand them Mango's
environment. `emacs.service` gets `SSH_AUTH_SOCK` from `gcr-ssh-agent.socket`.
After changing `.zshenv` or `env.conf`, log out and back in.

### 19.3 Caelus palette

Hand-copied into files that can't import anything (Neovim, Doom, LibreWolf
CSS, Mango, tmux, foot, Noctalia…); keep them in sync with this table.

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

Terminal ANSI order (black red green yellow blue magenta cyan white): normal
`bg red green orange blue magenta cyan gray9`, bright
`gray3 redLight greenLight orangeLight blueLight magentaLight cyanLight fg`.
