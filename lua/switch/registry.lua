local pid = vim.fn.getpid()
local dir = vim.fs.joinpath(vim.fn.stdpath('state'), 'switch')

local function make_entry_path(p)
    return vim.fs.joinpath(dir, tostring(p))
end

local function is_alive(p)
    return vim.uv.kill(p, 0) == 0
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

    return ok2 and info or nil
end

-- INTERFACE -------------------------------------------------------------------

local M = {}

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

--- @return {pid: integer, addr: string, cwd: string, instance_name: string, file: string, uis: integer}[]
function M.list()
    local res = {}
    for name, type in vim.fs.dir(dir) do
        local p = tonumber(name)
        if type == 'file' and p and p ~= pid then
            local path = make_entry_path(p)
            -- Yes, that's a TOCTOU. Is it really a problem? I don't think so
            local addr = is_alive(p) and (vim.fn.readfile(path)[1] or '') or ''
            local info = addr ~= '' and query_server(addr)

            if info then
                table.insert(res, vim.tbl_extend('force', info, { pid = p, addr = addr }))
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

return M
