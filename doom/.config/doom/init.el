;;; $DOOMDIR/init.el -*- lexical-binding: t; -*-
;;
;; Enabled Doom modules. Run `doom sync' after changing this file.
;;
;; `K' on a module name shows its documentation. Every available module is
;; listed in ~/.config/emacs/static/init.example.el.

(doom! :completion
       (corfu +orderless +icons)
       (vertico +icons)

       :ui
       doom
       dashboard
       hl-todo
       indent-guides
       ligatures
       (modeline +light)
       ophints
       (popup +defaults)
       (vc-gutter +pretty)
       vi-tilde-fringe
       workspaces

       :editor
       (evil +everywhere)
       file-templates
       fold
       (format +onsave)
       snippets
       (whitespace +guess +trim)

       :emacs
       (dired +icons)
       electric
       tramp
       undo
       vc

       :term
       ghostel                          ; hosts the pi agent (SPC o p)

       :checkers
       (syntax +flymake +icons)
       (spell +aspell)

       :tools
       (docker +lsp)
       editorconfig
       (eval +overlay)
       lookup
       (lsp +eglot)
       magit
       make
       tree-sitter
       upload

       :lang
       ;; Systems languages.
       (cc +lsp +tree-sitter)
       (go +lsp +tree-sitter)
       (rust +lsp +tree-sitter)
       (zig +lsp +tree-sitter)

       ;; Also edited by hand.
       emacs-lisp
       (lua +lsp +tree-sitter)
       (nix +lsp +tree-sitter)
       (python +lsp +tree-sitter)
       (sh +lsp)
       solidity                         ; Foundry setup in +solidity.el

       ;; Stock Doom support only: nothing about these in config.el.
       data
       (javascript +lsp +tree-sitter)
       (json +lsp +tree-sitter)
       (markdown +tree-sitter)
       org
       (php +lsp +tree-sitter)
       (web +lsp +tree-sitter)
       (yaml +lsp +tree-sitter)

       :config
       (default +bindings +smartparens))
