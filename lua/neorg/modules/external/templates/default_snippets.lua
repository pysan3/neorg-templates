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
local neorg = require("neorg.core")
local utils = neorg.utils

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
    magic_keywords = {
        CURSOR = i(0),
        METADATA = t("Error processing {METADATA}. This should be at the first line of template file."),
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
    TITLE_INPUT = function()
        return i(1, M.file_title())
    end,
    INSERT = function()
        return i(1)
    end,
    TODAY = f(M.current_date_f(0)),
    TOMORROW = f(M.current_date_f(1)),
    YESTERDAY = f(M.current_date_f(-1)),
    WEATHER = c(1, { t("Sunny "), t("Cloudy "), t("Rainy ") }),
    AUTHOR = f(utils.get_username),
    URL_TAG = fmt([[#{url_type} {{{url}}}]], {
        url = i(1, "url"),
        url_type = f(function(args, _)
            return M.link_type(args[1][1]):lower()
        end, { 1 }),
    }),
}

return M
