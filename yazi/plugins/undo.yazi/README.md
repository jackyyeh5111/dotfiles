# undo.yazi

A [Yazi](https://yazi-rs.github.io/) plugin to undo your changes.

## Installation

Use the [yazi package manager](https://yazi-rs.github.io/docs/cli#package-manager) to install this plugin:

```bash
ya pkg add 0xHouss/undo
```


## Usage

1. Key bindings:

    Add this to your [`~/.config/yazi/keymap.toml`](https://yazi-rs.github.io/docs/configuration/keymap):

    ```toml
    # A TOML linter such as https://taplo.tamasfe.dev/ can use this schema to validate your config.
    # If you encounter any issues, please make an issue at https://github.com/yazi-rs/schemas.
    "$schema" = "https://yazi-rs.github.io/schemas/keymap.json"

    [mgr]
    prepend_keymap = [
      ...

      # Undo
      { on = [
        "u",
      ], run = "plugin undo", desc = "Undo last changes" },

      ...
    ]

    ...
    ```

2. Setup

    Add this to your [`~/.config/yazi/init.lua`](https://yazi-rs.github.io/docs/configuration/overview#init.lua):

    ```lua
    require("undo"):setup()
    ```

    This is required — the plugin records operations from the `trash` event it
    subscribes to here.

    Options:

    ```lua
    require("undo"):setup({
      -- Ask before restoring. Default: true
      show_confirm = true,
      -- Position of the confirmation dialog. Default: { "center", w = 70, h = 40 }
      position = { "center", w = 70, h = 40 },
      -- Stay quiet when an undo succeeds. Default: false
      suppress_success_notification = false,
      -- Operations kept in the history file. Default: 200
      limit = 200,
    })
    ```

3. Enjoy

    Currently the plugin handles undoing trashing, when deleting items to the trash, you can press u to restore them.

## Requirements

[trash-cli](https://github.com/andreafrancia/trash-cli) — `trash-restore` must be on your `PATH`.

## Notes

- An undo never overwrites a file that has taken the original's place. If the
  destination is occupied the restore fails, and the entry stays in the history
  so you can retry after moving the file out of the way.
- History lives in `~/.yazi_history`. Entries written by earlier versions are
  still read.

## Todo

- Add handling for rename, move, duplicate
