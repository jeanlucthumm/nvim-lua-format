# nvim-lua-format

A formatter plugin for Lua files written in Lua. Asynchronously calls 
LuaFormatter and directly modifies current buffer. See **Configuration**
for configuration options including default styling options.

## Installation

Use your favorite plugin manager:

```
jeanlucthumm/nvim-lua-format
```

## Quickstart

Call the `nvim-lua-format.setup()` function in your startup file (e.g.
init.lua or init.vim):

```lua
    require"nvim-lua-format".setup {
        -- TODO: Set options here, if any
    }
```

Decide how you would like to call |nvim-lua-format.format()|:

```lua
    -- Lua style keybding:
    vim.api.nvim_set_keymap(
        "n", "<F5>, "<Cmd>lua require'nvim-lua-format'.format()<CR>")

    -- Vim style keybinding:
    nmap <F5> :lua require'nvim-lua-format'.format()<CR>

    -- Setting up a command:
    vim.cmd("command! -nargs=0 Format lua require'nvim-lua-format'.format()")
```

## Configuration

The default configuration options are as follows: 

```lua
    require"nvim-lua-format".setup {
        -- Scans current directory and up for .lua-format file and passes it
        -- to LuaFormatter. This will override any options set in |default|.
        use_local_config = true,

        -- Whether to automatically save an unsaved buffer when formatting.
        -- If false, formatting will print error.
        save_if_unsaved = false,

        -- Default style flags to pass to LuaFormatter. See its documentation
        -- for all options.
        default = {
            column_width = 80,
            indent_width = 4,
            use_tab = true,
            column_table_limit = "column_limit",
            -- ...
        }
    }
```

LuaFormatter style flags doc: [link](https://github.com/Koihik/LuaFormatter#default-configuration)

## API Reference

```vimhelp
setup({config})                                       *nvim-lua-format.setup()*
                Initializes the plugin. Must be called.

                Parameters: ~
                    {config}    Configuration described in
                                |nvim-lua-format-config|

format({flags}, {file})                              *nvim-lua-format.format()*
                Formats the current buffer.

                Parameters: ~
                    {flags} (optional) Table of style flags to pass to
                            LuaFormatter. If nil, then the `default`
                            table from |nvim-lua-format-config| is used.
                    {file}  (optional) Path to a `.lua-format` file to use.
                            This will override {flags}, any local
                            `.lua-format`, and any default config.
```
