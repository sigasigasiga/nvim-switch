local M = {}

local dir = vim.fs.joinpath(vim.fn.stdpath('state'), 'switch')
local pid = vim.fn.getpid()

local function make_entry_path(p)
    return vim.fs.joinpath(dir, tostring(p))
end

local function is_alive(p)
    return vim.uv.kill(p, 0) == 0
end

local function query(addr)
    local ok, chan = pcall(
        vim.fn.sockconnect,
        addr:match('^[^/\\]+:%d+$') and 'tcp' or 'pipe',
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
        'return require("switch").get_server_info()',
        {}
    )

    pcall(vim.fn.chanclose, chan)

    return ok2 and info or nil
end

local function default_picker(items, bang)
    assert(#items ~= 0)

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
                vim.cmd.connect { choice.addr, bang = bang }
            end
        end
    )
end

local function telescope_picker(items, bang)
    assert(#items ~= 0)

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
                        vim.cmd.connect { entry.value.addr, bang = bang }
                    end
                end)
                return true
            end,
        }
    )

    picker:find()
end

local function with_picker(picker, items, bang)
    if #items == 0 then
        vim.notify('switch: no other instances found', vim.log.levels.WARN)
        return
    end

    picker(items, bang)
end

-- INTERFACE -------------------------------------------------------------------

M.instance_name = vim.fn.fnamemodify(vim.fn.getcwd(-1, -1), ':t')

function M.register()
    if vim.v.servername == '' then
        vim.fn.serverstart()
    end

    vim.fn.mkdir(dir, 'p')
    vim.fn.writefile({ vim.v.servername }, make_entry_path(pid))
end

function M.unregister()
    vim.uv.fs_unlink(make_entry_path(pid))
end

-- Called remotely by peers to describe this instance.
function M.get_server_info()
    local buf = vim.api.nvim_buf_get_name(0)
    return {
        cwd = vim.fn.fnamemodify(vim.fn.getcwd(-1, -1), ':~'),
        instance_name = M.instance_name,
        file = buf ~= '' and vim.fn.fnamemodify(buf, ':~:.') or '[No Name]',
        uis = #vim.api.nvim_list_uis(),
    }
end

--- @return {pid: integer, addr: string, cwd: string, instance_name: string, file: string, uis: integer}[]
function M.list()
    local res = {}
    for name, type in vim.fs.dir(dir) do
        local p = tonumber(name)
        if type == 'file' and p and p ~= pid then
            local path = make_entry_path(p)
            local addr = is_alive(p) and (vim.fn.readfile(path)[1] or '') or ''
            local info = addr ~= '' and query(addr)
            if info then
                res[#res + 1] = vim.tbl_extend('force', info, { pid = p, addr = addr })
            else
                vim.uv.fs_unlink(path)
            end
        end
    end
    table.sort(res, function(a, b)
        return a.pid < b.pid
    end)
    return res
end

--- @param bang boolean? stop the current server if no other UI is attached
function M.default_picker(bang)
    with_picker(default_picker, M.list(), bang)
end

--- @param bang boolean? stop the current server if no other UI is attached
function M.telescope_picker(bang)
    with_picker(telescope_picker, M.list(), bang)
end

--- @param bang boolean? stop the current server if no other UI is attached
function M.pick(bang)
    local picker = vim.g.loaded_telescope == 1 and telescope_picker or default_picker
    with_picker(picker, M.list(), bang)
end

return M
