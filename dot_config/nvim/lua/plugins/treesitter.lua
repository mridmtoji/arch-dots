return {
    {
        "nvim-treesitter/nvim-treesitter",
        branch = "main",
        build = ":TSUpdate",
        lazy = false,
        opts = {
            ensure_installed = {
                "bash", "c", "cpp", "diff", "html", "javascript", "jsdoc", "json", "jsonc",
                "lua", "luadoc", "luap", "markdown", "markdown_inline", "printf", "python",
                "query", "qmljs", "regex", "toml", "tsx", "typescript", "vim", "vimdoc",
                "xml", "yaml",
            },
            highlight = { enable = true },
            indent = { enable = true, disable = { "cpp", "c" } },
            incremental_selection = {
                enable = true,
                keymaps = {
                    init_selection = "<C-space>",
                    node_incremental = "<C-space>",
                    node_decremental = "<bs>",
                },
            },
            textobjects = {
                select = {
                    enable = true,
                    lookahead = true,
                    keymaps = {
                        ["af"] = "@function.outer",
                        ["if"] = "@function.inner",
                    },
                },
                move = {
                    enable = true,
                    goto_next_start = {
                        ["]f"] = "@function.outer",
                        ["]c"] = "@class.outer",
                        ["]a"] = "@parameter.inner",
                    },
                    goto_next_end = {
                        ["]F"] = "@function.outer",
                        ["]C"] = "@class.outer",
                        ["]A"] = "@parameter.inner",
                    },
                    goto_previous_start = {
                        ["[f"] = "@function.outer",
                        ["[c"] = "@class.outer",
                        ["[a"] = "@parameter.inner",
                    },
                    goto_previous_end = {
                        ["[F"] = "@function.outer",
                        ["[C"] = "@class.outer",
                        ["[A"] = "@parameter.inner",
                    },
                },
            },
        },
        config = function(_, opts)
            local seen = {}
            opts.ensure_installed = vim.tbl_filter(function(lang)
                if seen[lang] then return false end
                seen[lang] = true
                return true
            end, opts.ensure_installed)

            require("nvim-treesitter").setup(opts)
        end,
    },

}

