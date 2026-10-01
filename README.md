# nvim-switch

Switch your UI between running Nvim server instances with `:connect`.
Requires Nvim 0.12+, no dependencies.

Every instance running this plugin registers its server address under
`stdpath('state')/switch/<pid>` and removes it on exit (stale entries from
crashed instances are pruned automatically).

## Usage

- `:Switch`  – pick another instance and `:connect` to it
- `:Switch!` – same, but uses `:connect!` (stops the current server if no other UI is attached)

Lua API: `require('switch').list()`, `require('switch').pick(bang)`.
