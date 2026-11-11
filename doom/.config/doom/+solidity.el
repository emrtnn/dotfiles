;;; +solidity.el --- Solidity with Foundry -*- lexical-binding: t; -*-
;;
;; On top of Doom's `:lang solidity' (solidity-mode plus a prettier formatter):
;;
;;   LSP       vscode-solidity-server through eglot. It bundles solc-js and
;;             solhint, so compiler and lint diagnostics both come from it.
;;   Format    forge fmt on save, using the project's foundry.toml [fmt].
;;   Commands  forge build / test on the localleader (SPC m).
;;
;; Per-project values come from `forge config --json', which resolves
;; foundry.toml, profiles and Foundry's defaults.

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

;;; Editing
;; solidity-mode derives from c-mode, which gets two things wrong for it.

;; cc-mode expects a `;' after `struct S { ... }' and `enum E { ... }', so it
;; indents the line after the closing brace as a continuation.
(defun +solidity-lineup-after-brace (_langelem)
  "Return 0 if the previous code line ends with `}', else nil."
  (save-excursion
    (beginning-of-line)
    (c-backward-syntactic-ws)
    (when (eq (char-before) ?\}) 0)))

(add-hook! 'solidity-mode-hook
  (defun +solidity-fix-c-mode-h ()
    (c-set-offset 'statement-cont
                  (list #'+solidity-lineup-after-brace
                        (alist-get 'statement-cont c-offsets-alist)))
    ;; Don't run the C compiler over Solidity while eglot is not connected.
    (remove-hook 'flymake-diagnostic-functions #'flymake-cc t)))

;;; Formatter
;; `:lang solidity' sets prettier inside its own `after!' block, so this has
;; to be registered after it to win.
(after! solidity-mode
  (set-formatter! 'forge-fmt '("forge" "fmt" "--raw" "-")
    :modes '(solidity-mode)))

;;; LSP

(defvar +solidity-solc-cache-dir (file-name-concat doom-cache-dir "solc/")
  "Where vscode-solidity-server caches the soljson compilers it downloads.
Without it the server writes soljson-<version>.js into the project root.")

(defun +solidity-lsp-settings (root)
  "Return the vscode-solidity-server settings for the project at ROOT."
  (let* ((cfg  (+solidity-forge-config root))
         (solc (alist-get 'solc cfg))
         (libs (append (alist-get 'libs cfg) nil)))
    (list
     :solidity
     (list
      :linter "solhint"
      ;; Use the project's pinned solc (foundry.toml `solc = "0.8.17"'). The
      ;; server's default, "latest", rejects exact pragmas such as
      ;; `pragma solidity 0.8.17;'. `solc' may also be a path to a binary,
      ;; which solc-js can't use, so only accept a bare version.
      :compileUsingRemoteVersion
      (if (and (stringp solc)
               (string-match-p "\\`[0-9]+\\.[0-9]+\\.[0-9]+\\'" solc))
          solc
        "latest")
      ;; Directories searched for `import "pkg/..."': Foundry `libs' (which
      ;; includes Soldeer's dependencies/) plus lib/ and node_modules/. The
      ;; server reads remappings.txt itself.
      :packageDefaultDependenciesDirectory
      (vconcat (delete-dups (append libs '("lib" "node_modules"))))))))

(defun +solidity-eglot-workspace-configuration (_server)
  "Return the settings eglot pushes to vscode-solidity-server.
Eglot calls this in the project root with `major-mode' set to the mode the
server was started in, so it stays out of the way of other servers."
  (when (derived-mode-p 'solidity-mode)
    (+solidity-lsp-settings default-directory)))

(set-eglot-client! 'solidity-mode
                   (list "vscode-solidity-server" "--stdio"
                         ;; The server treats a string as its solc cache dir.
                         :initializationOptions
                         (lambda (_server)
                           (make-directory +solidity-solc-cache-dir t)
                           (expand-file-name +solidity-solc-cache-dir))))

(after! eglot
  (setq-default eglot-workspace-configuration
                #'+solidity-eglot-workspace-configuration))

;; `:lang solidity' has no +lsp flag, so start the server the way Doom's
;; +lsp modules do.
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
