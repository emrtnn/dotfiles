;;; $DOOMDIR/config.el -*- lexical-binding: t; -*-

;; Place your private configuration here! Remember, you do not need to run 'doom
;; sync' after modifying this file!


;; Some functionality uses this to identify you, e.g. GPG configuration, email
;; clients, file templates and snippets. It is optional.
(setq user-full-name "emrtnn"
      user-mail-address "emrtnn@proton.me")

;; Doom exposes five (optional) variables for controlling fonts in Doom:
;;
;; - `doom-font' -- the primary font to use
;; - `doom-variable-pitch-font' -- a non-monospace font (where applicable)
;; - `doom-big-font' -- used for `doom-big-font-mode'; use this for
;;   presentations or streaming.
;; - `doom-symbol-font' -- for symbols
;; - `doom-serif-font' -- for the `fixed-pitch-serif' face
;;
;; See 'C-h v doom-font' for documentation and more examples of what they
;; accept. For example:

(setq doom-font (font-spec :family "Iosevka Nerd Font Mono" :size 18)
      doom-variable-pitch-font (font-spec :family "GeistMono Nerd Font" :size 20))

;; Set line numbers relative to cursor position
(setq display-line-numbers-type 'relative)

;; Cursor color per evil state, matching the modeline indicator.
(setq evil-normal-state-cursor   '(box "#ef934d")
      evil-insert-state-cursor   '(bar "#72ca68")
      evil-visual-state-cursor   '(box "#e28dc6")
      evil-replace-state-cursor  '(hbar "#f16e65")
      evil-operator-state-cursor '(hollow "#efbf71"))

;;; Editing
(setq scroll-margin 8
      evil-want-fine-undo t)

;;; Window Management
(defun my/find-file-split-right (file)
  "Open FILE in a new window to the right."
  (interactive "FFind file: ")
  (select-window (split-window-right))
  (find-file file))

(defun my/find-file-split-below (file)
  "Open FILE in a new window below."
  (interactive "FFind file: ")
  (select-window (split-window-below))
  (find-file file))

(after! embark
  (map! :map embark-file-map
        "v" #'my/find-file-split-right
        "h" #'my/find-file-split-below))

;; There are two ways to load a theme. Both assume the theme is installed and
;; available. You can either set `doom-theme' or manually load a theme with the
;; `load-theme' function. This is the default:
(setq doom-theme 'caelus)
;; Specify both a dark and light theme, like so and Doom will choose which one
;; to load based on your system light/dark setting:
;;
;;   (setq doom-theme '(doom-one   . doom-one-light))   ; (DARK . LIGHT)
;;
;; If you want more pro-active theme switching based on OS light/dark mode, look
;; up the `auto-dark' package.

;; This determines the style of line numbers in effect. If set to `nil', line
;; numbers are disabled. For relative line numbers, set this to `relative'.
(setq display-line-numbers-type t)

;; If you use `org' and don't want your org files in the default location below,
;; change `org-directory'. It must be set before org loads!
(setq org-directory "~/org/")

;;; Dashboard: hydra
(defun caelus/dashboard-hydra-banner ()
  (propertize
   (string-join
    '("⣴⣶⣤⡤⠦⣤⣀⣤⠆     ⣈⣭⣿⣶⣿⣦⣼⣆"
      "    ⠉⠻⢿⣿⠿⣿⣿⣶⣦⠤⠄⡠⢾⣿⣿⡿⠋⠉⠉⠻⣿⣿⡛⣦"
      "          ⠈⢿⣿⣟⠦ ⣾⣿⣿⣷    ⠻⠿⢿⣿⣧⣄"
      "           ⣸⣿⣿⢧ ⢻⠻⣿⣿⣷⣄⣀⠄⠢⣀⡀⠈⠙⠿⠄"
      "          ⢠⣿⣿⣿⠈    ⣻⣿⣿⣿⣿⣿⣿⣿⣿⣛⣳⣤⣀⣀"
      "   ⢠⣧⣶⣥⡤⢄ ⣸⣿⣿⠘  ⢀⣴⣿⣿⡿⠛⣿⣿⣧⠈⢿⠿⠟⠛⠻⠿⠄"
      "  ⣰⣿⣿⠛⠻⣿⣿⡦⢹⣿⣷   ⢊⣿⣿⡏  ⢸⣿⣿⡇ ⢀⣠⣄⣾⠄"
      " ⣠⣿⠿⠛ ⢀⣿⣿⣷⠘⢿⣿⣦⡀ ⢸⢿⣿⣿⣄ ⣸⣿⣿⡇⣪⣿⡿⠿⣿⣷⡄"
      " ⠙⠃   ⣼⣿⡟  ⠈⠻⣿⣿⣦⣌⡇⠻⣿⣿⣷⣿⣿⣿ ⣿⣿⡇ ⠛⠻⢷⣄"
      "      ⢻⣿⣿⣄   ⠈⠻⣿⣿⣿⣷⣿⣿⣿⣿⣿⡟ ⠫⢿⣿⡆"
      "       ⠻⣿⣿⣿⣿⣶⣶⣾⣿⣿⣿⣿⣿⣿⣿⣿⣿⡟⢀⣀⣤⣾⡿⠃")
    "\n")
   'face '+dashboard-banner))

(setq +dashboard-ascii-banner-fn #'caelus/dashboard-hydra-banner
      fancy-splash-image nil)          ; use the ASCII banner in GUI frames too

;; Replace the footer widget (GitHub icon linking to the Doom repo) with a
;; blank spacer so the load-time line keeps its margin.
(defun caelus/dashboard-widget-spacer ()
  (insert "\n\n"))

(setq +dashboard-functions
      (cl-substitute #'caelus/dashboard-widget-spacer #'+dashboard-widget-footer
                     +dashboard-functions))

;; Adjust vterm's max scrollback
(setq vterm-max-scrollback 100000)

;; Projectile project autodiscovery
(setq projectile-project-search-path '(("~/Dev" . 2)))

;; Dired keybinds and configuration
(map! :after dired
      :map dired-mode-map
      :n "h" #'dired-up-directory
      :n "l" #'dired-find-file)

;;; LANGUAGES
;; lsp semantic highlights
(setq lsp-semantic-tokens-enable t)

;;; Systemd unit files
;; Highlighting comes from `systemd-mode' (packages.el); LSP from the
;; `systemd-lsp' binary (pacman: systemd-lsp).
(after! lsp-mode
  (add-to-list 'lsp-language-id-configuration '(systemd-mode . "systemd"))
  (lsp-register-client
   (make-lsp-client :new-connection (lsp-stdio-connection "systemd-lsp")
                    :activation-fn (lsp-activate-on "systemd")
                    :server-id 'systemd-lsp)))
(add-hook 'systemd-mode-local-vars-hook #'lsp! 'append)

;; Astro
(add-to-list 'auto-mode-alist '("\\.astro\\'" . web-mode))
(add-hook 'web-mode-hook #'lsp! 'append)
