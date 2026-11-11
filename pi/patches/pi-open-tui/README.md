# pi-open-tui patches

`code-selection.patch` keeps code-block frames and Copy buttons, but excludes side borders and padding from fullscreen selection highlighting and copied text. It marks each code row's content with invisible APC sequences and clips Pi's shared selection-column calculation to those bounds. Ordinary transcript selection is unchanged.

The patch uses the extension's existing prototype-patch and cleanup mechanism. It checks for Pi's private `getSelectionColumns` method before wrapping it. If Pi changes that method, this patch needs checking again. Regular-mode terminal selection is not changed.

The markers are stripped from every frame before it is written, so the terminal never sees them. Terminal multiplexers such as herdr can mangle unknown APC sequences. As a second safeguard, the markers use the standard ST (`ESC \\`) terminator. BEL is not a valid APC terminator in real terminals, even though Pi's width helpers accept it; using BEL can swallow code, indentation, and frame padding.

Verified with pi-open-tui 0.4.4 and Pi 1.5.2. A headless xterm test checks actual terminal cells as well as Pi's selection behavior.

After `pi update`, reapply the patches from the dotfiles root:

```sh
bash pi/install.sh
```

Restart Pi to load the patched code.

Run the regression tests against the installed packages (requires a managed Pi installation):

```sh
npm ci --prefix pi/patches/pi-open-tui --ignore-scripts
npm test --prefix pi/patches/pi-open-tui
```

`no-side-rails.patch` separately removes the editor's side rails.
