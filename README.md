# nvim-switch

Switch your UI between running Nvim server instances with `:connect`.
Requires Nvim 0.12+, no dependencies.

Every instance running this plugin registers its server address under
`stdpath('state')/switch/<pid>` and removes it on exit (stale entries from
crashed instances are pruned automatically).

## Usage

Lua API: `require('switch').list()`, `require('switch').pick(bang)`.

```lua
vim.pack.add {
    'https://github.com/sigasigasiga/nvim-switch',
}

vim.api.nvim_create_user_command(
    'Switch',
    function(args) require 'switch'.pick(args.bang) end,
    { bang = true, desc = 'Switch UI to another Nvim server (! stops current server if unused)' }
)
```
