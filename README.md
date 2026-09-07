# bash-powerline

A powerline-style prompt for Bash with coloured segments, git integration, and theme presets. Built on [bash-powerline](https://github.com/riobard/bash-powerline) and styled after [powerline-shell](https://github.com/b-ryan/powerline-shell).

## Features

- Segmented prompt with coloured backgrounds and slanted separators
- Git integration: branch name, clean/dirty shown by segment colour
- Prompt symbol colour indicates last command success/failure
- Grey tail strip (matching the cwd segment) for a polished look
- Three built-in presets: `default`, `solarized`, `night`
- User configuration file to override any colour or setting
- Safe to source repeatedly (idempotent)

## Requirements

- A 256-colour-capable terminal (`$TERM=xterm-256color` or similar)
- A [patched/powerline font](https://github.com/powerline/fonts) for the slanted `\uE0B0` separator
  (e.g. *Fira Mono for Powerline* or *Meslo LG M for Powerline*)
  installed fonts live at `~/.local/share/fonts`; select one in your terminal emulator
- Use `POWERLINE_MODE=compatible` if you cannot install a patched font (uses `▶` instead)

## Installation

```bash
git clone <this-repo> ~/Projects/tools/bash-powerline
```

Then add to `~/.bashrc`:

```bash
source ~/Projects/tools/bash-powerline/bash-powerline.sh
```

### User configuration

```bash
mkdir -p ~/.config/bash-powerline
cp ~/Projects/tools/bash-powerline/config.example ~/.config/bash-powerline/config
```

Edit the file to taste. Values in the config override the active preset.

## Theme presets

| Preset       | Description                           |
|-------------|--------------------------------------|
| `default`   | Light-blue user, dark grey cwd, green clean / salmon-red dirty |
| `solarized` | Solarized dark palette                |
| `night`     | Cool blue-grey night scheme           |

Set at source time in `~/.bashrc`:

```bash
export POWERLINE_THEME=solarized
source ~/.../bash-powerline.sh
```

Or switch live in a running shell:

```bash
powerline_theme solarized   # applies immediately
powerline_theme default     # back to default
powerline_theme night       # cool night scheme
```

Any name not in `default|solarized|night` is treated as a custom preset whose colours come from your configuration file.

## Configuration

A configuration file is searched in this order; the first match wins:

1. `$POWERLINE_CONFIG` (explicit path)
2. `~/.config/bash-powerline/config`
3. `~/.bash-powerline.conf`

The file is plain Bash. Any `PL_*` variable set there overrides the active preset. See `config.example` for the full list.

### Environment variables

| Variable | Description | Default |
|---|---|---|
| `POWERLINE_MODE` | Separator style: `patched`, `compatible`, `flat` | `patched` |
| `POWERLINE_SEP` | Override the compatible-mode separator | `▶` |
| `POWERLINE_THEME` | Colour preset name | `default` |
| `POWERLINE_SHOW_USER` | Show the username segment | _(unset)_ |
| `POWERLINE_SHOW_HOST` | Show the hostname segment | _(unset)_ |
| `POWERLINE_GIT` | Set to `0` to disable git segment | _(unset)_ |
| `PS_SYMBOL` | Prompt symbol (e.g. `$`) | `$` on Linux, `%` otherwise |

### Colour variables

Set in the config file (xterm-256 colour codes, `0`-`255`):

| Variable | Segment |
|---|---|
| `PL_USER_FG`, `PL_USER_BG` | Username |
| `PL_HOST_FG`, `PL_HOST_BG` | Hostname |
| `PL_CWD_FG`, `PL_CWD_BG` | Working directory + prompt tail |
| `PL_GIT_FG`, `PL_GIT_BG` | Git, clean |
| `PL_GITD_FG`, `PL_GITD_BG` | Git, dirty |
| `PL_OK_FG` | Prompt symbol, last command succeeded |
| `PL_ERR_FG` | Prompt symbol, last command failed |

## Custom presets

1. Create a config file defining your colours:

```bash
export POWERLINE_THEME=mytheme

PL_USER_FG=15;  PL_USER_BG=61
PL_HOST_FG=15;  PL_HOST_BG=37
PL_CWD_FG=254;  PL_CWD_BG=234
PL_GIT_FG=15;   PL_GIT_BG=64
PL_GITD_FG=15;  PL_GITD_BG=160
PL_OK_FG=46
PL_ERR_FG=196
```

2. Switch to it at runtime: `powerline_theme mytheme`

## License

MIT
