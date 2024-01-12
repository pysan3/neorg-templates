# Neorg Templates

\* **This README is generated from [./README.norg](./README.norg).**

## Demo

![templates-demo](https://user-images.githubusercontent.com/41065736/232847417-6f7e32b8-fdd3-4464-9d67-269bb28b363c.gif)

1.  `:Neorg templates fload journal` (`fload = force load`: Overwrite
    buffer without asking)

2.  `AUTHOR, TODAY...` will be automatically filled.

3.  `{TITLE_INPUT}` is an `input_node` with `{TITLE}` being the default
    placeholder text.

- Changes the title.

1.  Cursor at `{WEATHER}`.

- Choosing between options provided from `LuaSnip`'s `choice_node`.

1.  Cursor ends up at `{CURSOR}` position.

\* `{CURSOR}` is a magic keyword, which specifies the last position of
the cursor. More about magic keywords in [Magic
Keywords](#magic-keywords).

\* You can use the same keyword in multiple places to insert the same
content. Not possible in bare `LuaSnip`.

## Usage

### Template Norg Files

So, the plugin works like this. First you create a template file with
placeholders for dynamic values.

`~/.config/nvim/templates/norg/journal.norg`

``` norg
@document.meta
title: {TITLE_INPUT}
description:
authors: {AUTHOR}
categories:
created: {TODAY}
updated: {TODAY}
version: 1.0.0
@end

* {TITLE_INPUT}
  Weather: {WEATHER}
  {{:{YESTERDAY}:}}[Yesterday] - {{:{TOMORROW}:}}[Tomorrow]

** Daily Review
   - {CURSOR}
```

When you load this plugin, you have the command:
`:Neorg templates load journal`.

This overwrites the current buffer and substitutes it with the content
the template file. This behavior can be customized. More in
[Subcommands](#subcommands).

### Autofill with `LuaSnip`

But do you see the `{AUTHOR}` placeholder in the template file?

Yes, it automatically substitutes those placeholders **with the power of
`LuaSnip`**!

And since it is a snippet, you can also use `input_node`, `choice_node`
and all other useful nodes inside your template file! I've also added
some useful snippets by default so you can use them out of the box.

## Installation

- [lazy.nvim](https://github.com/folke/lazy.nvim) installation

``` lua
-- neorg.lua
local M = {
  "nvim-neorg/neorg",
  ft = "norg",
  dependencies = {
    { "pysan3/neorg-templates", dependencies = { "L3MON4D3/LuaSnip" } }, -- ADD THIS LINE
  },
}
```

## Configuration

``` lua
-- See {*** Options} for more options
M.config = function ()
  require("neorg").setup({
    load = {
      ["external.templates"] = {
        -- templates_dir = vim.fn.stdpath("config") .. "/templates/norg",
        -- default_subcommand = "add", -- or "fload", "load"
        -- keywords = { -- Add your own keywords.
        --   EXAMPLE_KEYWORD = function ()
        --     return require("luasnip").insert_node(1, "default text blah blah")
        --   end,
        -- },
        -- snippets_overwrite = {},
      }
    }
  })
end
```

### Options

Find details here:
[`module.config.public`](./lua/neorg/modules/external/templates/module.lua:59)

#### `templates_dir`

- `string | string[]`

Path to the directories where the template files are stored.

- Default: `vim.fn.stdpath("config") .. "/templates/norg"`

  - Most likely: `~/.config/nvim/templates/norg`

- Only looks for 1 depth.

- You may also provide multiple paths to directories with a table.

  - `templates_dir = { "~/temp_dir1/", "~/temp_dir2/" }`

#### `default_subcommand`

- `string`

Default action to take when only filename is provided.

More details are explained in [Subcommands](#subcommands)

- Default: `add` [Subcommands](#subcommands) - [`add`](#add)

#### `keywords`

- `{KEY: <snippet_node>}` \| `{KEY: fun(...) -> <snippet_node>}`

Define snippets to be called in placeholders. Kyes are advised to be
`ALL_CAPITALIZED`.

- Examples are provided in
  [./lua/neorg/modules/external/templates/default_snippets.lua](./lua/neorg/modules/external/templates/default_snippets.lua)

  - Read [Builtin Snippets](#builtin-snippets) for more information.

- `KEY` should be the name of the placeholder

- Value should be a snippet node or a function that returns a snippet
  node.

  - For example `TITLE_INPUT` needs to run `M.file_title()` right before
    the expansion. Therefore, it is defined with a function.

- First argument of nodes (`pos`) should always be `1`.

  - e.g. `i(<pos>, "default text")`,
    `c(<pos>, { t("choice1"), t("choice2") })`

  - The order of jumping is dynamically calculated after loading the
    template, so you cannot specify with integer here.

#### `snippets_overwrite`

- `table<string, any>`

Overwrite any field of
[./lua/neorg/modules/external/templates/default_snippets.lua](./lua/neorg/modules/external/templates/default_snippets.lua).

- You might want to change `date_format`.

  - For more tags, see: <https://www.lua.org/pil/22.1.html>

``` lua
{
  snippets_overwrite = {
    date_format = [[%a, %d %b]] -- Wed, 1 Nov (norg date format)
  }
}
```

## Subcommands

All command in this plugin takes the format of
`:Neorg templates <subcmd> <templ_name>`.

- `<subcmd>`: Sub command. Basically defines how to load the template
  file.

- `<templ_name>`: Name of template file to load.

  - If you want to load `<config.templates_dir>/journal.norg`, call with
    `journal`.

#### `default_subcommand` Option

Read [`default_subcommand`](#defaultsubcommand) for more information. If
you ommit `<subcmd>` and call this plugin with
`:Neorg templates <templ_name>`, the behavior depends on this config
option.

You can choose from the functions below.

### `add`

Add (append) template file content to the current cursor position.

### `fload`

Force-load template file. Overwrites content of current file and replace
it with LuaSnip.

### `load`

Load. Similar to `fload` but asks for confirmation before deleting the
buffer content.

## Magic Keywords

Magic keywords take the format of `{CURSOR}`, same as a placeholder, but
has a special meaning.

### `{CURSOR}`

The cursor position when the snippet ends.

- Same as `i(0)`

- If `{CURSOR}` is not found, the cursor will be at the end of the file.

### `{METADATA}`

Placeholder for metadata. Generated by `core.norg.esupports.metagen`.

- Metadata will be simply substituted with this keyword.

- You cannot edit or control the output with this plugin.

  - Read [Neorg - Wiki -
    Metagen](https://github.com/nvim-neorg/neorg/wiki/Metagen) instead.

- This keyword **MUST BE** at the **first line** of the template file.

- In order to `:Neorg inject-metadata blog-post`, use
  `{METADATA:blog-post}`

## Tips and Tricks

### Ask for a Snippet

If you are not familiar with `LuaSnip`, post what kind of snippet you
want! Maybe someone can help you out.

Post it in the
[Discussions](https://github.com/pysan3/neorg-templates-draft/discussions)
with the category \`✂️ Ask for a Snippet \`.

### Autoload with `:Neorg journal`

> <https://github.com/nvim-neorg/neorg/issues/714#issuecomment-1551013595>

``` lua
vim.api.nvim_create_autocmd("BufNewFile", {
  command = "Neorg templates load journal",
  pattern = { neorg_dir .. "journal/*.norg" },
})
```

### Builtin Snippets

I will not list all builtin snippets but some useful ones that might
need a bit of explanation. Please read
[`default_snippets.lua`](./lua/neorg/modules/external/templates/default_snippets.lua)
for the whole list.

#### `TITLE`, `TITLE_INPUT`

Inserts the file name. `TITLE_INPUT` would be an insert node with
default text being `TITLE`.

#### `TODAY`, `YESTERDAY`, `TOMORROW` + `_OF_FILENAME`, `_OF_FILETREE`

`TODAY_OF_FILENAME` will insert the date by parsing the filename.
`OF_FILENAME` is useful when `journal.strategy == "flat"`. So, if the
filename is `2023-01-01.norg`, `YESTERDAY_OF_FILENAME => 2022-12-31`.

Similarly, `TODAY_OF_FILETREE` is useful when
`journal.strategy == "nested"`. Ex: if the filename is
`/path/to/2023/01/01.norg`, `YESTERDAY_OF_FILETREE => 2022-12-31`.

For more fine control, read [2. Build you own snippet
key.](https://github.com/pysan3/neorg-templates/discussions/15#discussioncomment-7574518)

## Useful Templates

- [pysan3](https://github.com/pysan3)

  - [Plugin
    Setup](https://github.com/pysan3/dotfiles/blob/main/nvim/lua/plugins/60-neorg.lua)

  - [Personal
    Keywords](https://github.com/pysan3/dotfiles/blob/main/nvim/lua/norg-config/templates.lua)

  - [Templates](https://github.com/pysan3/dotfiles/tree/main/nvim/templates/norg)

More examples welcome! Create a PR to update the README.

## Contribution

- Please follow code style defined in [./stylua.toml](./stylua.toml)
  using [StyLua](https://github.com/johnnymorganz/stylua).

## LICENSE

All files in this repository without annotation are licensed under the
**GPL-3.0 license** as detailed in [LICENSE](LICENSE).

## FAQs

### Q. Do you plan to support other snippet engines like Ultisnip?

No. This plugin heavily depends on luasnip and I do not have the time
and interest to support other ones.

There is an [open issue](https://github.com/nvim-neorg/neorg/issues/714)
discussing for a pure lua solution using autocmds.

There are other neovim template plugins (not just for norg) that do not
depend on luasnip. Here are some examples.

- [template.nvim](https://github.com/nvimdev/template.nvim)

- [skeleton.nvim](https://github.com/xvzc/skeleton.nvim)

- [esqueleto.nvim](https://github.com/cvigilv/esqueleto.nvim)

- [new-file-template.nvim](https://github.com/otavioschwanck/new-file-template.nvim)

- [templar.nvim](https://github.com/vigoux/templar.nvim)

### Q. I want to use this plugin for other filetypes!

Most of the code related to luasnip and template loading mechanism is
written inside
[`snippet_handler.lua`](https://github.com/pysan3/neorg-templates/blob/main/lua/neorg/modules/external/templates/snippet_handler.lua)
which **does not** rely on neorg at all. The entry point is mostly
`load_template_at_curpos(content, fs_name)`.

For usage example, read the implementation of subcommands
[here](https://github.com/pysan3/neorg-templates/blob/main/lua/neorg/modules/external/templates/module.lua#L78-L116).

You are free to fork / copy-paste this code as long as you respect the
[LICENSE](#license). I just don't have the motivation to compete against
other template plugins listed above.

### Q. Where can I contact you?

I'll be at [neorg's discord server](https://discord.gg/T6EgTAX7ht) with
the username `@pysan3`, so feel free to ping me there.

### Q. Where can I donate?

Thank you very much but I'd be more than happy with a star for this
repo. Buy yourself a cup of coffee and have a nice day 😉
