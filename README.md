# XcodeVimTricks
Proof of concept for Remapping keys in Xcode's Vim mode using [Hammerspoon](https://hammerspoon.org).

## What?

Xcode has a built-in Vim mode. I wanted to do some changes to it:

* `U` in normal mode should redo
* `y` and `p` should use the system clipboard by default, while still allowing specifying a register manually
* `Y` should yank from the cursor to the end of the line, similar to `D` and `C`
* `j` and `k` act like `gj` and `gk`, unless you do something like `10j`, then they operate normally
* `:w<CR>` saves
* `:%s` opens search and replace
* `gv` to reselect the last visual mode selection

## Why?

I have some bindings in my `.vimrc` which are muscle memory. I also have [opinions about how the system clipboard should operate in Vim](https://ezhik.me/blog/vim-clipboard/).

## How?

Evil, evil bodging. The current Vim mode Xcode shows in the debug bar is not exposed to accessibility APIs, but every different mode does have its own color, so what this does is:

1. Determine if the current focused element is the source code editor
2. Determine where the debug bar is in the window
3. Take a screenshot of the window and compare the color of a pixel in the Vim mode status (I'M SORRY)
4. Perform tricks

## What next?

Who knows. Right now this isn't really a proper Hammerspoon spoon and there is no user configuration, but it does most of the essential things I put in my `.vimrc`.

## Installation
1. Install Hammerspoon and grant it accessibility and screen recording permissions
2. Put the spoon in `~/.hammerspoon/Spoons`
3. Enable it by adding the following to your Hammerspoon configuration (`~/.hammerspoon/init.lua`):

```lua
hs.loadSpoon("XcodeVimTricks")
spoon.XcodeVimTricks:start()
```


