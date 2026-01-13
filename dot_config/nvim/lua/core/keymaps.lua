vim.g.mapleader = " "
vim.g.maplocalleader = " "

local opts = { noremap = true, silent = true }


vim.keymap.set("n", "<leader>w", function()
  vim.opt.wrap = not vim.opt.wrap:get()
  vim.opt.linebreak = vim.opt.wrap:get()
end, { desc = "Toggle line wrap" })

vim.keymap.set("v", "J", ":m '>+1<CR>gv=gv", { desc = "moves lines down in visual selection" })
vim.keymap.set("v", "K", ":m '<-2<CR>gv=gv", { desc = "moves lines up in visual selection" })

vim.keymap.set("n", "<C-d>", "<C-d>zz", { desc = "move down in buffer with cursor centered" })
vim.keymap.set("n", "<C-u>", "<C-u>zz", { desc = "move up in buffer with cursor centered" })

vim.keymap.set("n", "n", "nzzzv")
vim.keymap.set("n", "N", "Nzzzv")

vim.keymap.set("v", "<", "<gv", opts)
vim.keymap.set("v", ">", ">gv", opts)

vim.keymap.set("n", "x", '"_x', opts)

vim.keymap.set("i", "<C-c>", "<Esc>")

vim.keymap.set("n", "<C-c>", ":nohl<CR>", { desc = "Clear search highlight", silent = true })

vim.keymap.set("n", "<leader>f", vim.lsp.buf.format)


vim.keymap.set("n", "<leader>fp", function()
    local filePath = vim.fn.expand("%:~")
    vim.fn.setreg("+", filePath)
    print("File path copied to clipboard: " .. filePath)
end, { desc = "Copy file path to clipboard" })

local isLspDiagnosticsVisible = true
vim.keymap.set("n", "<leader>lx", function()
    isLspDiagnosticsVisible = not isLspDiagnosticsVisible
    vim.diagnostic.config({
        virtual_text = isLspDiagnosticsVisible,
        underline = isLspDiagnosticsVisible
    })
end, { desc = "Toggle LSP diagnostics" })

vim.keymap.set("n", "<leader>a", "ggVG<CR>", { desc = "Select all" }, opts)

-- Normal mode: replace word under cursor
vim.keymap.set("n", "gs", [[:let @/ = '\V\<'.escape(expand('<cword>'), '\').'\>'<CR>cgn]], { desc = "Replace word under cursor" })

-- Visual mode: replace selection
vim.keymap.set("x", "gs", [["vy:let @/ = '\V'.escape(@v, '\')<CR>cgn]], { desc = "Replace selection" })

vim.keymap.set("n", "<F10>", function()
  vim.cmd.write()
  local file = vim.fn.expand("%:p")
  local output = vim.fn.expand("%:p:r")
  local dir = vim.fn.expand("%:p:h")

  -- Compile
  vim.fn.system(string.format("g++ -std=c++17 %s -o %s", 
    vim.fn.shellescape(file), vim.fn.shellescape(output)))

  if vim.v.shell_error ~= 0 then
    return
  end

  -- Run in vertical split terminal
  vim.cmd("vsplit | vertical resize 40")
  vim.cmd.term(string.format("cd %s && %s", 
    vim.fn.shellescape(dir),
    vim.fn.shellescape(output)
  ))
  vim.cmd.startinsert()
end, { noremap = true, silent = true, desc = "Compile and run C++" })
