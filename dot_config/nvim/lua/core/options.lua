vim.opt.cursorline = true
-- vim.opt.cursorlineopt = "number"

vim.opt.number = true
vim.opt.relativenumber = true

vim.opt.fillchars = {
  horiz = "━",
  horizup = "┻",
  horizdown = "┳",
  vert = "┃",
  vertleft = "┨",
  vertright = "┣",
  verthoriz = "╋",
  fold = " ",
  eob = " ",
  diff = "┃",
  msgsep = "‾",
  foldsep = "│",
  foldclose = "",
  foldopen = "",
}

vim.opt.tabstop = 4
vim.opt.softtabstop = 4
vim.opt.shiftwidth = 4

vim.opt.expandtab = true
vim.opt.autoindent = true
vim.opt.smartindent = true

vim.opt.wrap = false
vim.opt.showmode = false
-- vim.opt.showmatch = true

vim.opt.updatetime = 100

vim.opt.splitright = true
vim.opt.splitbelow = true

vim.opt.scrolloff = 5
vim.opt.sidescrolloff = 5

vim.opt.mouse = "a"

vim.opt.display = vim.opt.display + { "lastline" }

vim.opt.incsearch = true
vim.opt.inccommand = "split"
vim.opt.ignorecase = true
vim.opt.smartcase = true

vim.opt.autoread = true

vim.opt.backspace = "indent,eol,start"
vim.opt.nrformats:remove({ "octal" }) -- useful for <C-a> and <C-x>

vim.opt.listchars = {
    tab = "→ ",
    eol = "↵",
    space = "·",
    trail = "·",
    extends = "↷",
    precedes = "↶",
    nbsp = "␣",
    lead = "·",
}

vim.opt.shortmess:append('c')
vim.opt.shortmess:append('s')

vim.opt.title = true
vim.opt.hlsearch = true

vim.opt.showcmd = true

vim.opt.swapfile = false
vim.opt.backup = false
vim.opt.undofile = false
vim.opt.writebackup = false

vim.opt.path:append({ "**" })

vim.opt.splitkeep = "cursor"

vim.cmd([[let &t_Cs = "\e[4:3m"]])
vim.cmd([[let &t_Ce = "\e[4:0m"]])

vim.opt.formatoptions:append({ "r" })

vim.opt.wildmenu = true
vim.opt.ruler = false

vim.opt.completeopt = "menu,menuone,longest"

vim.opt.wildignorecase = true
vim.opt.hidden = true
vim.opt.ttimeout = true
vim.opt.ttimeoutlen = 100

vim.opt.clipboard:append("unnamedplus")

vim.opt.signcolumn = "yes" 
vim.opt.termguicolors = true
vim.opt.isfname:append("@-@")

