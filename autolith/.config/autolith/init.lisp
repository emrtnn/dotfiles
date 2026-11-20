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

