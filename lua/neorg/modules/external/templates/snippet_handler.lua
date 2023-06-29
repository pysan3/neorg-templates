---@diagnostic disable
-- stylua: ignore start
local ls = require("luasnip")
local s = ls.snippet
local sn = ls.snippet_node
local d = ls.dynamic_node
local t = ls.text_node
local fmt = require("luasnip.extras.fmt").fmt
local rep = require("luasnip.extras").rep
-- stylua: ignore end
---@diagnostic enable

M = {
    keywords = {}, -- will be updated with M.add_keywords
    magic_keywords = {},
}

---append user defined aliases to snippets
---@param kwds table<string, any> # { TITLE = i(1) }
M.add_keywords = function(kwds)
    M.keywords = vim.tbl_extend("force", M.keywords, kwds)
end

---from `CURSOR` to `{CURSOR}`
---@param key string # name of key
---@return string # "{<key>}"
M.key2entry = function(key)
    return "{" .. key .. "}"
end

---search keywords inside `content` and index the order
---@param content string # whole content of file
---@return table<string, integer> # { TITLE = 1 } index of order appearing in content, starting from 1
M.search_keywords = function(content)
    local kwds_tuple, kwds_ids = {}, {}
    local content_len = string.len(content)
    for key, _ in pairs(M.keywords) do
        if not kwds_ids[key] then
            local priority = string.find(content, M.key2entry(key))
            kwds_tuple[#kwds_tuple + 1] = { key, priority or content_len }
            kwds_ids[key] = priority
        end
    end
    table.sort(kwds_tuple, function(a, b)
        return a[2] < b[2]
    end)
    local max_idx = 0
    for idx, tuple in ipairs(kwds_tuple) do
        local key = tuple[1]
        if kwds_ids[key] then
            kwds_ids[key] = idx
            max_idx = idx
        else
            break
        end
    end
    kwds_ids._neorg_templates_max_idx = max_idx
    return kwds_ids
end

---create snippet_node with the appropriate index and a deepcopy to user defined snippets
---@param kwds_ids table<string, integer> # result from M.search_keywords or M.text_nodes
---@return table<string, any> # keyword and snippet_node with appropriate index as value
M.build_keywords = function(kwds_ids)
    local result = vim.deepcopy(M.magic_keywords)
    local max_idx = kwds_ids._neorg_templates_max_idx + 1
    kwds_ids._neorg_templates_max_idx = nil
    for key, _ in pairs(kwds_ids) do
        local node = M.keywords[key]
        if result[key] then
            -- do not overwrite existing keys (magic keywords)
        elseif not node then
            result[key] = sn(max_idx, t(M.key2entry(key)))
            max_idx = max_idx + 1
        elseif type(node) == "function" then
            result[key] = sn(kwds_ids[key], node(kwds_ids))
        else -- `node` is a snippet node. i.e. table
            result[key] = sn(kwds_ids[key], vim.deepcopy(node))
        end
    end
    return result
end

---search all keywords wrapped in `{xxx}` to workaround URLs
---@param content string # whole content of file
---@return table<string, integer> # { TITLE = 1 } index of order appearing in content, starting from 1
M.text_nodes = function(content)
    local result = {}
    for match in string.gmatch(content, [[{(..-)}]]) do
        result[match] = 0
    end
    return result
end

---rename duplicate entries of keywords to `rep`
---@param content string # whole content of file
---@param kwds_ids table<string, integer> # output of `M.search_keywords`
---@param keywords table<string, any> # output of `M.build_keywords` (any = snippet_node)
---@param snip_name string # unique string that identifies the snippet
---@return string # new_content after renaming duplicates
M.handle_duplicate_fields = function(content, kwds_ids, keywords, snip_name)
    for key, id in pairs(kwds_ids) do
        local counter = 0
        content = string.gsub(content, string.gsub(M.key2entry(key), "%p", "%%%1"), function(match)
            counter = counter + 1
            if counter == 1 then
                return match
            end
            local new_key = string.format([[%s.repeat_node.%s]], key, counter) .. snip_name
            keywords[new_key] = rep(id)
            return M.key2entry(new_key)
        end)
    end
    return content
end

---accumulate content and snippets and create a `fmt` node
---@param content string # whole content of file
---@param snip_name string # unique string that identifies the snippet
---@return any # new snippet object
M.create_snippet = function(content, snip_name)
    local dscr = "Created by norg_snippet_handler: " .. snip_name
    local kwds_ids = vim.tbl_extend("force", M.text_nodes(content), M.search_keywords(content))
    local keywords = M.build_keywords(kwds_ids)
    local new_content = M.handle_duplicate_fields(content, kwds_ids, keywords, snip_name)
    return s({ trig = snip_name, name = snip_name, dscr = dscr }, fmt(new_content, keywords, { strict = false }))
end

---create new snippet based on `content` and `fs_name` and register to luasnip
---@param content string # whole content of file
---@param fs_name string # unique name of template file
---@param add_opts table # options passed to `ls.add_snippets`
---@return any # snippet object generated by luasnip
M.add_snippet_to_luasnip = function(content, fs_name, add_opts)
    local ft = "norg"
    local file = "norg_snippet_handler." .. fs_name .. ".norg"
    local type = "snippets"
    local snip_name = "__snippets_" .. file
    -- add temporary snippet
    ls.add_snippets(
        ft,
        { M.create_snippet(content, snip_name) },
        vim.tbl_extend("keep", {
            type = type,
            key = snip_name,
            refresh_notify = true,
        }, add_opts or {})
    )
    -- get new snippet object
    local snippet_list = ls.get_snippets(ft, type)
    for i = #snippet_list, 1, -1 do -- reverse list to find the latest
        if snippet_list[i].name == snip_name then
            return snippet_list[i]
        end
    end
end

---find `{METADATA}` keyword and substitute with output from `core.norg.esupports.metagen`
---@param content string # whole content of file
---@return string, string? # [new_content, metagen subcmd]: metagen subcmd will be nil if `{METADATA}` is not found
M.extract_metadata = function(content)
    if vim.startswith(content, "{METADATA}") then
        return string.sub(content, string.len("{METADATA}") + 1), ""
    elseif vim.startswith(content, "{METADATA:") then
        for w in string.gmatch(content, [[:([%w%-_.]+)}]]) do
            return string.sub(content, string.len("{METADATA:") + string.len(w) + 2), w
        end
    end
    return content, nil
end

---create and expand the snippet at current cursor position
---@param content string # whole content of file
---@param fs_name string # unique name of template file
M.load_template_at_curpos = function(content, fs_name)
    local new_content, metagen_subcmd = M.extract_metadata(content)
    local snip = M.add_snippet_to_luasnip(new_content, fs_name, {})
    if metagen_subcmd then
        vim.cmd([[Neorg inject-metadata ]] .. metagen_subcmd)
    end
    vim.cmd.startinsert()
    vim.schedule(function()
        ls.snip_expand(snip, {})
    end)
end

return M
