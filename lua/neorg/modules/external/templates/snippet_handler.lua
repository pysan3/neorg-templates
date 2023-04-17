---@diagnostic disable
-- stylua: ignore start
local ls = require("luasnip")
local s = ls.snippet
local sn = ls.snippet_node
local i = ls.insert_node
local d = ls.dynamic_node
local fmt = require("luasnip.extras.fmt").fmt
local e = function(trig, name, dscr, wordTrig, regTrig, docstring, docTrig, hidden, priority)
  local ret = { trig = trig, name = name, dscr = dscr }
  if wordTrig ~= nil then ret["wordTrig"] = wordTrig end
  if regTrig ~= nil then ret["regTrig"] = regTrig end
  if docstring ~= nil then ret["docstring"] = docstring end
  if docTrig ~= nil then ret["docTrig"] = docTrig end
  if hidden ~= nil then ret["hidden"] = hidden end
  if priority ~= nil then ret["priority"] = priority end
  return ret
end
-- stylua: ignore end
---@diagnostic enable

M = {
    keywords = {}, -- will be updated with M.add_keywords
}

M.add_keywords = function(kwds)
    M.keywords = vim.tbl_extend("force", M.keywords, kwds)
end

M.search_keywords = function(content)
    local kwds_ids = { TITLE = 1 }
    for key, _ in pairs(M.keywords) do
        if not kwds_ids[key] then
            local splits = vim.split(content, key, { plain = true, trimempty = false })
            kwds_ids[key] = #splits > 1 and string.len(splits[1]) or nil
        end
    end
    return kwds_ids
end

M.build_keywords = function(kwds_ids)
    local res = { CURSOR = i(0) }
    for key, id in pairs(kwds_ids) do
        -- res[key] = d(id, function(args, parent, old_stage, user_args)
        --     return sn(1, M.keywords[key])
        -- end)
        res[key] = sn(id, { M.keywords[key] })
    end
    return res
end

M.create_snippet = function(content, snip_name)
    local dscr = "Created by norg_snippet_handler: " .. snip_name
    local kwds_ids = M.search_keywords(content)
    local keywords = M.build_keywords(kwds_ids)
    return s({ trig = snip_name, name = snip_name, dscr = dscr }, fmt(content, keywords, { strict = false }))
end

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
            -- prevent refresh here, will be done outside loop.
            refresh_notify = false,
        }, add_opts or {})
    )
    -- get new snippet object
    local snippet_list = ls.get_snippets(ft, type)
    for _, snip in ipairs(snippet_list) do
        if snip.name == snip_name then
            return snip
        end
    end
end

M.load_template_at_curpos = function(content, fs_name)
    local snip = M.add_snippet_to_luasnip(content, fs_name, {})
    vim.cmd.startinsert()
    vim.schedule(function()
        ls.snip_expand(snip, {})
    end)
end

return M
