return {
  cmd = { 'pyright-langserver', '--stdio' },
  filetypes = { 'python' },
  root_markers = { 'pyproject.toml', 'setup.py', '.git' },
  settings = {
    python = {
      analysis = {
        typeCheckingMode = 'basic',
        autoImportCompletions = true,
        useLibraryCodeForTypes = true,
      },
    },
    telemetry = { enable = false },
  },
}

