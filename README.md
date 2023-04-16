



# Neorg Templates Draft

_A very early stage implementation of template files for norg files, to show a proof of concept._

\* **This README is generated from [./README.norg](./README.norg).**


## Ideas

- Using [`LuaSnip`](https://github.com/L3MON4D3/LuaSnip) to utilize the power of snippets
- `ffmt` (file_format_nodes): enables snippet definitions in separate files.
    -  This feature is still a PR: [PR link](https://github.com/L3MON4D3/LuaSnip/pull/868)


## Installation

- [lazy.nvim](https://github.com/folke/lazy.nvim) installation
```lua
-- neorg.lua
local M = {
  "nvim-neorg/neorg",
  ft = "norg",
  dependencies = {
    { "pysan3/neorg-templates-draft", dependencies = { "L3MON4D3/LuaSnip" } }, -- ADD THIS LINE
  },
}
```


## Configuration

```lua
-- Defaults. See {*** Options} for more options
M.config = function ()
  require("neorg").setup({
    load = {
      ["external.templates"] = {
        ...
      }
    }
  })
end
```


### Options




## Usage

- `Neorg template xxx`
    - Expands snippet defined in `xxx.norg`


## Contribution

- Any PR is WELCOME!!
- Please follow code style defined in [./stylua.toml](./stylua.toml) using [StyLua](https://github.com/johnnymorganz/stylua).


## LICENSE

All files in this repository without annotation are licensed under the **GPL-3.0 license** as detailed in [LICENSE](LICENSE).

