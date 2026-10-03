if vim.g.loaded_switch then
    return
end

vim.g.loaded_switch = true

local registry = require 'switch.registry'

registry.register()

vim.api.nvim_create_autocmd('VimLeavePre', {
    group = vim.api.nvim_create_augroup('sigasigasiga/switch', {}),
    callback = registry.unregister,
})
