return {
    "CRAG666/code_runner.nvim",
    config = function()
    require("code_runner").setup({
        mode = "term",
        focus = true,
        startinsert = true,
        term = {
            position = "vert", 
            size = 40,
        },
        filetype = {
            cpp = {
                "cd $dir &&",
                "g++ -std=c++17 $fileName -o /tmp/$fileNameWithoutExt &&",
                "/tmp/$fileNameWithoutExt;"
            },
            python = {
                "cd $dir &&",
                "python3 -u $file;",
            }
        },
    })

    vim.keymap.set("n", "<F9>", ":w<CR>:RunFile<CR>", { noremap = true, silent = true, desc = "Run C++ file" })
    end,
}
