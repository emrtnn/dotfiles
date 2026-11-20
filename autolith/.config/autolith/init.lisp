(let ((name "omniroute-anthropic"))
  (register-provider
   name
   :description   "Anthropic API key via OmniRoute"
   :family        ':anthropic
   :protocol      ':messages
   :models        '((:name "claude-fable-5-2" :context-window 1000000
                     :reasoning-efforts ("low" "medium" "high" "xhigh" "max"))
                    (:name "claude-opus-5-5" :context-window 1000000
                     :reasoning-efforts ("low" "medium" "high" "xhigh" "max"))
                    (:name "claude-sonnet-5-5" :context-window 1000000
                     :reasoning-efforts ("low" "medium" "high" "xhigh" "max")))
   :endpoint      "http://iberica-vps/v1/messages"
   :authenticator #'openai-compatible--authenticate
   :factory
   (lambda (configuration &key reasoning-summaries-p)
     (declare (ignore reasoning-summaries-p))
     (make-instance 'anthropic-api-key-provider
                    :configuration      configuration
                    :credential-manager (api-key-credential-manager-create
                                         :provider-name        name
                                         :pathname             (configuration-api-keys-path configuration)
                                         :environment-variable "OMNIROUTE_API_KEY")
                    :session-id         (make-identifier)))))

(setf (config :model-provider) "omniroute-anthropic")
(setf (config :model) "claude-opus-5-5")

;;; Standing instructions, sent with every provider request.

(define-context-contributor user-git-policy (request)
  "Keep changes uncommitted until the user asks for a commit."
  (declare (ignore request))
  (make-context-contribution
   :identifier  "user-git-policy"
   :instruction "Git: leave your changes uncommitted in the working tree. Commit only when the user explicitly asks for a commit. This overrides the default rule to commit finished work."
   :class       ':mandatory
   :lifetime    ':turn))
