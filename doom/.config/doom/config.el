;;; config.el -*- lexical-binding: t; -*-

;; Personal settings. Reload with `M-x doom/reload' (SPC h r r).

;;; Toolchain
;; Language servers and formatters are installed by Neovim's mason.nvim (the
;; list in ~/.config/nvim/lua/plugins/mason.lua). ~/.config/zsh/.zshenv
;; already has its bin dir on PATH; this also covers an Emacs started without that environment.
(let ((mason-bin (expand-file-name "~/.local/share/nvim/mason/bin")))
  (when (file-directory-p mason-bin)
    (add-to-list 'exec-path mason-bin)
    (unless (member mason-bin (split-string (or (getenv "PATH") "") path-separator))
      (setenv "PATH" (concat mason-bin path-separator (getenv "PATH"))))))

;; Build missing tree-sitter grammars without asking (needs git and a C
;; compiler), so ts-modes just work.
(setq treesit-auto-install-grammar 'always)

(setq doom-theme 'caelus              ; themes/caelus-theme.el
      doom-font (font-spec :family "Iosevka Nerd Font Mono" :size 22)
      display-line-numbers-type 'relative)

;; Cursor color per evil state, matching the modeline indicator.
(setq evil-normal-state-cursor   '(box "#ef934d")
      evil-insert-state-cursor   '(bar "#72ca68")
      evil-visual-state-cursor   '(box "#e28dc6")
      evil-replace-state-cursor  '(hbar "#f16e65")
      evil-operator-state-cursor '(hollow "#efbf71"))

;;; Editing
(setq scroll-margin 8
      evil-want-fine-undo t)

;;; LSP
(after! lsp-mode
  (setq lsp-headerline-breadcrumb-enable t
        lsp-inlay-hint-enable t
        lsp-enable-file-watchers nil)   ; big node_modules trees

  ;; Python: basedpyright (installed by mason) instead of pyright.
  (setq lsp-pyright-langserver-command "basedpyright")

  ;; Solidity: vscode-solidity-server (Juan Blanco's, includes Solhint).
  (add-to-list 'lsp-language-id-configuration '(solidity-mode . "solidity"))
  (lsp-register-client
   (make-lsp-client
    :new-connection (lsp-stdio-connection '("vscode-solidity-server" "--stdio"))
    :activation-fn (lsp-activate-on "solidity")
    :priority 1
    :server-id 'vscode-solidity)))

(add-hook 'solidity-mode-local-vars-hook #'lsp! 'append)

;;; Formatters (apheleia): same tools as nvim's conform.nvim
(after! apheleia
  (setf (alist-get 'biome apheleia-formatters)
        '("biome" "format" "--stdin-file-path" filepath))
  (dolist (mode '(js-ts-mode typescript-ts-mode tsx-ts-mode json-ts-mode css-ts-mode))
    (setf (alist-get mode apheleia-mode-alist) 'biome))
  (setf (alist-get 'nix-mode apheleia-mode-alist) 'alejandra
        (alist-get 'nix-ts-mode apheleia-mode-alist) 'alejandra
        (alist-get 'alejandra apheleia-formatters) '("alejandra" "-q" "-")
        (alist-get 'solidity-mode apheleia-mode-alist) 'forge-fmt
        (alist-get 'forge-fmt apheleia-formatters) '("forge" "fmt" "--raw" "-")
        (alist-get 'python-mode apheleia-mode-alist) 'ruff
        (alist-get 'python-ts-mode apheleia-mode-alist) 'ruff))

;;; Dashboard: same hydra banner as nvim's snacks dashboard
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

(setq vterm-max-scrollback 100000)

(defun ai/pi ()
  "Toggle a pi session for the current project in a right-side window."
  (interactive)
  (require 'vterm)
  (let* ((root (or (doom-project-root) default-directory))
         (name (format "pi:%s" (doom-project-name)))
         (buf  (get-buffer name))
         (win  (and buf (get-buffer-window buf))))
    (if win
        (delete-window win)
      (unless (buffer-live-p buf)
        (let ((default-directory root)
              (vterm-shell "pi"))
          (setq buf (save-window-excursion (vterm name)))))
      (select-window
       (display-buffer buf '((display-buffer-in-side-window)
                             (side . right)
                             (window-width . 0.4)))))))

(map! :leader :desc "Pi" "o i" #'ai/pi)
