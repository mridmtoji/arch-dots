return {
    'stevearc/oil.nvim',
    ---@module 'oil'
    ---@type oil.SetupOpts
    opts = {},
    dependencies = { { "nvim-mini/mini.icons", opts = {} } },
    lazy = false,
    opts = {
        view_options = {
            show_hidden = true,
        }
    },
    config = function(_, opts)
        require("oil").setup(opts) 
    end,
    vim.keymap.set("n", "-", "<CMD>Oil<CR>", { desc = "Open parent directory" }),
    vim.keymap.set("n", "_", "<CMD>Oil --float<CR>", { desc = "Open current directory in a float window"})
}
