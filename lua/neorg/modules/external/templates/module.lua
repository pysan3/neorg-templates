local ext_name = "templates"
local neorg = require("neorg.core")

---Concat table of strings
---@param s_tbl string | string[] # table of strings, if it is a simple string, treats as `{ s_tbl }`
---@param separator string? # separator, defaults to `"."`
---@param sep_at_front boolean? # whether to add separator at front
---@param sep_at_end boolean? # whether to add separator at end
---@return string
local function join(s_tbl, separator, sep_at_front, sep_at_end)
    ---@type string[]
    local tbl = type(s_tbl) == "string" and { s_tbl } or s_tbl or {} ---@diagnostic disable-line
    local sep = #tbl > 0 and (separator or ".") or ""
    return (sep_at_front and sep or "") .. table.concat(tbl, sep) .. (sep_at_end and sep or "")
end

---keynames based on `ext_name`
---@param post string | string[] | nil # keys coming after `ext_name`
---@param pre string | string[] | nil # keys coming after `ext_name`
---@return string
local function plug(post, pre)
    return join(pre or {}, ".", false, true) .. ext_name .. join(post or {}, ".", true, false)
end
---keynames based on `ext_name`
---@param s string # string containing `ext_name`
---@return string[], string[] # `pre` and `post`
local function deplug(s)
    local splits = vim.split(s, ".", { plain = true, trimempty = true })
    for i, split in ipairs(splits) do
        if split == ext_name then
            return { unpack(splits, 1, i - 1) }, { unpack(splits, i + 1) }
        end
    end
    return {}, splits
end

local module = neorg.modules.create(plug(nil, "external")) ---@diagnostic disable-line
local uv = vim.loop
local log = require("neorg.external.log")
local utils = require("neorg.modules.external.templates.utils")
local snippet_handler = require("neorg.modules.external.templates.snippet_handler")
local default_snippets = require("neorg.modules.external.templates.default_snippets")

module.setup = function()
    return {
        success = true,
        requires = {
            -- "core.norg.dirman",
            "core.keybinds",
            "core.neorgcmd",
            -- "core.mode",
        },
    }
end

module.config.public = {
    templates_dir = vim.fn.stdpath("config") .. "/templates/norg",
    default_subcommand = "add",
    keywords = {},
    snippets_overwrite = {
        date_format = [[%Y-%m-%d]],
        time_format = [[%H:%M]],
        url_lookup = {
            ["www.youtube.com"] = "YouTube",
            ["youtu.be"] = "YouTube",
        },
    },
}

module.private = {
    template_files = {},
}

---@type { [string]: fun(fs_name: string) } # function takes `fs_name` which is the name of template file
-- `fs_name = journal` will load (<module.config.public.templates_dir>/<fs_name>.norg) and load with LuaSnip
module.private.subcommands = {}

---Add (append) template file content to the current cursor position
module.private.subcommands.add = function(fs_name)
    for name, path_abs in pairs(module.private.template_files) do
        if fs_name == name then
            local st = uv.fs_stat(path_abs)
            local file_content = ""
            if not st then
                vim.notify(string.format([[%s does not exist.]], path_abs))
            else
                local file = io.open(path_abs, "r")
                if file then -- `file` may be `nil` when failed
                    local content = file:read("*a") -- Read the whole file
                    if content then -- content may be `nil` when failed
                        file_content = content
                    end
                end
            end
            return snippet_handler.load_template_at_curpos(file_content, fs_name)
        end
    end
    -- no template file with `fs_name` found
    log.warn("Aborting. No template file found: " .. fs_name)
end

---Force-load fs_name. Will overwrite content of current file and replace it with LuaSnip
module.private.subcommands.fload = function(fs_name)
    vim.cmd("normal! ggVGd") -- delete content inside file
    return module.private.subcommands.add(fs_name)
end

---Load. Similar to `fload` but asks for confirmation before deleting buffer content
module.private.subcommands.load = function(fs_name)
    local help = "(use `:Neorg templates add xxx` to append template file)"
    local msg = "Current buffer has contents. Delete? " .. help
    if utils.buffer_has_contents(0) and not utils.confirm(msg, false) then
        return
    end
    return module.private.subcommands.fload(fs_name)
end

---Looks at `module.private.commands` and files inside `module.config.public.templates_dir` to create the subcommands
---This dynamically creates the completion options after `:Neorg templates <subcommand> <fs_name>`
module.private.define_commands = function()
    local subscribed_neorgcmd = {}
    local cmds = { templates = { args = 3, subcommands = {} } }
    for fs_name, _ in pairs(module.private.template_files) do
        local cmd_name = plug(fs_name)
        subscribed_neorgcmd[cmd_name] = true
        cmds.templates.subcommands[fs_name] = { args = 0, name = cmd_name }
        for command_name, _ in pairs(module.private.subcommands) do
            if not cmds.templates.subcommands[command_name] then
                cmds.templates.subcommands[command_name] = { args = 1, subcommands = {}, name = plug(command_name) }
            end
            cmds.templates.subcommands[command_name].subcommands[fs_name] =
                { args = 0, name = plug({ command_name, fs_name }) }
            subscribed_neorgcmd[plug({ command_name, fs_name })] = true
        end
    end
    module.required["core.neorgcmd"].add_commands_from_table(cmds)
    module.events.subscribed = { ["core.neorgcmd"] = subscribed_neorgcmd }
end

---First function to be loaded
module.load = function()
    -- Find templates
    if type(module.config.public.templates_dir) ~= "table" then
        ---@type string[]
        module.config.public.templates_dir = { module.config.public.templates_dir } ---@diagnostic disable-line
    end
    for _, dir in ipairs(module.config.public.templates_dir) do
        local dir_abs = vim.fn.fnamemodify(dir, ":p")
        log.debug([[Loading templates from: ]] .. dir_abs)
        if not utils.fs_exists(dir_abs) then
            log.warn([[templates_dir does not exist: ]] .. dir_abs)
        else
            for _, path in ipairs(utils.list_template_files(dir_abs)) do
                local path_abs = dir_abs .. "/" .. path
                local fs_name = utils.fs_name(path_abs)
                if module.private.template_files[fs_name] ~= nil then
                    log.warn(
                        string.format(
                            [[Found multiple template files with same name: %s, %s. Ignoring previous.]],
                            module.private.template_files[fs_name],
                            path_abs
                        )
                    )
                end
                module.private.template_files[fs_name] = path_abs
            end
        end
    end
    log.debug("Template files found: " .. vim.inspect(module.private.template_files))
    module.private.define_commands()

    -- Check `module.config.public.default_subcommand` is valid
    if not vim.tbl_contains(vim.tbl_keys(module.private.subcommands), module.config.public.default_subcommand) then
        log.warn(
            [[`config.default_subcommand` is not a valid value: ]]
                .. module.config.public.default_subcommand
                .. string.format(
                    [[ Should be one of: %s. Defaulting to `add`]],
                    vim.tbl_keys(module.private.subcommands)
                )
        )
        module.config.public.default_subcommand = "add"
    end

    -- Add user defined snippets and append keywords
    default_snippets = vim.tbl_deep_extend("force", default_snippets, module.config.public.snippets_overwrite)
    snippet_handler.add_keywords(default_snippets.default_keywords)
    snippet_handler.add_keywords(module.config.public.keywords or {})
    snippet_handler.magic_keywords = default_snippets.magic_keywords
end

module.on_event = function(event)
    if vim.tbl_contains({ "core.keybinds", "core.neorgcmd" }, event.split_type[1]) then
        local _, post = deplug(event.split_type[2])
        local func, fs_name = unpack(post)
        if module.private.subcommands[func] ~= nil then
            return module.private.subcommands[func](fs_name)
        end
        -- Directry specify fs_name. (:Neorg templates fs_name) -> (:Neorg templates add fs_name)
        return module.private.subcommands[module.config.public.default_subcommand](func)
    end
end

return module
