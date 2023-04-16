local M = {}
local uv = vim.loop

---Check if path exists in filesystem
---@param path string # path to check
---@return boolean # true if path exists
M.fs_exists = function(path)
    local st = uv.fs_stat(path)
    return st and true or false
end
---fs_name: return file stem as a name
-- fs_name("foo/bar.norg") -> "bar"
---@param path string # path
---@return string # name of file, i.e. file stem
M.fs_name = function(path)
    return vim.fn.fnamemodify(path, ":p:t:r")
end

---Checks whether path's extension is `norg`
---@param path string # path to file to check
---@param check_exists boolean? # whether to first check if the file exists
---@return boolean # `true` if file's extension is `norg`, `false` also when file does not exist
M.is_norg_file = function(path, check_exists)
    if check_exists and not M.fs_exists(path) then
        return false
    end
    return vim.fn.fnamemodify(path, ":e") == "norg"
end

M.buffer_has_contents = function(bufid)
    for _, line in ipairs(vim.api.nvim_buf_get_lines(bufid, 0, -1, false)) do
        if string.len(line or "") > 0 then
            return true
        end
    end
    return false
end

---confirm: asks for a confirmation in cmd
---@param msg string: confirm message asking yes / no
---@param default boolean: return value if <CR> was pressed without any letter
---@return boolean:
M.confirm = function(msg, default)
    local yes = default and "YES" or "yes"
    local no = default and "no" or "NO"
    local answer = vim.fn.confirm(msg, string.format("&%s\n&%s", yes, no), default and 1 or 2)
    if answer == 0 then
        return M.confirm(msg .. " Press `y` or `n`.", default)
    end
    return answer == 1
end

---Iterate files inside `dir` and return files with `.norg` extension
---@param dir string # path to templates_dir
---@return string[] # List of paths
M.list_template_files = function(dir)
    local hdl = uv.fs_scandir(dir)
    local files = {}
    if hdl then
        while true do
            local name, _ = uv.fs_scandir_next(hdl)
            if not name then
                break
            end
            if M.is_norg_file(name, false) then
                files[#files + 1] = name
            end
        end
    end
    return files
end

return M
