local PROTOCOL_VERSION = 1

local function builtin_picker(items, on_choice)
    assert(#items > 0)

    vim.ui.select(
        items,
        {
            prompt = ('Switch to:\n%11s %16s %32s %24s%8s'):format('PID', 'Name', 'CWD', 'Open file', 'UI'),
            format_item = function(i)
                local ui_str = i.uis > 0 and ('  [%d UI]'):format(i.uis) or ''
                return ('%8d %16s %32s %24s%8s'):format(i.pid, i.instance_name, i.cwd, i.file, ui_str)
            end,
        },
        function(choice)
            if choice then
                on_choice(choice)
            end
        end
    )
end

local function telescope_picker(items, on_choice)
    assert(#items > 0)

    local pickers = require 'telescope.pickers'
    local finders = require 'telescope.finders'
    local conf = require 'telescope.config'.values
    local actions = require 'telescope.actions'
    local action_state = require 'telescope.actions.state'
    local entry_display = require 'telescope.pickers.entry_display'

    local displayer = entry_display.create {
        separator = ' ',
        items = {
            { width = 8, right_justify = true },
            { width = 16, right_justify = true },
            { width = 32, right_justify = true },
            { width = 24, right_justify = true },
            { width = 8, right_justify = true },
        },
    }

    local picker = pickers.new(
        {},
        {
            prompt_title = 'Switch to',
            finder = finders.new_table {
                results = items,
                entry_maker = function(i)
                    return {
                        value = i,
                        ordinal = ('%d %s %s %s'):format(i.pid, i.instance_name, i.cwd, i.file),
                        display = function()
                            return displayer {
                                { tostring(i.pid), 'TelescopeResultsNumber' },
                                i.instance_name,
                                i.cwd,
                                i.file,
                                i.uis > 0 and ('[%d UI]'):format(i.uis) or '',
                            }
                        end,
                    }
                end,
            },
            sorter = conf.generic_sorter {},
            attach_mappings = function(prompt_bufnr)
                actions.select_default:replace(function()
                    local entry = action_state.get_selected_entry()
                    actions.close(prompt_bufnr)
                    if entry then
                        on_choice(entry.value)
                    end
                end)
                return true
            end,
        }
    )

    picker:find()
end

local function recent_picker(items, on_choice)
    assert(#items > 0)
    on_choice(items[1])
end

local function with_picker(picker, items, bang)
    if #items == 0 then
        vim.notify('switch: no other instances found', vim.log.levels.WARN)
        return
    end

    table.sort(items, function(a, b)
        return a.last_access > b.last_access
    end)

    picker(items, function(choice)
        vim.cmd.connect { choice.addr, bang = bang }
    end)
end

local function query_server(addr)
    local ok, chan = pcall(
        vim.fn.sockconnect,
        addr:match([[^[^/\]+:%d+$]]) and 'tcp' or 'pipe',
        addr,
        { rpc = true }
    )

    if not ok or chan == 0 then
        return nil
    end

    local ok2, info = pcall(
        vim.rpcrequest,
        chan,
        'nvim_exec_lua',
        [[return require 'switch'.get_server_info()]],
        {}
    )

    pcall(vim.fn.chanclose, chan)

    if ok2 and info and info.protocol_version == PROTOCOL_VERSION then
        info.addr = addr
        return info
    end
end

local function server_list()
    local current_servers = vim.fn.serverlist()

    return vim.iter(vim.fn.serverlist { peer = true })
        -- yes, that's `M*N` but i don't expect `current_servers` to be big
        :filter(function(v) return not vim.list_contains(current_servers, v) end)
        :map(query_server)
        :totable()
end

local function now()
    -- `CLOCK_MONOTONIC` is guaranteed to be system-wide by POSIX,
    -- so the values are comparable between peers.
    local t = vim.uv.clock_gettime('monotonic')
    return t.sec + t.nsec / 1e9
end

-- it is expected that the plugin is loaded on startup
local last_access = now()

-- INTERFACE -------------------------------------------------------------------

local M = {}

M.instance_name = vim.fn.fnamemodify(vim.fn.getcwd(-1, -1), ':t')

vim.api.nvim_create_autocmd({ 'UIEnter', 'FocusGained' }, {
    group = vim.api.nvim_create_augroup('sigasigasiga/nvim-switch', { clear = true }),
    callback = function() last_access = now() end,
})

-- Called remotely by peers to describe this instance.
function M.get_server_info()
    local buf = vim.api.nvim_buf_get_name(0)
    return {
        protocol_version = PROTOCOL_VERSION, -- NB: bump this if the structure of the returned table changes
        pid = vim.fn.getpid(),
        cwd = vim.fn.fnamemodify(vim.fn.getcwd(-1, -1), ':~'),
        instance_name = M.instance_name,
        file = buf ~= '' and vim.fn.fnamemodify(buf, ':~:.') or '[No Name]',
        uis = #vim.api.nvim_list_uis(),
        last_access = last_access,
    }
end

--- @param bang boolean? stop the current server if no other UI is attached
function M.builtin_picker(bang)
    with_picker(builtin_picker, server_list(), bang)
end

--- @param bang boolean? stop the current server if no other UI is attached
function M.telescope_picker(bang)
    with_picker(telescope_picker, server_list(), bang)
end

--- @param bang boolean? stop the current server if no other UI is attached
function M.pick(bang)
    local picker = vim.g.loaded_telescope == 1 and telescope_picker or builtin_picker
    with_picker(picker, server_list(), bang)
end

function M.pick_recent(bang)
    with_picker(recent_picker, server_list(), bang)
end

return M
