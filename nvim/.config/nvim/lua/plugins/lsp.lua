return {
	{
		-- Only provides lsp/<server>.lua configs. It must be on 'runtimepath'
		-- before the first FileType event so vim.lsp.enable() can resolve them.
		"neovim/nvim-lspconfig",
		event = { "BufReadPre", "BufNewFile" },
		config = function()
			vim.diagnostic.config({
				virtual_text = true,
				virtual_lines = false,
				underline = false,
				signs = true,
				update_in_insert = false,
				severity_sort = true,
				float = { source = true },
				-- The default ]d / [d mappings show the diagnostic they land on.
				jump = {
					on_jump = function(diagnostic, bufnr)
						if diagnostic then
							vim.diagnostic.open_float({ bufnr = bufnr, scope = "cursor", focus = false })
						end
					end,
				},
			})

			local group = vim.api.nvim_create_augroup("UserLspConfig", { clear = true })

			-- Native progress (0.12): LSP work-done progress becomes progress
			-- messages, which feed vim.ui.progress_status() (shown in lualine) and
			-- the terminal's progress bar.
			vim.api.nvim_create_autocmd("LspProgress", {
				group = group,
				callback = function(event)
					local params = event.data.params
					local value = params.value
					if type(value) ~= "table" then
						return
					end
					vim.api.nvim_echo({ { value.message or "done" } }, false, {
						id = ("lsp.%d.%s"):format(event.data.client_id, params.token),
						kind = "progress",
						source = "vim.lsp",
						title = value.title,
						status = value.kind == "end" and "success" or "running",
						percent = value.percentage,
					})
				end,
			})

			vim.api.nvim_create_autocmd("LspAttach", {
				group = group,
				callback = function(event)
					local buf = event.buf
					local client = vim.lsp.get_client_by_id(event.data.client_id)
					if not client then
						return
					end

					local map = function(keys, func, desc)
						vim.keymap.set("n", keys, func, { buffer = buf, desc = "LSP: " .. desc })
					end

					-- Nvim defaults cover the rest: K hover, grn rename, gra code action,
					-- grr references, gri implementation, grt type definition,
					-- gO document symbols, <C-s> signature help, ]d/[d and <C-w>d.
					map("gd", vim.lsp.buf.definition, "Go to Definition")
					map("gD", vim.lsp.buf.declaration, "Go to Declaration")
					map("<leader>cd", vim.diagnostic.open_float, "Show Diagnostics")

					-- Language-specific keymaps and capability ownership
					if client.name == "clangd" then
						map("<leader>ch", "<cmd>LspClangdSwitchSourceHeader<cr>", "Switch Source/Header")
					elseif client.name == "ruff" then
						-- Basedpyright provides the richer Python hover response.
						client.server_capabilities.hoverProvider = false
					end

					if client:supports_method("textDocument/inlayHint", buf) then
						vim.lsp.inlay_hint.enable(true, { bufnr = buf })
						map("<leader>th", function()
							vim.lsp.inlay_hint.enable(
								not vim.lsp.inlay_hint.is_enabled({ bufnr = buf }),
								{ bufnr = buf }
							)
						end, "Toggle Inlay Hints")
					end
				end,
			})

			-- Completion capabilities blink.cmp adds on top of Nvim's defaults
			-- (from its get_lsp_capabilities()). Declared here so servers that start
			-- before the first InsertEnter get them without loading blink.cmp on
			-- every file open; blink applies the same table itself once loaded.
			vim.lsp.config("*", {
				capabilities = {
					textDocument = {
						completion = {
							completionItem = {
								resolveSupport = {
									properties = { "documentation", "detail", "additionalTextEdits", "command", "data" },
								},
								insertTextModeSupport = { valueSet = { 1 } },
							},
							completionList = {
								itemDefaults = {
									"commitCharacters",
									"editRange",
									"insertTextFormat",
									"insertTextMode",
									"data",
								},
							},
							insertTextMode = 1,
						},
					},
				},
			})

			-- C/C++
			vim.lsp.config("clangd", {
				cmd = {
					"clangd",
					"--background-index",
					"--clang-tidy",
					"--header-insertion=iwyu",
					"--completion-style=detailed",
					"--function-arg-placeholders",
					"--fallback-style=llvm",
				},
				init_options = {
					usePlaceholders = true,
					completeUnimported = true,
					clangdFileStatus = true,
				},
			})

			-- Rust
			vim.lsp.config("rust_analyzer", {
				settings = {
					["rust-analyzer"] = {
						cargo = {
							allFeatures = true,
							loadOutDirsFromCheck = true,
							buildScripts = { enable = true },
						},
						procMacro = { enable = true },
						check = { command = "clippy" },
					},
				},
			})

			-- This server already publishes both solc and Solhint diagnostics.
			vim.lsp.config("solidity_ls", {
				settings = { solidity = { linter = "solhint" } },
			})

			-- Hadolint owns the overlapping Dockerfile best-practice diagnostics;
			-- dockerls remains enabled for completion, navigation, and syntax errors.
			vim.lsp.config("dockerls", {
				settings = {
					docker = {
						languageserver = {
							diagnostics = {
								deprecatedMaintainer = "ignore",
								directiveCasing = "ignore",
								emptyContinuationLine = "ignore",
								instructionCasing = "ignore",
								instructionCmdMultiple = "ignore",
								instructionEntrypointMultiple = "ignore",
								instructionHealthcheckMultiple = "ignore",
								instructionJSONInSingleQuotes = "ignore",
							},
						},
					},
				},
			})

			-- Web: Biome provides lint diagnostics and code actions (formatting
			-- stays in conform). lspconfig only attaches it in projects with a
			-- biome.json; lint everywhere with Biome's defaults instead.
			vim.lsp.config("biome", {
				root_dir = function(bufnr, on_dir)
					on_dir(vim.fs.root(bufnr, { { "biome.json", "biome.jsonc" }, ".git" }) or vim.fn.getcwd())
				end,
			})

			local ts_inlay_hints = {
				parameterNames = { enabled = "literals" },
				parameterTypes = { enabled = true },
				variableTypes = { enabled = true },
				propertyDeclarationTypes = { enabled = true },
				functionLikeReturnTypes = { enabled = true },
				enumMemberValues = { enabled = true },
			}
			vim.lsp.config("vtsls", {
				settings = {
					typescript = { inlayHints = ts_inlay_hints },
					javascript = { inlayHints = ts_inlay_hints },
				},
			})

			-- Python: Ruff owns lint/name diagnostics and import organization;
			-- Basedpyright remains active for type analysis and language features.
			vim.lsp.config("basedpyright", {
				settings = {
					basedpyright = {
						disableOrganizeImports = true,
						analysis = {
							typeCheckingMode = "basic",
							diagnosticSeverityOverrides = {
								reportDuplicateImport = "none",
								reportRedeclaration = "none",
								reportUnboundVariable = "none",
								reportUndefinedVariable = "none",
								reportUnusedImport = "none",
								reportUnusedVariable = "none",
							},
						},
					},
				},
			})

			-- Lua
			vim.lsp.config("lua_ls", {
				settings = {
					Lua = {
						completion = { callSnippet = "Replace" },
						telemetry = { enable = false },
						hint = { enable = true },
					},
				},
			})

			vim.lsp.enable({
				-- C/C++
				"clangd",
				"neocmake",
				-- Systems
				"rust_analyzer",
				"zls",
				"solidity_ls",
				-- Nix, Lua, shell
				"nixd",
				"lua_ls",
				"bashls", -- also runs ShellCheck
				-- Python
				"basedpyright",
				"ruff",
				-- PHP
				"phpactor",
				-- Web
				"vtsls",
				"biome",
				"astro",
				"jsonls",
				"yamlls",
				-- Docker
				"dockerls",
				"docker_compose_language_service",
			})
		end,
	},
}
