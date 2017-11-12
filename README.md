# `mpv_crop_script.lua`

[![](docs/sintel_crop_guides_crosshair.jpg "Cropping Sintel (2010) with mpv_crop_script.lua")](https://youtu.be/Eis0Ipu7yw0)
[*Click the image or here to see the script in action*](https://youtu.be/Eis0Ipu7yw0)

----

## What is it?

`mpv_crop_script.lua` is a script for making cropped screenshots from within [mpv](https://github.com/mpv-player/mpv), without any external dependencies[^deps], cross-platform-ly[^crossplat]!

## How?

mpv by itself doesn't support cropped screenshots, but can be told to save a full screenshot at a specified location.
This full-sized image can then be cropped down to size, but this requires a tool to edit the image (like ImageMagick). Bothersome!

However, we can forget external ependencies by calling on mpv itself to use the the built-in [encoding features](https://mpv.io/manual/master/#encoding). Bam!

## How do I install it?

Grab a release from the [releases page](https://github.com/TheAMM/mpv_crop_script/releases) (or [see below](#development) how to "build" (concatenate) it yourself) and place the `mpv_crop_script.lua` to your mpv's `scripts` directory.

For example:
  * Linux/Unix/Mac: `~/.config/mpv/scripts/mpv_crop_script.lua`
  * Windows: `%APPDATA%\Roaming\mpv\scripts\mpv_crop_script.lua`

See the [Files section](https://mpv.io/manual/master/#files) in mpv's manual for more info.

## How do I use it?

Press `c` and crop away! You can toggle a crosshair and guides for the crop box with `c` and `x` while cropping.

Pressing `Enter` will save a cropped screenshot, while `ESC` will cancel the current crop.

## Configuration

Create a file called `mpv_crop_script.conf` inside your mpv's `lua-settings` directory.

For example:
  * Linux/Unix/Mac: `~/.config/mpv/lua-settings/mpv_crop_script.conf`
  * Windows: `%APPDATA%\Roaming\mpv\lua-settings\mpv_crop_script.conf`

See the [Files section](https://mpv.io/manual/master/#files) in mpv's manual for more info.

In this file you may set the following options:
```ini
# Output filename template, with path
output_template=/home/amm/mpv_screenshots/%f %p %D%U.%x
# Possible substitutions
# %f - Original filename without extension - "A.Video.2017"
# %X - Original extension - "mkv"
# %x - Output extension   - "png"
# %u - Unique - "", "_1", "_2", ...
# %U - Unique - "", " 1", " 2", ...
# %p - Current time - 00.03.50.423
# %P - Current time without decimals - 00.03.50
# %D - Crop size - 200x300, 123x450, full

# Whether to keep the original full-size screenshot or not
keep_original=yes|no

# You can disable the automatic keybind to 'c' and add your own, see below
disable_keybind=yes|no
```

With `disable_keybind=yes`, you can add your own keybind to [`input.conf`](https://mpv.io/manual/master/#input-conf) with `script-binding crop-screenshot`, for example:
```ini
shift+alt+s script-binding crop-screenshot
```

## Development

Included in the repository is the `concat_files.py` tool I use for automatically concatenating files upon their change, and also mapping changes to the output file back to the source files. It's really handy on stack traces when mpv gives you a line and column on the output file - no need to hunt down the right place in the source files!

The script requires Python 3, so install that. Nothing more, though. Call it with `concat_files.py concat.json`.

You may also, of course, just `cat` the files together yourself. See the [`concat.json`](concat.json) for the order.

### Donation

If you *really* get a kick out of this (weirdo), you can [paypal me](https://www.paypal.me/TheAMM) or send bitcoins to `1K9FH7J3YuC9EnQjjDZJtM4EFUudHQr52d`. Just having the option there, is all.

[^deps]: You *may* need to add `mpv[.exe]` to your `PATH`.
[^crossplat]: Developed & tested on Windows and Linux (Ubuntu), but it *should* work on Mac and whatnot as well, if <sup>1</sup> has been taken care of.
