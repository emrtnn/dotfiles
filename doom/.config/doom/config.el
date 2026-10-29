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

;;; EDITOR CONFIG
;; Configure file reload on external changes
(setq auto-revert-use-notify t)
(setq global-auto-revert-non-file-buffers t)
(global-auto-revert-mode 1)

;; Set line numbers relative to cursor position
(setq display-line-numbers-type 'relative)

;; Indentation, mirroring nvim (tabstop=2 shiftwidth=2 expandtab shiftround).
(setq-default indent-tabs-mode nil
              tab-width 2
              standard-indent 2
              evil-shift-width 2
              evil-shift-round t)

(setq +whitespace-guess-in-projects t)

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
(setq projectile-project-search-path '(("~/Projects" . 2)))

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

;;; LSP SERVERS

;; C/C++ : clangd flags
(after! lsp-clangd
  (setq lsp-clients-clangd-args
        '("--background-index" "--clang-tidy" "--header-insertion=iwyu"
          "--completion-style=detailed" "--function-arg-placeholders"
          "--fallback-style=llvm")))

;; Rust : rust-analyzer (clippy on check, all features, build + proc-macro)
(after! lsp-rust
  (setq lsp-rust-all-features t
        lsp-rust-analyzer-cargo-run-build-scripts t
        lsp-rust-analyzer-proc-macro-enable t
        lsp-rust-analyzer-cargo-watch-command "clippy"))

;; Python : basedpyright (types/hover) + ruff add-on (lint + organize-imports)
;; IMPORTANT: these must be set BEFORE lsp-pyright loads. lsp-pyright registers
;; its server dependency (`basedpyright-langserver') from
;; `lsp-pyright-langserver-command' AT LOAD TIME, so `after!' would be too late
;; (lsp would look for the nonexistent `pyright-langserver' and silently fall
;; back to ruff only). A plain top-level setq runs at config load, before any
;; python buffer triggers lsp-pyright, and defcustom respects the prior value.
(setq lsp-pyright-langserver-command "basedpyright"
      lsp-pyright-disable-organize-imports t          ; ruff owns import organization
      lsp-pyright-type-checking-mode "basic"
      ;; built-in severity overrides (ruff/basedpyright split, matching nvim)
      lsp-pyright-diagnostic-severity-overrides
      '(("reportUnusedImport"     . "none")
        ("reportUnusedVariable"   . "none")
        ("reportUndefinedVariable" . "none")
        ("reportUnboundVariable"  . "none")
        ("reportRedeclaration"    . "none")
        ("reportDuplicateImport"  . "none")))
;; ruff starts automatically as an add-on once `ruff' is on PATH. nvim disables
;; ruff's hover so basedpyright owns it; lsp-mode has no per-client hover toggle,
;; so if hover becomes noisy, uncomment and verify this:
;; (add-hook 'lsp-after-initialize-hook
;;           (lambda ()
;;             (when (eq (lsp--client-server-id (lsp--workspace-client lsp--cur-workspace)) 'ruff)
;;               (lsp:set-server-capabilities-hover-provider?
;;                (lsp--workspace-server-capabilities lsp--cur-workspace) nil))))

;; Lua : lua-language-server
(after! lsp-lua
  (setq lsp-lua-completion-call-snippet "Replace"
        lsp-lua-hint-enable t
        lsp-lua-telemetry-enable nil))

;; TS/JS : inlay hints (ts-ls; lsp-mode drives both ts.* and js.* from these)
(after! lsp-javascript
  (setq lsp-javascript-display-parameter-name-hints "literals"
        lsp-javascript-display-parameter-type-hints t
        lsp-javascript-display-variable-type-hints t
        lsp-javascript-display-property-declaration-type-hints t
        lsp-javascript-display-return-type-hints t
        lsp-javascript-display-enum-member-value-hints t))

;; Solidity : use solhint (no defcustom -> JSON path)
(after! lsp-mode
  (lsp-register-custom-settings '(("solidity.linter" "solhint"))))

;; Docker : let hadolint own these best-practice diagnostics
(after! lsp-dockerfile
  (setq lsp-dockerfile-deprecated-maintainer "ignore"
        lsp-dockerfile-directive-casing "ignore"
        lsp-dockerfile-empty-continuation-line "ignore"
        lsp-dockerfile-instruction-casing "ignore"
        lsp-dockerfile-instruction-cmd-multiple "ignore"
        lsp-dockerfile-instruction-entrypoint-multiple "ignore"
        lsp-dockerfile-instruction-healthcheck-multiple "ignore"
        lsp-dockerfile-instruction-json-single-quotes "ignore"))

;; Biome (JS/TS/JSON/CSS lint + code actions) via the third-party `lsp-biome'
;; (packages.el). Runs as an add-on next to ts-ls / css-ls. Formatting stays in
;; apheleia.
(after! lsp-biome
  (advice-add 'lsp-biome--has-config-p :override #'always))

;; Tailwind: lsp-mode's built-in client (add-on, starts when the project has a
;; tailwind config or tailwindcss v4 in package.json). Its default mode list
;; lacks css-ts-mode, which Doom uses for .css.
(after! lsp-tailwindcss
  (add-to-list 'lsp-tailwindcss-major-modes 'css-ts-mode))

;; CSS: don't flag Tailwind v4 directives (@theme, @apply, @utility...) as
;; unknown at-rules.
(after! lsp-css
  (setq lsp-css-lint-unknown-at-rules "ignore"))

;;; FORMATTING (apheleia)
(after! apheleia
  ;; --- formatters apheleia doesn't define out of the box ---
  (setf (alist-get 'ruff-fix apheleia-formatters)        ; ruff lint autofix (stdin->stdout)
        '("ruff" "check" "-n" "--fix" "--fix-only" "--stdin-filename" filepath "-"))
  (setf (alist-get 'alejandra apheleia-formatters)
        '("alejandra" "--quiet" "-"))
  (setf (alist-get 'forge-fmt apheleia-formatters)
        '("forge" "fmt" "--raw" "-"))
  (setf (alist-get 'php-cs-fixer apheleia-formatters)    ; no stdin -> use apheleia `inplace'
        '("php-cs-fixer" "fix" "--using-cache=no" "--quiet" inplace))
  ;; gersemi: 2-space indent unless the project ships a .gersemirc.
  (setf (alist-get 'gersemi apheleia-formatters)
        '("gersemi"
          (when (not (locate-dominating-file default-directory ".gersemirc"))
            (list "--indent" "2"))
          "-"))
  ;; clang-format: LLVM + PointerAlignment Left, unless a project .clang-format
  ;; exists (clang-format reads that itself).
  (setf (alist-get 'clang-format apheleia-formatters)
        '("clang-format"
          "-assume-filename"
          (or (apheleia-formatters-local-buffer-file-name)
              (apheleia-formatters-mode-extension) ".c")
          (when (not (locate-dominating-file default-directory ".clang-format"))
            "--style={BasedOnStyle: LLVM, PointerAlignment: Left}")))

  ;; --- per-mode formatter choice (classic + tree-sitter modes) ---
  ;; Order for python mirrors conform: lint-fix, organize-imports, then format.
  (dolist (entry '((python-mode        . (ruff-fix ruff-isort ruff))
                   (python-ts-mode     . (ruff-fix ruff-isort ruff))
                   (js-mode            . biome)
                   (js-ts-mode         . biome)
                   (typescript-mode    . biome)
                   (typescript-ts-mode . biome)
                   (tsx-ts-mode        . biome)
                   (json-mode          . biome)
                   (js-json-mode       . biome)
                   (json-ts-mode       . biome)
                   (css-mode           . biome)
                   (css-ts-mode        . biome)
                   (nix-mode           . alejandra)
                   (nix-ts-mode        . alejandra)
                   (php-mode           . php-cs-fixer)
                   (php-ts-mode        . php-cs-fixer)
                   (cmake-mode         . gersemi)
                   (cmake-ts-mode      . gersemi)
                   (solidity-mode      . forge-fmt)
                   (bash-ts-mode       . shfmt)))
    (setf (alist-get (car entry) apheleia-mode-alist) (cdr entry))))
;; Note: lua->stylua, rust->rustfmt, zig->zig-fmt, sh->shfmt and web-mode->prettier
;; (for .astro) are already apheleia/Doom defaults, so they need no entry here.

;;; SPELLCHECK (spell-fu + aspell, English and Spanish at the same time)
;; A word is accepted if it appears in either dictionary.
(setq ispell-dictionary "en")

(add-hook! 'spell-fu-mode-hook
  (defun my/spell-fu-add-spanish-h ()
    (spell-fu-dictionary-add (spell-fu-get-ispell-dictionary "es"))
    (spell-fu-dictionary-add
     (spell-fu-get-personal-dictionary "es-personal" (expand-file-name "ispell/es.pws" doom-data-dir)))))

;;; DIAGNOSTICS (flymake)
(after! flymake
  (setq flymake-show-diagnostics-at-end-of-line 'short))

;; Emacs 31 refuses to byte-compile (hence flymake-check) elisp in "untrusted"
;; files, since macro expansion runs code. Doom only trusts the ~/.config/{doom,
;; emacs}/ *symlink* paths, but these live in ~/dotfiles and dev projects in
;; `buffer-file-truename' (the ~/ form), not an expanded /home/... path.
(dolist (dir '("~/dotfiles/" "~/Projects/"))
  (add-to-list 'trusted-content dir))

(custom-set-faces!
  '(flymake-error   :underline nil)
  '(flymake-warning :underline nil)
  '(flymake-note    :underline nil))

;;; EXTRA LINTERS (flymake backends with no language server)
;; cppcheck / cmakelint / hadolint / statix run alongside the LSP diagnostics.
;; Backend definitions live in +flymake-linters.el (ported from nvim lint.lua).
(load! "+flymake-linters")
(add-hook! '(c-mode-hook c++-mode-hook c-ts-mode-hook c++-ts-mode-hook
             cmake-mode-hook cmake-ts-mode-hook
             dockerfile-mode-hook dockerfile-ts-mode-hook
             nix-mode-hook nix-ts-mode-hook)
           #'+my/flymake-extra-linters)
;; Re-add the extra backends after lsp sets up its own flymake backend.
(with-eval-after-load 'lsp-diagnostics
  (add-hook 'lsp-diagnostics-mode-hook #'+my/flymake-extra-linters))

;;; AI
;; Pi Coding agent
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
