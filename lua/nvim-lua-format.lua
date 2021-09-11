local api = vim.api
local uv = vim.loop
local fn = vim.fn

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

local function convert_opt_to_args(opt)
    local args = {}
    for k, v in pairs(opt) do
        local arg = k:gsub("_", "-")

        -- Boolean options have [no]arg prefix in CLI
        if type(v) == "boolean" then
            if not v then arg = "no-" .. arg end
            table.insert(args, "--" .. arg)
        else
            table.insert(args, "--" .. arg)
            table.insert(args, tostring(v))
        end
    end
    return args
end

local M = {}

function M.setup(opt) M.opt = opt.options end

function M.format(opt, config_file)
    -- Find defaults for parameters
    if not opt then opt = M.opt end
    if not config_file then config_file = fn.findfile(".lua-format", ".;") end

    local name = api.nvim_buf_get_name(0) -- full path
    local stdout = uv.new_pipe()
    local stderr = uv.new_pipe()

    -- Pass the correct style options
    local args = {name}
    if config_file and config_file ~= "" then
        table_concat(args, {"-c", config_file})
    elseif opt then
        table_concat(args, convert_opt_to_args(opt))
    end

    local function done()
        stdout:close()
        stderr:close()
    end
    local handle = uv.spawn("lua-format",
                            {args = args, stdio = {nil, stdout, stderr}}, done)

    uv.read_start(stderr, vim.schedule_wrap(function(err, data)
        assert(not err, err)
        if data then
            api.nvim_err_writeln("Error calling lua-format: " .. data)
        end
    end))

    -- TODO this deletes the entire buffer on error
    -- Store stdout as it streams in and rewrite buf once its done
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
