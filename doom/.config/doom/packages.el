;; -*- no-byte-compile: t; -*-
;;; $DOOMDIR/packages.el
;;
;; Packages on top of what the modules in init.el install. Run `doom sync'
;; after changing this file.

;; Major mode for systemd unit files (.service, .timer, .socket, ...).
(package! systemd)

;; ACP client that hosts the Autolith conversation (SPC o p a). Sly, which
;; `autolith-ide' also needs, comes with the :lang common-lisp module.
(package! agent-shell)
