require("neorg.modules.base")
require("neorg.modules")
require("neorg.external.helpers")

local ext_name = "templates"
---keynames based on `ext_name`
---@param post string? # keys coming after `ext_name`
---@param pre string? # keys coming after `ext_name`
---@return string
local function plug(post, pre)
    local s = ext_name
    if pre then
        s = pre .. "." .. s
    end
    if post then
        s = s .. "." .. post
    end
    return s
end

local module = neorg.modules.create(plug(nil, "external")) ---@diagnostic disable-line
local uv = vim.loop
local log = require("neorg.external.log")
local utils = require(plug("utils", "neorg.modules.external"))
local snippet_handler = require(plug("snippet_handler", "neorg.modules.external"))

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
    keywords = {},
}

module.private = {
    templates_dir = "",
    template_files = {},
}

module.private.define_commands = function()
    local cmds = {
        definitions = {
            templates = {
                load = {},
                fload = {},
                add = {},
            },
        },
        data = {
            templates = {
                min_args = 2,
                max_args = 3,
                subcommands = {
                    load = { args = 1, name = plug("load") },
                    fload = { args = 1, name = plug("fload") },
                    add = { args = 1, name = plug("add") },
                },
            },
        },
    }
    for fs_name, _ in pairs(module.private.template_files) do
        local cmd_name = plug(fs_name)
        cmds.definitions.templates[fs_name] = {}
        cmds.data.templates.subcommands[fs_name] = { args = 0, name = cmd_name }
        module.events.subscribed["core.neorgcmd"] = {
            [cmd_name] = true,
        }
    end
    module.required["core.neorgcmd"].add_commands_from_table(cmds)
end

module.private[plug("add")] = function(fs_name) ---@diagnostic disable-line
    for name, path in pairs(module.private.template_files) do
        if fs_name == name then
            local abs_path = vim.fn.fnamemodify(path, ":p")
            local st = uv.fs_stat(abs_path)
            local file_content = ""
            if not st then
                vim.notify(string.format([[%s does not exist.]], abs_path))
            else
                local file = io.open(abs_path, "r")
                if file then -- `file` may be `nil` when failed
                    local content = file:read("*a") -- Read the whole file
                    if content then -- content may be `nil` when failed
                        file_content = content
                    end
                end
            end
            return snippet_handler.load_template_at_curpos(file_content)
        end
    end
end

module.private[plug("fload")] = function(fs_name) ---@diagnostic disable-line
    vim.cmd("normal! VggGd") -- delete content inside file
    return module.private[plug("add")](fs_name)
end

module.private[plug("load")] = function(fs_name) ---@diagnostic disable-line
    local help = "(use `:Neorg templates add xxx` to append template file)"
    local msg = "Current buffer has contents. Delete? " .. help
    if utils.buffer_has_contents(0) and not utils.confirm(msg) then
        return
    end
    return module.private[plug("fload")](fs_name)
end

---First function to be loaded
module.load = function()
    -- Find templates
    module.private.templates_dir = vim.fn.fnamemodify(module.config.public.templates_dir, ":p")
    vim.notify([[Loading templates from: ]] .. module.private.templates_dir) -- debug
    if not utils.fs_exists(module.private.templates_dir) then
        log.warn([[templates_dir does not exist: ]] .. module.private.templates_dir)
    end
    for _, path in ipairs(utils.list_template_files(module.private.templates_dir)) do
        local fs_name = utils.fs_name(path)
        module.private.template_files[fs_name] = path
    end
    vim.notify("Template files found: " .. vim.inspect(module.private.template_files)) -- debug
    module.private.define_commands()

    -- Append keywords
    snippet_handler.add_keywords(module.config.public.keywords or {})
    vim.notify(vim.inspect(vim.tbl_keys(snippet_handler.keywords)))
end

module.on_event = function(event)
    if vim.tbl_contains({ "core.keybinds", "core.neorgcmd" }, event.split_type[1]) then
        if module.private[plug(event.split_type[2])] ~= nil then
            return module.private[plug(event.split_type[2])](event.content[1])
        end
        return module.private[plug("add")](event.split_type[2])
    end
end

return module
