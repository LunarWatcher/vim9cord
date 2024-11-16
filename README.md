# Vim9cord

Vim9cord is a pure vim9script plugin for Discord rich presence.

## Requirements

Currently, only Linux and non-Flatpak/non-Snap discord is supported. **This plugin will not work on Windows or Mac** - but on unsupported platforms or with unsupported Discord installations, it should quietly error out. If you'd like this to change, consider submitting a pull request.

Aside this, Vim 9.1 or newer is required. Vim 9.0 or newer may also work, but support for 9.0 and earlier is not intentional.

## Installing

Using your favourite plugin manager is recommended. Here's copypasta for vim-plug:
```
Plug 'LunarWatcher/vim9cord'
```
Replace "Plug" with whatever your plugin manager uses if you don't use vim-plug.

## Features

### Button support

You can use `g:Vim9cordButtons` to add up to two custom buttons on Discord. See the docs for details.

### Pure Vim9script

No external dependencies (aside Discord, for obvious reasons) are required for the plugin 

### Fails fast and quietly

Discord's rich presence is just a cool thing to occasionally have. The plugin is therefore designed for this to never be a thing you _need_ to have if you want your editor to continue running smoothly. Optimally, you'll never notice the plugin is there, even if Discord fails, your internet fails, or you run your config on a machine without Discord (or an unsupported OS or Discord install method).
