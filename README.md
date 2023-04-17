



# Neorg Templates Draft

_A very early stage implementation of template files for norg files, to show a proof of concept._

\* **This README is generated from [./README.norg](./README.norg).**


## Ideas

- Using [`LuaSnip`](https://github.com/L3MON4D3/LuaSnip) to utilize the power of snippets
- ~~`ffmt` (file_format_nodes): enables snippet definitions in separate files.~~
    -  This feature is still a PR: [PR link](https://github.com/L3MON4D3/LuaSnip/pull/868) -> **Rejected**
    -  Implemented missing parts inside this plugin instead.


### Template norg files

So, the plugin works like this. First you create a template file like this.

`~/.config/nvim/templates/norg/journal.norg`
<sub>`\@end` is escaped cuz it ends the code block...</sub>
```norg
@document.meta
title: {TITLE}
description:
authors: {AUTHOR}
categories:
created: {TODAY}
updated: {TODAY}
version: 1.0.0
\@end

* {TITLE}
Weather: {WEATHER}
{{:{YESTERDAY}:}}[Yesterday] - {{:{TOMORROW}:}}[Tomorrow]

** Daily Review
- {CURSOR}
```

When you load this plugin, you have the command: `:Neorg templates load journal`.

This overwrites current file and substitutes current buffer with the content from template file.
This behavior can be customized. More in [Subcommands](#subcommands).


### Autofill with `LuaSnip`

But do you see the `{TITLE}` placeholder in the template file?

Yes, it automatically substitutes those placeholders **with the power of `LuaSnip`**!

And because it is a snippet, you can also use `input_node`, `choice_node` and all other useful nodes
inside your template file!
Also, I've added some useful snippets by default so you can use them out of the box!


### Demo

TODO: GIF of me loading template file with Neorg.

1. `:Neorg templates fload journal` (`force load`: Overwrite buffer without asking)
2. `TITLE, AUTHOR, TODAY...` will be automatically filled.
3. Cursor at `{WEATHER}`.
    - Choosing between options provided from `LuaSnip`'s `choice_node`.
4. Cursor ends up at `{CURSOR}` position.


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
-- See {*** Options} for more options
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

Find details here: [`module.config.public`](#luaneorgmodulesexternaltemplatesmodulelua59)


#### `templates_dir`: `str`

> Path to the directory where the template files are stored.

- Default: `vim.fn.stdpath("config") .. "/templates/norg"`
    - Most likely: `~/.config/nvim/templates/norg`
- Only looks for 1 depth.


#### `default_subcommand`: `str`

> Default action to take when only filename is provided.
>
> More details are explained in [Subcommands](#subcommands)

- Default: `add`: [Subcommands](#subcommands) - [`add`](#add)


#### `keywords`: `{KEY: <snippet_node>}`

> Define snippets to be called in placeholders.
>
> Kyes are advised to be `ALL_CAPITALIZED`.

- Examples are provided in [./lua/neorg/modules/external/templates/default_snippets.lua](#luaneorgmodulesexternaltemplatesdefaultsnippetslua)
- First argument of nodes (`pos`) should always be `1`.
    - e.g. `i(<pos>, "default text")`, `c(<pos>, { t("choice1"), t("choice2") })`
    - The order of jumping is dynamically calculated after loading the template, so you cannot specify with integer here.


#### `snippets_overwrite`: `table<any, any>`

> Overwrite any field of [./lua/neorg/modules/external/templates/default_snippets.lua](#luaneorgmodulesexternaltemplatesdefaultsnippetslua).

- You might want to change `date_format`.


## Subcommands

All command in this plugin takes the format of `:Neorg templates <subcmd> <fs_name>`.

- `<subcmd>`: Sub command. Basically defines how to load the template file.
- `<fs_name>`: Name of template file to load.
    - If you want to load `<config.templates_dir>/journal.norg`, call with `journal`.


#### `default_subcommand`: [`default_subcommand`: `str`](#defaultsubcommand-str)

If you ommit `<subcmd>` and call this plugin with `:Neorg templates <fs_name>`,
the behavior depends on this config option.

You can choose from the functions below.

Read [./lua/neorg/modules/external/templates/module.lua:78](#luaneorgmodulesexternaltemplatesmodulelua78) for more details.


### `add`

> Adds (append) template file content to the current cursor position


### `fload`

> Force-load fs_name. Overwrites content of current file and replace it with LuaSnip.


### `load`

> Load. Similar to `fload` but asks for confirmation before deleting buffer content.


## Contribution

- Any PR is WELCOME!!
- Please follow code style defined in [./stylua.toml](./stylua.toml) using [StyLua](https://github.com/johnnymorganz/stylua).


## LICENSE

All files in this repository without annotation are licensed under the **GPL-3.0 license** as detailed in [LICENSE](LICENSE).

