;;; init.el -*- lexical-binding: t; -*-

;; Enabled Doom modules. Run `doom sync' after changing this file.
;; Languages mirror ~/.config/nvim (servers installed by mason.nvim, see
;; ~/.config/nvim/lua/plugins/mason.lua and the exec-path setup in config.el).

(doom! :completion
       (corfu +orderless +icons)
       (vertico +icons)

       :ui
       doom
       dashboard
       hl-todo
       indent-guides
       (modeline +light)
       nav-flash
       ophints
       (popup +defaults)
       (vc-gutter +pretty)
       vi-tilde-fringe
       window-select
       workspaces
       treemacs

       :editor
       (evil +everywhere)
       file-templates
       fold
       (format +onsave)
       multiple-cursors
       snippets
       (whitespace +guess +trim)

       :emacs
       (dired +icons)
       electric
       (ibuffer +icons)
       tramp
       undo
       vc

       :term
       vterm

       :checkers
       syntax

       :tools
       (docker +lsp +tree-sitter)
       editorconfig
       (eval +overlay)
       lookup
       lsp
       magit
       make
       tree-sitter

       :lang
       (cc +lsp +tree-sitter)
       data
       emacs-lisp
       (javascript +lsp +tree-sitter)
       (json +lsp +tree-sitter)
       (lua +lsp +tree-sitter)
       markdown
       (nix +lsp +tree-sitter)
       org
       (php +lsp +tree-sitter)
       (python +lsp +pyright +tree-sitter)
       (rust +lsp +tree-sitter)
       (sh +lsp)
       solidity
       (web +lsp +tree-sitter)
       (yaml +lsp +tree-sitter)
       (zig +lsp +tree-sitter)

       :config
       (default +bindings +smartparens))
