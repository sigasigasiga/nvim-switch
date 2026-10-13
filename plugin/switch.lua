if vim.g.loaded_switch then
    return
end
vim.g.loaded_switch = true

local function now()
    -- `CLOCK_MONOTONIC` is guaranteed to be system-wide by POSIX,
    -- so the values are comparable between peers.
    local t = vim.uv.clock_gettime('monotonic')
    return t.sec + t.nsec / 1e9
end

vim.g.switch_last_access = now()

vim.api.nvim_create_autocmd({ 'UIEnter', 'FocusGained' }, {
    group = vim.api.nvim_create_augroup('sigasigasiga/nvim-switch', { clear = true }),
    callback = function() vim.g.switch_last_access = now() end,
})
