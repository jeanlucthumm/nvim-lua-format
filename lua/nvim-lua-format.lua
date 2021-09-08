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

local function table_concat(dest, src)
    for i = 1, #src do dest[#dest + 1] = src[i] end
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

    uv.read_start(stderr, vim.schedule_wrap(function(err, data)
        assert(not err, err)
        if data then
            api.nvim_err_writeln("Error calling lua-format: " .. data)
        end
    end))

    local formatted_lines = {}
    uv.read_start(stdout, vim.schedule_wrap(function(err, data)
        assert(not err, err)
        if data then
            table_concat(formatted_lines, data:split("\n"))
        else
            api.nvim_buf_set_lines(0, 0, -1, true, formatted_lines)
        end
    end))
end

return M
