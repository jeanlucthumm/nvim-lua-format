local api = vim.api
local uv = vim.loop

function string:split(delimiter)
    local result = {}
    local from = 1
    local delim_from, delim_to = string.find(self, delimiter, from)
    while delim_from do
        table.insert(result, string.sub(self, from, delim_from - 1))
        from = delim_to + 1
        delim_from, delim_to = string.find(self, delimiter, from)
    end
    table.insert(result, string.sub(self, from))
    return result
end

local M = {}

function M.setup(opt) print("Completed setup") end

function M.format()
    local name = api.nvim_buf_get_name(0)

    local stdout = uv.new_pipe()
    local stderr = uv.new_pipe()

    local function done()
        stdout:close()
        stderr:close()
    end
    local handle = uv.spawn("lua-format",
                            {args = {name}, stdio = {nil, stdout, stderr}}, done)

    local buf = api.nvim_create_buf(true, false)
    if buf == 0 then
        api.nvim_err_writeln("Failed to create temporary buffer")
        return
    end
    api.nvim_buf_set_name(buf, "TEMP")

    uv.read_start(stderr, vim.schedule_wrap(function(err, data)
        assert(not err, err)
        if data then
            api.nvim_err_writeln("Error calling lua-format: " .. data)
        end
    end))

    uv.read_start(stdout, vim.schedule_wrap(function(err, data)
        assert(not err, err)
        if data then
            api.nvim_buf_set_lines(buf, -2, -1, false,
                                   ("stdout chunk " .. data):split("\n"))
        else
            print("stdout end")
        end
    end))
end

return M
