;;; +solidity.el --- Solidity / Foundry development -*- lexical-binding: t; -*-
;;
;; Builds on Doom's `:lang solidity' (solidity-mode; flycheck-only checkers; a
;; prettier formatter) and brings it in line with the nvim setup.  Loaded from
;; config.el via `load!'.
;;
;;   LSP        vscode-solidity-server (mason), the same server as nvim's
;;              `solidity_ls'.  It bundles solc-js AND solhint, so compiler and
;;              solhint diagnostics both arrive through lsp -> flymake (solhint
;;              reads the project's .solhint.json).
;;   Format     forge fmt on save, using the project's foundry.toml [fmt].
;;   Indent     whatever `forge fmt' will write (fmt.tab_width / fmt.style), so
;;              typing and saving agree.
;;   Commands   forge build / test on the localleader (SPC m), with clickable
;;              compiler errors.
;;
;; Per-project values come from `forge config --json' (~10ms).  It resolves
;; foundry.toml, profiles, ~/.foundry/foundry.toml and Foundry's defaults, so
;; nothing here has to parse TOML.

;;; Foundry project helpers

(defun +solidity-foundry-root (&optional dir)
  "Return the nearest directory at or above DIR containing foundry.toml."
  (locate-dominating-file (or dir default-directory) "foundry.toml"))

(defun +solidity-forge-config (&optional dir)
  "Return the resolved Foundry config (an alist) for the project at DIR.
Nil when DIR is not inside a Foundry project or forge is unavailable."
  (when-let* ((root (+solidity-foundry-root dir))
              ((executable-find "forge")))
    (let ((default-directory root))
      (with-temp-buffer
        (when (eq 0 (call-process "forge" nil '(t nil) nil "config" "--json"))
          (goto-char (point-min))
          (ignore-errors
            (json-parse-buffer :object-type 'alist
                               :null-object nil :false-object nil)))))))

;;; Indentation
;; Indent the way `forge fmt' will rewrite the buffer on save: the project's
;; fmt.tab_width/style, else 4 spaces (Foundry's default and the Solidity style
;; guide).  Don't use the global 2 here, because forge would undo it on every
;; save.
(defun +solidity-indent-like-forge-h ()
  "Set indentation for this buffer to match `forge fmt'."
  (let-alist (alist-get 'fmt (+solidity-forge-config))
    (let ((width (or .tab_width 4)))
      (setq-local c-basic-offset width
                  tab-width width
                  evil-shift-width width
                  indent-tabs-mode (equal .style "tab")
                  fill-column (or .line_length 120)))))

(add-hook 'solidity-mode-hook #'+solidity-indent-like-forge-h)

;; cc-mode parses `struct S { ... }' / `enum E { ... }' as C, where a `;' must
;; follow the brace.  So it takes the next line for a continuation
;; (`statement-cont') and indents it one extra level.  Solidity has no such
;; `;', so after a closing brace there is nothing to continue.
(defun +solidity-lineup-after-brace (_langelem)
  "Return 0 if the previous code line ends with `}', else nil."
  (save-excursion
    (beginning-of-line)
    (c-backward-syntactic-ws)
    (when (eq (char-before) ?\}) 0)))

(add-hook! 'solidity-mode-hook
  (defun +solidity-fix-offsets-h ()
    (c-set-offset 'statement-cont
                  (list #'+solidity-lineup-after-brace
                        (alist-get 'statement-cont c-offsets-alist)))))

;; Insert-state TAB.  cc-mode binds TAB to `c-indent-line-or-region', which in
;; a line's indentation only ever re-indents, so TAB on an indented line does
;; nothing.  Use `indent-for-tab-command' like every other mode: the first TAB
;; re-indents, a repeated TAB inserts another level, and past the indentation
;; it inserts.  Bound as "TAB", not [tab]: Doom's smart [tab] (snippet
;; fields, completion popup) still goes first and falls through to this.
(map! :after solidity-mode
      :map solidity-mode-map
      :i "TAB" #'indent-for-tab-command)

;;; Diagnostics
;; Being a c-mode, solidity-mode also gets cc-mode's `flymake-cc' backend,
;; which runs the C compiler over Solidity.  Diagnostics come from the LSP
;; (solc + solhint).  cppcheck is skipped in +flymake-linters.el.
(add-hook! 'solidity-mode-hook
  (defun +solidity-drop-c-checkers-h ()
    (remove-hook 'flymake-diagnostic-functions #'flymake-cc t)))

;;; Formatter
;; :lang solidity calls `set-formatter!' for prettier (via npx) inside its own
;; `(after! solidity-mode ...)'.  That runs after any `(after! apheleia ...)' in
;; config.el, so it silently replaced forge-fmt.  This `after!' is registered
;; later than the module's, so it runs last and wins.  forge finds the nearest
;; foundry.toml from the buffer's directory and applies its [fmt] section.
(after! solidity-mode
  (set-formatter! 'forge-fmt '("forge" "fmt" "--raw" "-") :modes '(solidity-mode)))

;;; LSP
(defvar +solidity-solc-cache-dir (file-name-concat doom-cache-dir "solc/")
  "Where vscode-solidity-server caches the soljson compilers it downloads.
If unset, the server writes soljson-<version>.js into the project root.")

(defun +solidity-lsp-settings (root)
  "Return the vscode-solidity-server `solidity' settings for the project at ROOT."
  (let* ((cfg  (+solidity-forge-config root))
         (solc (alist-get 'solc cfg))
         (libs (append (alist-get 'libs cfg) nil)))
    (list
     :solidity
     (list
      :linter "solhint"
      ;; Use the project's pinned solc (foundry.toml `solc = "0.8.17"').  The
      ;; server's default, "latest", rejects exact pragmas such as
      ;; `pragma solidity 0.8.17;'.  `solc' may also be a path to a binary,
      ;; which solc-js can't use, so only accept a bare version.
      :compileUsingRemoteVersion
      (if (and (stringp solc)
               (string-match-p "\\`[0-9]+\\.[0-9]+\\.[0-9]+\\'" solc))
          solc
        "latest")
      ;; Directories searched for `import "pkg/..."': Foundry `libs' (which
      ;; includes Soldeer's dependencies/) plus lib/ and node_modules/.  The
      ;; server reads remappings.txt itself.
      :packageDefaultDependenciesDirectory
      (vconcat (delete-dups (append libs '("lib" "node_modules"))))))))

(defun +solidity--lsp-log-message (workspace params)
  "Log the server's window/logMessage PARAMS unless the message is null."
  (when (lsp:show-message-request-params-message params)
    (lsp--window-log-message workspace params)))

(after! lsp-mode
  (lsp-register-client
   (make-lsp-client
    :new-connection (lsp-stdio-connection '("vscode-solidity-server" "--stdio"))
    :activation-fn (lsp-activate-on "solidity")
    :priority 1                 ; beat lsp-mode's built-in Nomic Foundation client
    :server-id 'vscode-solidity
    ;; Once per start the server sends window/logMessage with "message": null,
    ;; and lsp-mode's default handler errors on it ("Error processing message
    ;; (wrong-type-argument stringp nil)").  Drop those; log the rest as usual.
    :notification-handlers
    (let ((handlers (make-hash-table :test #'equal)))
      (puthash "window/logMessage" #'+solidity--lsp-log-message handlers)
      handlers)
    :initialization-options     ; the server treats a string as its solc cache dir
    (lambda ()
      (make-directory +solidity-solc-cache-dir t)
      (expand-file-name +solidity-solc-cache-dir))
    ;; The server never requests workspace/configuration.  It only applies
    ;; settings pushed through didChangeConfiguration, so push them on startup.
    :initialized-fn
    (lambda (workspace)
      (with-lsp-workspace workspace
        (lsp--set-configuration
         (+solidity-lsp-settings (lsp--workspace-root workspace))))))))

;; :lang solidity has no +lsp flag, so start lsp the same way Doom's +lsp
;; modules do.
(add-hook 'solidity-mode-local-vars-hook #'lsp! 'append)

;;; Foundry commands (SPC m ...)
(defun +solidity--forge (args)
  "Run `forge ARGS' with `compile' from the Foundry project root.
With a prefix argument, edit the command before running it."
  (let* ((default-directory
          (or (+solidity-foundry-root)
              (user-error "Not in a Foundry project (no foundry.toml above %s)"
                          (abbreviate-file-name default-directory))))
         (command (concat "forge " args)))
    (compile (if current-prefix-arg (compilation-read-command command) command))))

(defun +solidity--relative-file ()
  "Return the current file's path relative to the Foundry root, shell-quoted."
  (unless buffer-file-name
    (user-error "Buffer is not visiting a file"))
  (shell-quote-argument
   (file-relative-name buffer-file-name (+solidity-foundry-root))))

(defun +solidity/build ()
  "Run `forge build'."
  (interactive)
  (+solidity--forge "build"))

(defun +solidity/gas-report ()
  "Run the test suite with a gas report."
  (interactive)
  (+solidity--forge "test --gas-report"))

(defun +solidity/test-all ()
  "Run the whole test suite."
  (interactive)
  (+solidity--forge "test"))

(defun +solidity/test-rerun ()
  "Re-run only the tests that failed on the previous run."
  (interactive)
  (+solidity--forge "test --rerun -vvv"))

(defun +solidity/test-file ()
  "Run the tests in the current file, with traces for failures."
  (interactive)
  (+solidity--forge (concat "test -vvv --match-path " (+solidity--relative-file))))

(defun +solidity/test-at-point ()
  "Run the test or invariant function at or above point, with traces."
  (interactive)
  (let ((name (save-excursion
                (end-of-line)
                (when (re-search-backward
                       "\\_<function[ \t\n]+\\(\\(?:test\\|invariant\\)[[:alnum:]_]*\\)"
                       nil t)
                  (match-string-no-properties 1)))))
    (unless name
      (user-error "No test function at or above point"))
    ;; forge matches against the full signature, e.g. "testFoo(uint256)", so
    ;; anchor on the opening paren to avoid also running testFooBar.
    (+solidity--forge (format "test -vvv --match-path %s --match-test '^%s\\('"
                              (+solidity--relative-file) name))))

;; The test submenu is a plain keymap, like `ai/pi-agent-map' in config.el,
;; not map!'s `(:prefix ("t" . "desc") ...)'.  Flymake's elisp checker compiles
;; this file without Doom's macros, so it treats map! as a function and fails
;; on that dotted pair ("proper-list-p").
(defvar-keymap +solidity-test-map
  :doc "forge test commands for solidity-mode."
  "a" '("all"          . +solidity/test-all)
  "f" '("file"         . +solidity/test-file)
  "t" '("at point"     . +solidity/test-at-point)
  "r" '("rerun failed" . +solidity/test-rerun))

(map! :after solidity-mode
      :localleader
      :map solidity-mode-map
      :desc "forge build"      "b" #'+solidity/build
      :desc "forge gas report" "g" #'+solidity/gas-report
      :desc "forge test"       "t" +solidity-test-map)

;; Make compiler diagnostics in *compilation* clickable (paths are relative to
;; the Foundry root, which is where `+solidity--forge' runs):
;;   solc:  " --> src/Foo.sol:12:5:"     solar: "  ╭▸ src/Foo.sol:4:17"
(after! compile
  (dolist (rule '((forge-solc  "^ *--> \\([^ \n]+\\.sol\\):\\([0-9]+\\):\\([0-9]+\\):" 1 2 3)
                  (forge-solar "^ *╭▸ \\([^ \n]+\\.sol\\):\\([0-9]+\\):\\([0-9]+\\)" 1 2 3)))
    (setf (alist-get (car rule) compilation-error-regexp-alist-alist) (cdr rule))
    (add-to-list 'compilation-error-regexp-alist (car rule))))
