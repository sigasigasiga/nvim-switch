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
function M.pick(bang)
    local items = M.list()
    if #items == 0 then
        vim.notify('switch: no other instances found', vim.log.levels.WARN)
        return
    end

    vim.ui.select(
        items,
        {
            prompt = ('Switch to:\n%8s %16s %16s %24s %8s'):format('PID', 'Name', 'CWD', 'Open file', 'UI'),
            format_item = function(i)
                local ui_str = i.uis > 0 and ('  [%d UI]'):format(i.uis) or ''
                return ('%-8d %-16s %-16s  %s%s'):format(i.pid, i.instance_name, i.cwd, i.file, ui_str)
            end,
        },
        function(choice)
            if choice then
                vim.cmd.connect { choice.addr, bang = bang }
            end
        end
    )
end

return M
