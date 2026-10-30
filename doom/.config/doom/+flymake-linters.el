;;; +flymake-linters.el --- extra flymake backends with no language server -*- lexical-binding: t; -*-
;;
;; Custom Flymake backends for CLI linters that `flymake-collection' does NOT
;; ship (cppcheck, cmakelint, hadolint), plus wiring to enable the shipped
;; `flymake-collection-statix'.  Loaded from config.el via `load!'.
;;
;; These run ALONGSIDE lsp-mode's own flymake backend
;; (`lsp-diagnostics--flymake-backend'): every backend is added to the
;; buffer-local `flymake-diagnostic-functions' with buffer-local `add-hook', so
;; it is additive and never replaces another backend.  (lsp-mode adds its own
;; backend the same way and does not reset the list — that reset is eglot-only.)
;;
;; Mirrors ~/dotfiles/nvim/.config/nvim/lua/plugins/lint.lua.  Biome, ShellCheck,
;; Ruff, Clippy, clang-tidy and Solhint are already provided by language servers,
;; so they are intentionally NOT re-added here.
;;
;; CAPTURED REAL TOOL OUTPUT (parsers matched against reality, not guessed):
;;   cppcheck  (no stdin -> temp file; stderr):
;;     sample.c:5:5: error: Memory leak: p [memleak]
;;     sample.c:3:10: style: Variable 'p' can be declared as pointer to const [constVariablePointer]
;;   cmakelint (no stdin; only lints *.cmake / CMakeLists.txt -> temp file + .cmake symlink):
;;     CMakeLists.txt:3: Do not mix upper and lower case commands [readability/mixedcase]
;;   hadolint  (clean stdin, JSON):
;;     [{"code":"DL3006","column":1,"file":"-","level":"warning","line":1,"message":"..."}]

(require 'flymake)

;; Prefer a PATH install; fall back to the known mason/system paths so these work
;; even if the mason bin dir is not on `exec-path'.
(defvar +flymake-cppcheck-executable
  (or (executable-find "cppcheck") "/usr/bin/cppcheck")
  "Path to the cppcheck executable used by `+flymake-collection-cppcheck'.")

(defvar +flymake-cmakelint-executable
  (or (executable-find "cmakelint")
      "/home/emrtnn/.local/share/nvim/mason/bin/cmakelint")
  "Path to the cmakelint executable used by `+flymake-collection-cmakelint'.")

(defvar +flymake-hadolint-executable
  (or (executable-find "hadolint")
      "/home/emrtnn/.local/share/nvim/mason/bin/hadolint")
  "Path to the hadolint executable used by `+flymake-collection-hadolint'.")

;; Defined lazily, after `flymake-collection' loads, so this file is load-safe
;; even before the package is installed (Doom pulls it on `doom sync').
(with-eval-after-load 'flymake-collection
  (require 'flymake-collection-define)

  ;; --- cppcheck ----------------------------------------------------------
  (flymake-collection-define-rx +flymake-collection-cppcheck
    "A C/C++ static analyzer using cppcheck (no stdin -> temp file)."
    :title "cppcheck"
    :write-type 'file
    :pre-let ((cppcheck-exec +flymake-cppcheck-executable))
    :pre-check (unless (and cppcheck-exec (executable-find cppcheck-exec))
                 (error "Cannot find cppcheck executable"))
    :command `(,cppcheck-exec
               "-q"
               "--enable=warning,style,performance,portability"
               ,(concat "--language="
                        (pcase major-mode
                          ((or 'c-mode 'c-ts-mode) "c")
                          (_ "c++")))
               "--template={file}:{line}:{column}: {severity}: {message} [{id}]"
               ,flymake-collection-temp-file)
    :regexps
    ((error   bol (file-name) ":" line ":" column ": "
              "error" ": " (message) " [" (id (one-or-more (not (any "]")))) "]" eol)
     (warning bol (file-name) ":" line ":" column ": "
              "warning" ": " (message) " [" (id (one-or-more (not (any "]")))) "]" eol)
     (note    bol (file-name) ":" line ":" column ": "
              (or "style" "performance" "portability" "information" "note") ": "
              (message) " [" (id (one-or-more (not (any "]")))) "]" eol)))

  ;; --- cmakelint ---------------------------------------------------------
  (flymake-collection-define-rx +flymake-collection-cmakelint
    "A CMake linter using cmakelint (no stdin; needs a *.cmake filename)."
    :title "cmakelint"
    :write-type 'file
    :pre-let ((cmakelint-exec +flymake-cmakelint-executable))
    :pre-check (unless (and cmakelint-exec (executable-find cmakelint-exec))
                 (error "Cannot find cmakelint executable"))
    :command
    (let ((cmake-file (concat flymake-collection-temp-file ".cmake")))
      ;; Temp file lives in `flymake-collection-temp-dir', so this symlink is
      ;; removed when that directory is cleaned up.
      (make-symbolic-link flymake-collection-temp-file cmake-file t)
      (list cmakelint-exec cmake-file))
    :regexps
    ((warning bol (file-name) ":" line ": "
              (message) " [" (id (one-or-more (not (any "]")))) "]" eol)))

  ;; --- hadolint ----------------------------------------------------------
  (flymake-collection-define-enumerate +flymake-collection-hadolint
    "A Dockerfile linter using hadolint (JSON over stdin)."
    :title "hadolint"
    :write-type 'pipe
    :pre-let ((hadolint-exec +flymake-hadolint-executable))
    :pre-check (unless (and hadolint-exec (executable-find hadolint-exec))
                 (error "Cannot find hadolint executable"))
    :command `(,hadolint-exec "--no-color" "-f" "json" "-")
    :generator
    (car
     (flymake-collection-parse-json
      (buffer-substring-no-properties (point-min) (point-max))))
    :enumerate-parser
    (let-alist it
      (let ((loc (flymake-diag-region flymake-collection-source
                                      .line
                                      (and .column (max .column 1)))))
        (list flymake-collection-source
              (car loc)
              (cdr loc)
              (pcase .level
                ("error" :error)
                ("warning" :warning)
                ((or "info" "style" _) :note))
              (concat (propertize (format "%s" .code)
                                  'face 'flymake-collection-diag-id)
                      " " .message))))))

(defun +my/flymake-extra-linters ()
  "Add the extra Flymake linter backend(s) for the current major mode.

Additive: uses buffer-local `add-hook' on `flymake-diagnostic-functions'
so it coexists with lsp-mode's `lsp-diagnostics--flymake-backend'.  Also
ensures `flymake-mode' is on (needed for modes with no language server,
e.g. cmake/dockerfile/nix)."
  (require 'flymake-collection nil t)
  (require 'flymake-collection-statix nil t)
  (let ((backends
         (cond
          ;; solidity-mode derives from c-mode (and runs `c-mode-hook'), but
          ;; cppcheck would parse Solidity as C. Its LSP covers diagnostics.
          ((derived-mode-p 'solidity-mode) nil)
          ((derived-mode-p 'c-mode 'c++-mode 'c-ts-mode 'c++-ts-mode)
           '(+flymake-collection-cppcheck))
          ((derived-mode-p 'cmake-mode 'cmake-ts-mode)
           '(+flymake-collection-cmakelint))
          ((derived-mode-p 'dockerfile-mode 'dockerfile-ts-mode)
           '(+flymake-collection-hadolint))
          ((derived-mode-p 'nix-mode 'nix-ts-mode)
           '(flymake-collection-statix)))))
    (dolist (backend backends)
      (if (fboundp backend)
          (add-hook 'flymake-diagnostic-functions backend nil t)
        (flymake-log :warning "Flymake backend %s is not defined" backend)))
    (when backends
      (unless (bound-and-true-p flymake-mode)
        (flymake-mode 1)))))
