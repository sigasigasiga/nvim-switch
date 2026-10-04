# nvim-switch

Switch your UI between running Neovim server instances with `:connect`.
Requires Neovim 0.12+, no dependencies.

Every instance running this plugin registers its server address under
`stdpath('state')/switch/<pid>` and removes it on exit (stale entries from
crashed instances are pruned automatically).

## Example config

```lua
vim.pack.add {
    'https://github.com/sigasigasiga/nvim-switch',
}

local switch = require 'switch'

vim.api.nvim_create_user_command(
    'Switch',
    function(args) switch.pick(args.bang) end,
    { bang = true, desc = 'Switch UI to another Neovim server (! stops current server if unused)' }
)

vim.api.nvim_create_user_command(
    'SetInstanceName',
    function(args) switch.instance_name = args.args end,
    { nargs = 1, desc = 'Set the current Neovim server instance name' }
)
```

## Similar plugins

* [servery.nvim](https://github.com/wurli/servery.nvim)
