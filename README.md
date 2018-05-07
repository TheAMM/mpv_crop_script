# `mpv_crop_script.lua`

[![](docs/sintel_crop_guides_crosshair.jpg "Cropping Sintel (2010) with mpv_crop_script.lua")](https://youtu.be/Eis0Ipu7yw0)
[*Click the image or here to see the script in action*](https://youtu.be/Eis0Ipu7yw0)

*(You might also be interested in [`mpv_thumbnail_script.lua`](https://github.com/TheAMM/mpv_thumbnail_script))*

----

## What is it?

`mpv_crop_script.lua` is a script for making cropped screenshots from within [mpv](https://github.com/mpv-player/mpv), without any external dependencies[<sup>1</sup>](#footnotes), cross-platform-ly[<sup>2</sup>](#footnotes)!

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
# The template for screenshot filenames. See below for explanation of the property expansion!
# Can be an absolute or relative path (though relative paths are mostly untested)
output_template=/home/amm/mpv_screenshots/${filename} ${#pos:%02h.%02m.%06.3s} ${!full:${crop_w}x${crop_h} ${%unique:%03d}}.png
# The above template would expand to something like "Sintel.2010.1080p 00.05.40.500 200x400 001.png".
# or just "Sintel.2010.1080p 00.05.40.500.png" for the full-size screenshots (if kept).
# The template checks if 'full' is falsey, in which case it will expand the crop size and sequence number.

# Whether to try and create missing directories when saving screenshots
# (All directories will be created, not just the last section)
create_directories=yes|no

# Whether to keep the original full-size screenshot or not
keep_original=yes|no

# You can disable the automatic keybind to 'c' and add your own, see below
disable_keybind=yes|no
```

With `disable_keybind=yes`, you can add your own keybind to [`input.conf`](https://mpv.io/manual/master/#input-conf) with `script-binding crop-screenshot`, for example:
```ini
shift+alt+s script-binding crop-screenshot
```

**NEW:** You may also run mpv with `mpv --idle --script-opts mpv_crop_script-example-config=example.conf` to dump an example config with the default values to `example.conf`.

## Property expansion

This script's `output_template` mimics mpv's own [property expansion](https://mpv.io/manual/master/#property-expansion), but is not a 1:1 match. With it you can flexibly specify filenames and use lightweight logic (fallback expressions).  
(This script does not handle `$$`, `$}` or `$>` in any special way, as there is no need to do so.)  
The script provides a couple of properties, but you may also access all of [mpv's properties](https://mpv.io/manual/master/#property-list) by prefixing the property name with `mpv/`, eg. `${mpv/media-title}`.

Tricky examples of the property expansion:

`${#pos:%.3S}` will expand into the current second in the file, eg. `4213.310`.  
`${&-:%Y}/${&-:%Y-%m}/${&-:%Y-%m-%d}/` store your screenshots into a subdirectory like `2017/2017-11/2017-11-26`.  
`${?mpv/sid:SID:${mpv/sid}}` will expand into `SID:1` if the first subtitle track is active.  
`${?mpv/sub-visibility:with subs}${!mpv/sub-visibility:without subs}` will expand into `with/without subs` depending on if they're visible.  

**The following expansions are available:**

`${NAME}`  
  Expands to the value of property `NAME`, or in case the value is not found, an empty string

`${NAME:STR}`  
  Expands to the value of property `NAME`, or in case the value is not found, to the fallback `STR`, which is recursively expanded

`${?NAME:STR}`  
  If `NAME` is truthy (exists, not `nil`, `false` or `0`), recursively expand to `STR`

`${!NAME:STR}`  
  If `NAME` is falsey (doesn't exist, `nil`, `false`, or `0`), recursively expand to `STR`

`${~NAME:STR}`  
  Recursively expand to `STR` if `NAME` exists (but may be otherwise falsey, eg. `0`)

`${%NAME:FORMAT}`  
  Format `NAME` according to `FORMAT` using Lua's [`string.format()`](http://www.lua.org/manual/5.1/manual.html#pdf-string.format), which is practically `printf()`. Handy for formatting numbers, but could be used to pad strings as well.

`${#NAME:TIMEFORMAT}`  
  Format `NAME` (expected to be a `number`) into a timestamp using the given `TIMEFORMAT`. You may also leave the `:TIMEFORMAT` off, in which case the default `%02h.%02m.%02.3s` will be used.
  The `TIMEFORMAT` can use the following format characters:

  *  `%h` - hours, integer
  *  `%m` - minutes, integer
  *  `%s` - seconds, float
  *  `%S` - raw seconds (hours and minutes included), float
  *  `%M` - milliseconds (0-999), integer

  You may use format specifiers to pad or truncate the values, for example `%02h` will pad the hour with a zero and `%2.0s` will format the seconds as a two-digit decimal number.
  Milliseconds are included as their own specifier in case you'd like to do `%02h-%02m-%02.0f-%03M` for `00-01-34-523`.

`${&NAME:DATEFORMAT}`  
  Format current date with the given `TIMEFORMAT` using Lua's [`os.date()`](https://www.lua.org/pil/22.1.html). You may also leave the `:DATEFORMAT` off, in which case the default `%Y-%m-%d %H-%M-%S` will be used.
  (Due to lazy implementation, `NAME` can be anything)

`${@NAME:STR}`  
  Just like `${NAME:STR}`, but use [`mp.get_property_osd()`](https://mpv.io/manual/master/#lua-scripting-mp-get-property-osd(name-[,def])) when accessing mpv properties. This can be useful in getting more humand-readable output from properties.


**The following script-specific properties are available:**

| Name | Type | Notes |
| ---- | ---- | ----- |
| `filename` | `string` | Original filename with the extension stripped off |
| `file_ext` | `string` | Original extension, dot included |
| `path` | `string` | full source path - may be a network path, so beware |
| `pos` | `number` | Current playback position (float), format it with `${#pos:TIMEFORMAT}`! |
| `unique` | `number` | A sequence number. The script will choose the first available filename, starting with `unique` as 1 and counting up. Use with `${%...}` |
| `full` | `boolean` | Flag to specify which filename is being expanded - the cropped (`false`) output or the intermediary full-size image (`true`). Use with `${?...}` and `${-...}` |
| `crop_w` | `number` | Width of the crop |
| `crop_h` | `number` | Height of the crop |
| `crop_x` | `number` | Left edge of the crop |
| `crop_y` | `number` | Top edge of the crop |
| `crop_x2` | `number` | Right edge of the crop |
| `crop_y2` | `number` | Bottom edge of the crop |


## Development

Included in the repository is the `concat_files.py` tool I use for automatically concatenating files upon their change, and also mapping changes to the output file back to the source files. It's really handy on stack traces when mpv gives you a line and column on the output file - no need to hunt down the right place in the source files!

The script requires Python 3, so install that. Nothing more, though. Call it with `concat_files.py concat.json`.

You may also, of course, just `cat` the files together yourself. See the [`concat.json`](concat.json) for the order.

### Donation

If you *really* get a kick out of this (weirdo), you can [paypal me](https://www.paypal.me/TheAMM) or send bitcoins to `1K9FH7J3YuC9EnQjjDZJtM4EFUudHQr52d`. Just having the option there, is all.

#### Footnotes
<sup>1</sup>You *may* need to add `mpv[.exe]` to your `PATH`.

<sup>2</sup>Developed & tested on Windows and Linux (Ubuntu), but it *should* work on Mac and whatnot as well, if <sup>1</sup> has been taken care of.
