if vim.g.loaded_switch then
    return
end

vim.g.loaded_switch = true

local switch = require('switch')
switch.register()

local group = vim.api.nvim_create_augroup('switch', {})
vim.api.nvim_create_autocmd('VimLeavePre', {
    group = group,
    callback = switch.unregister,
})

vim.api.nvim_create_user_command(
    'Switch',
    function(args) switch.pick(args.bang) end,
    { bang = true, desc = 'Switch UI to another Nvim server (! stops current server if unused)' }
)
