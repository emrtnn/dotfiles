;;; $DOOMDIR/config.el -*- lexical-binding: t; -*-
;;
;; Only what Doom does not already do. Changes here need no `doom sync'.

(setq user-full-name "emrtnn"
      user-mail-address "emrtnn@proton.me")

;;; Look

(setq doom-theme 'caelus                ; themes/caelus-theme.el
      doom-font (font-spec :family "Iosevka Nerd Font Mono" :size 18)
      doom-variable-pitch-font (font-spec :family "GeistMono Nerd Font" :size 20)
      display-line-numbers-type 'relative
      scroll-margin 8)

;; Cursor colour per evil state, matching the modeline indicator.
(setq evil-normal-state-cursor   '(box "#ef934d")
      evil-insert-state-cursor   '(bar "#72ca68")
      evil-visual-state-cursor   '(box "#e28dc6")
      evil-replace-state-cursor  '(hbar "#f16e65")
      evil-operator-state-cursor '(hollow "#efbf71"))

;; Dashboard: hydra banner instead of the Doom logo, and no GitHub footer.
(defun my-dashboard-banner ()
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

(setq +dashboard-ascii-banner-fn #'my-dashboard-banner)
(remove-hook '+dashboard-functions #'+dashboard-widget-footer)

;;; Editing

;; Reload a buffer as soon as its file changes on disk, so edits made by the
;; pi agent show up while the buffer is visible. Doom alone only checks when
;; you switch buffer, window or frame.
(after! autorevert
  (setq auto-revert-use-notify t        ; Doom turns this off
        auto-revert-avoid-polling t))   ; notifications only, no 5s polling
(global-auto-revert-mode 1)

;; Projects live in ~/Projects/<group>/<repo>.
(setq projectile-project-search-path '(("~/Projects" . 2)))

;; These files are symlinks into ~/dotfiles, which Emacs 31 does not trust,
;; so without this there are no elisp diagnostics in my own config.
(add-to-list 'trusted-content "~/dotfiles/")

;;; Languages
;; Eglot starts one server per buffer and needs nothing here for Go (gopls),
;; Zig (zls), Python (basedpyright), Nix (nixd) or shell.

;; C: without a compile_commands.json clangd parses .h files as C++.
(set-eglot-client! '(c-mode c-ts-mode)
                   '("clangd" :initializationOptions
                     (:fallbackFlags ["-xc" "-std=gnu23"])))

;; Rust: diagnostics from clippy instead of `cargo check'.
(setq rustic-lsp-check-command "clippy")

;; Lua: Doom's server command expects lua-language-server unpacked in its own
;; data dir. Mine is on PATH, so replace it once Doom has registered its own.
(after! (:or lua-mode lua-ts-mode)
  (set-eglot-client! '(lua-mode lua-ts-mode) '("lua-language-server")))

;; CMake: Doom only hooks the server up when the non-tree-sitter cmake-mode
;; loads, which never happens once cmake-ts-mode is in use.
(add-hook 'cmake-ts-mode-local-vars-hook #'lsp! 'append)

;; systemd units: the mode comes from packages.el, the server is systemd-lsp.
(set-eglot-client! 'systemd-mode '("systemd-lsp"))
(add-hook 'systemd-mode-local-vars-hook #'lsp! 'append)

;; Solidity with Foundry.
(load! "+solidity")

;;; Formatting on save
;; Only where I do not use the formatter Doom picks by default.

(set-formatter! 'ruff :modes '(python-mode python-ts-mode))

(set-formatter! 'alejandra '("alejandra" "--quiet" "-")
  :modes '(nix-mode nix-ts-mode))

;; C: LLVM style with left-aligned pointers, unless the project has its own
;; .clang-format.
(set-formatter! 'clang-format
  '("clang-format" "-assume-filename"
    (or (apheleia-formatters-local-buffer-file-name)
        (apheleia-formatters-mode-extension)
        ".c")
    (unless (locate-dominating-file default-directory ".clang-format")
      "--style={BasedOnStyle: LLVM, PointerAlignment: Left}")))

;; CMake: 2-space indent, unless the project has its own .gersemirc.
(set-formatter! 'gersemi
  '("gersemi"
    (unless (locate-dominating-file default-directory ".gersemirc")
      '("--indent" "2"))
    "-")
  :modes '(cmake-mode cmake-ts-mode))

;;; Spell check: English and Spanish at the same time

(setq ispell-dictionary "en")

(add-hook! 'spell-fu-mode-hook
  (defun my-spell-add-spanish-h ()
    (spell-fu-dictionary-add (spell-fu-get-ispell-dictionary "es"))
    (spell-fu-dictionary-add
     (spell-fu-get-personal-dictionary
      "es-personal" (expand-file-name "ispell/es.pws" doom-data-dir)))))

;;; Pi coding agent (SPC o p)

(defun ai/pi-agent ()
  "Open the pi coding agent in ghostel in a vertical split, rooted at the project.
Reuses the buffer for the project if it is still running."
  (interactive)
  (require 'ghostel)
  (let* ((root (or (doom-project-root) default-directory))
         (name (format "*pi:%s*" (abbreviate-file-name root)))
         (buf  (get-buffer name)))
    ;; A leftover from a failed start is not a terminal: throw it away.
    (when (and buf (not (eq (buffer-local-value 'major-mode buf) 'ghostel-mode)))
      (kill-buffer buf)
      (setq buf nil))
    (if-let* ((win (and buf (get-buffer-window buf))))
        (select-window win)
      (select-window (split-window-right (- (floor (* 0.35 (window-total-width))))))
      (if buf
          (switch-to-buffer buf)
        (setq buf (get-buffer-create name))
        (with-current-buffer buf
          (setq default-directory root))
        (switch-to-buffer buf)
        (ghostel-exec buf (or (executable-find "pi") "pi"))))))

(defun ai/pi-agent-kill ()
  "Kill the pi agent buffer for the current project and quit its window.
When called from inside a pi buffer, kill that one."
  (interactive)
  (let* ((buf (if (string-prefix-p "*pi:" (buffer-name))
                  (current-buffer)
                (get-buffer (format "*pi:%s*"
                                    (abbreviate-file-name
                                     (or (doom-project-root) default-directory)))))))
    (if (not (buffer-live-p buf))
        (message "No pi agent buffer for this project")
      (let ((win (get-buffer-window buf)))
        ;; Don't prompt about the running process.
        (when-let* ((proc (get-buffer-process buf)))
          (set-process-query-on-exit-flag proc nil))
        (kill-buffer buf)
        (when (and (window-live-p win) (not (one-window-p t)))
          (delete-window win))))))

(defvar-keymap ai/pi-agent-map
  :doc "Keymap for the pi coding agent."
  "p" '("Open pi agent" . ai/pi-agent)
  "k" '("Kill pi agent" . ai/pi-agent-kill))

(map! :leader :desc "pi agent" "o p" ai/pi-agent-map)
