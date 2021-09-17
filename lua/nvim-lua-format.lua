local api = vim.api
local uv = vim.loop
local fn = vim.fn

-- Split a string on every instance of |delimiter|, returning a list
function string:split(delimiter)
    local result = {}
    local from = 1
    local delim_from, delim_to = string.find(self, delimiter, from)
    while delim_from do
        table.insert(result, string.sub(self, from, delim_from - 1))
        from = delim_to + 1
        delim_from, delim_to = string.find(self, delimiter, from)
    end
    local last = string.sub(self, from)
    if last ~= "" then table.insert(result, string.sub(self, from)) end
    return result
end

-- Append all entries in |src| to |dest|, maintaining indices
local function table_concat(dest, src)
    for i = 1, #src do dest[#dest + 1] = src[i] end
end

-- Convert a table of formatting options to flags that LuaFormatter
-- can understand
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

-- Specialized |table_concat| that lets you combine the last line of |accum|
-- and first line of |new| before concatenating. This helps with accumulating
-- lines as stdout from LuaFormatter streams in, since a received data chunk
-- could end in the middle of a line
local function merge_lines(accum, new, fuse_border)
    if fuse_border and #accum > 0 and #new > 0 then
        new[1] = accum[#accum] .. new[1]
        accum[#accum] = nil
    end
    table_concat(accum, new)
end

-- Usually the first line is enough context to figure out what's going on. 
-- In the case of syntax errors, there are better sources of truth than
-- stdout from LuaFormatter, like an LSP, so we don't bother showing more.
local function parse_stderr(data)
    local first_line = data:split("\n")[1]
    api.nvim_err_writeln("Error calling lua-format: " ..
                             (first_line or "unknown"))
end

local M = {}

-- See doc/nvim-lua-format.txt
local default_opt = {
    use_local_config = true,
    save_if_unsaved = false,
    default = {}
}

-- See doc/nvim-lua-format.txt
function M.setup(opt)
    M.opt = vim.tbl_deep_extend("force", default_opt, opt or {})
    M.configured = true
end

-- See doc/nvim-lua-format.txt
function M.format(opt, config_file)
    if not M.configured then
        api.nvim_err_writeln("Please call require\"nvim-lua-format\".setup()")
        return nil
    end

    -- Find defaults for parameters
    if not opt then opt = M.default end
    if not config_file and M.opt.use_local_config then
        config_file = fn.findfile(".lua-format", ".;")
    end

    -- Handle unsaved buffers
    if vim.opt.modified:get() then
        if M.opt.save_if_unsaved then
            vim.cmd("write")
        else
            api.nvim_err_writeln(
                "Cannot format unsaved buffer. Set |save_if_unsaved| in config to automatically save")
            return nil
        end
    end

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

    local code
    local handle
    local function done(c, _)
        stdout:close()
        stderr:close()
        handle:close()
        code = c
    end
    handle = uv.spawn("lua-format",
                      {args = args, stdio = {nil, stdout, stderr}}, done)

    uv.read_start(stderr, vim.schedule_wrap(function(err, data)
        assert(not err, err)
        if data then parse_stderr(data) end
    end))

    -- Store stdout as it streams in and rewrite buf once its done
    local formatted_lines = {}
    local had_newline = false;
    uv.read_start(stdout, vim.schedule_wrap(function(err, data)
        assert(not err, err)
        if data then
            merge_lines(formatted_lines, data:split("\n"), not had_newline)
            had_newline = (data:sub(-1) == "\n")
        else
            if code == 0 then
                api.nvim_buf_set_lines(0, 0, -1, true, formatted_lines)
            end
        end
    end))
end

return M
