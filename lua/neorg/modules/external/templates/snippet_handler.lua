---@diagnostic disable
-- stylua: ignore start
local ls = require("luasnip")
local s = ls.snippet
local sn = ls.snippet_node
local isn = ls.indent_snippet_node
local t = ls.text_node
local i = ls.insert_node
local f = ls.function_node
local c = ls.choice_node
local d = ls.dynamic_node
local r = ls.restore_node
local events = require("luasnip.util.events")
local ai = require("luasnip.nodes.absolute_indexer")
local fmt = require("luasnip.extras.fmt").fmt
local rep = require("luasnip.extras").rep
local m = require("luasnip.extras").m
local lambda = require("luasnip.extras").l
local postfix = require("luasnip.extras.postfix").postfix

local snippets, autosnippets = {}, {}
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

local M = {
    date_format = [[%Y-%m-%d]],
    time_format = [[%H:%M]],
    url_lookup = {
        ["www.youtube.com"] = "YouTube",
        ["youtu.be"] = "YouTube",
    },
}

M.parse_date = function(delta_date, str)
    local year, month, day = string.match(str, [[^(%d%d%d%d)-(%d%d)-(%d%d)$]])
    return os.date(M.date_format, os.time({ year = year, month = month, day = day }) + 86400 * delta_date)
end

M.current_date_f = function(delta_day)
    return function()
        return os.date(M.date_format, os.time() + 86400 * delta_day)
    end
end

M.file_title = function()
    return vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":t:r")
end

---Parse url and return service name based on domain
---@param link string # url in shape of http(s)://domain.name/xxx
---@return string # Name of service
M.link_type = function(link)
    local domain = string.gsub(link, [[http.://([^/]-)/.*]], "%1")
    vim.notify(string.format(
        [[
URL: %s
-> Domain: %s
-> Lookup: %s
  ]],
        link,
        domain,
        M.url_lookup[domain]
    ))
    return M.url_lookup[domain] or domain
end

M.default_keywords = {
    TITLE = f(M.file_title),
    TODAY = f(M.current_date_f(0)),
    TOMORROW = f(M.current_date_f(1)),
    YESTERDAY = f(M.current_date_f(-1)),
    AUTHOR = f(require("neorg.external.helpers").get_username),
    URL_TAG = fmt([[#{url_type} {{{url}}}]], {
        url = i(1, "url"),
        url_type = f(function(args, _)
            return M.link_type(args[1][1]):lower()
        end, { 1 }),
    }),
}

M.keywords = {} -- will be updated with M.add_keywords

M.add_keywords = function(kwds)
    M.keywords = vim.tbl_extend("force", M.default_keywords, M.keywords, kwds)
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
    return s(e(snip_name, snip_name, dscr), fmt(content, keywords, { strict = false }))
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
