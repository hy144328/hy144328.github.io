+++
date = '2026-04-22T02:05:13.510292+02:00'
title = 'Neovim packages and plugins'
tags = ['lua', 'neovim']
+++

{{< badge >}}lua{{< /badge >}} {{< badge >}}neovim{{< /badge >}}

Three weeks ago, [Neovim version 0.12](https://github.com/neovim/neovim/releases/tag/v0.12.0) was released.
Arguably, the most exciting new feature is the built-in plugin manager, [`vim.pack`](https://neovim.io/doc/user/pack/#vim.pack).
It got me to revisit my Neovim configuration and installed plugins.
At the same time, I saw many people on [Reddit](https://www.reddit.com/r/neovim/) share their migration stories.
So I decided to write this tutorial, too.

[Evgeni Chasnovski](https://echasnovski.com/) sets the gold standard for [`vim.pack` tutorials](https://echasnovski.com/blog/2026-03-13-a-guide-to-vim-pack).
While my tutorial has very little of substance to add, it records my own experiences with `vim.pack`.
Or in other words, I consider this to be a Neovim tutorial for dummies.
I start with instructions to download and install Neovim.
By the end of the tutorial, I hope it becomes clear how to customize Neovim with plugins, and how to develop your own plugins.

## Installation

For Ubuntu, Neovim is available from the `apt` repository.
However, it tends to be outdated compared to the current stable release.
In Ubuntu 24.04, the `apt` repository provides [version 0.9.5](https://github.com/neovim/neovim/releases/tag/v0.9.5).
The current stable release is [version 0.12.1](https://github.com/neovim/neovim/releases/tag/v0.12.1).
Therefore, I propose two alternative installation methods.

The first alternative installation method is to [download a pre-compiled binary](https://github.com/neovim/neovim/releases/).
In order to select the pre-compiled binary, you have to know your operating system and your CPU architecture.
On Unix (macOS or Linux, not Windows), use `uname -s` and `uname -m` to confirm operating system and CPU architecture, respectively.
For instance, my computer runs on Ubuntu 24.04, which is a Linux operating system, and the CPU architecture is `x86_64`.
Download the pre-compiled binary to a location of your choice.

The second alternative installation method is to [compile a binary from source](https://github.com/neovim/neovim/blob/master/BUILD.md).
If your computer runs on an older Ubuntu version, e.g. version 20.04, this will be necessary because the pre-compiled binary links against more modern `libc` versions.
Clone the [Neovim repository](https://github.com/neovim/neovim) to a location of your choice.
Check out the tag of the current stable release, i.e. `v0.12.1`.
Take care of the [build prerequisites](https://github.com/neovim/neovim/blob/master/BUILD.md#build-prerequisites).
Enter the following commands:

```
make CMAKE_BUILD_TYPE=RelWithDebInfo CMAKE_INSTALL_PREFIX=$(pwd)/v0.12.1
make install
```

The binary is found under `v0.12.1/bin/nvim`.

Once I have installed Neovim, I like to make it easily accessible from the command line.
Firstly, I create a symbolic link to the pre-compiled binary in a standard location on `PATH`, e.g. `~/.local/bin`:

```
ln -s $(pwd)/nvim ~/.local/bin/nvim
```

Secondly, I need to make sure that the standard location is on `PATH`.
For instance, look in `.profile` for a command like the following:

```
export PATH=$HOME/.local/bin:$PATH
```

Now, typing `nvim` into the command line will open Neovim.

## Neovim plugins

Neovim has a plugin ecosystem that allows you to customize your editor experience.
On Unix, Neovim looks for configuration in `~/.config/nvim/`.
In particular, the following three locations are relevant to us:

*   `~/.config/nvim/init.lua`.
    This is the starting point of our Neovim configuration.
    Note that it is also possible to use [`~/.config/nvim/init.vim`](https://neovim.io/doc/user/starting/#init.vim) instead (`init.lua` and `init.vim` are mutually exclusive).
    However, this tutorial is opinionated, and we deliberately choose the more modern Lua set-up.
*   `~/.config/nvim/plugin/`.
    This is useful for [eager configuration of plugins](https://neovim.io/doc/user/starting/#load-plugins).
    It is best reserved for lightweight configuration, e.g. key bindings and auto-commands.
*   `~/.config/nvim/lua/`.
    This is useful for lazy configuration of plugins.
    It is best reserved for heavyweight configuration, e.g. debuggers involving start-up of servers.

### Example: eager and lazy loading

We install the following plugins:

*   [`gitsigns.nvim`](https://github.com/lewis6991/gitsigns.nvim).
*   [`indent-blankline.nvim`](https://github.com/lukas-reineke/indent-blankline.nvim).
*   [`neotest`](https://github.com/nvim-neotest/neotest).

    *   [`neotest-go`](https://github.com/nvim-neotest/neotest-go).
    *   [`neotest-python`](https://github.com/nvim-neotest/neotest-python).

In `~/.config/nvim/init.lua`, we execute the following command:

```lua
vim.pack.add({
  {src='https://github.com/lewis6991/gitsigns.nvim'},
  {src='https://github.com/lukas-reineke/indent-blankline.nvim'},
  {src='https://github.com/nvim-lua/plenary.nvim'},
  {src='https://github.com/nvim-neotest/neotest'},
  {src='https://github.com/nvim-neotest/neotest-go'},
  {src='https://github.com/nvim-neotest/neotest-python'},
  {src='https://github.com/nvim-neotest/nvim-nio'},
})
```

Each plugin possibly requires custom initialization.
For simplicity, we take the default configuration from the respective documentation if applicable.

In order to not complicate things, we want to eagerly load each configuration file.
Therefore, we place all configuration files into `~/.config/nvim/plugin/`:

*   [`~/.config/nvim/plugin/gitsigns.lua`](./gitsigns.lua).
*   [`~/.config/nvim/plugin/ibl.lua`](./ibl.lua).
*   [`~/.config/nvim/plugin/neotest.lua`](./neotest.lua).

Note that I name each configuration file after the corresponding Lua module.
This holds no relevance whatsoever.
`plugin/` directories are not searched for Lua modules during import.
Thus, there will be no confusion between our configuration file and the corresponding Lua module when the Lua module is imported elsewhere.

You will possibly notice that the start-up time of Neovim is slightly sluggish.
Let us quantify this:

```
nvim --startuptime startup.txt
```

In `startup.txt`, we observe a disproportional jump from 26.786 to 264.907 milliseconds around the initialization of `neotest`:

```
--- Startup times for process: Primary (or UI client) ---

times in msec
 clock   self+sourced   self:  sourced script
 clock   elapsed:              other lines

000.001  000.001: --- NVIM STARTING ---
000.140  000.140: event init
000.239  000.099: early init
000.298  000.058: locale set
000.340  000.042: init first window
000.776  000.436: inits 1
000.783  000.007: window checked
000.786  000.003: parsing arguments
001.421  000.059  000.059: require('vim._core.shared')
001.532  000.007  000.007: require('string.buffer')
001.571  000.071  000.065: require('vim.inspect')
001.640  000.057  000.057: require('vim._core.options')
001.645  000.218  000.090: require('vim._core.editor')
001.683  000.036  000.036: require('vim._core.system')
001.685  000.367  000.054: require('vim._init_packages')
001.688  000.535: init lua interpreter
003.672  001.984: nvim_ui_attach
004.171  000.499: nvim_set_client_info
004.174  000.003: --- NVIM STARTED ---

--- Startup times for process: Embedded ---

times in msec
 clock   self+sourced   self:  sourced script
 clock   elapsed:              other lines

000.000  000.000: --- NVIM STARTING ---
000.133  000.132: event init
000.220  000.087: early init
000.274  000.054: locale set
000.310  000.036: init first window
000.747  000.437: inits 1
000.756  000.009: window checked
000.759  000.003: parsing arguments
001.550  000.063  000.063: require('vim._core.shared')
001.654  000.006  000.006: require('string.buffer')
001.691  000.065  000.059: require('vim.inspect')
001.761  000.059  000.059: require('vim._core.options')
001.766  000.210  000.087: require('vim._core.editor')
001.802  000.034  000.034: require('vim._core.system')
001.804  000.347  000.040: require('vim._init_packages')
001.806  000.700: init lua interpreter
001.858  000.051: expanding arguments
001.877  000.019: inits 2
002.374  000.498: init highlight
002.378  000.003: waiting for UI
002.539  000.162: done waiting for UI
002.555  000.016: clear screen
002.758  000.021  000.021: require('vim.keymap')
003.968  000.278  000.278: sourcing nvim_exec2()
004.014  000.013  000.013: require('vim._core.log')
007.155  004.596  004.284: require('vim._core.defaults')
007.158  000.007: init default mappings & autocommands
007.579  000.038  000.038: sourcing /home/hans/Install/neovim-20260407/v0.12.1/share/nvim/runtime/ftplugin.vim
007.625  000.019  000.019: sourcing /home/hans/Install/neovim-20260407/v0.12.1/share/nvim/runtime/indent.vim
008.600  000.073  000.073: require('vim._async')
008.610  000.787  000.714: require('vim.pack')
008.639  000.020  000.020: require('vim.fs')
008.684  000.004  000.004: require('vim.F')
011.166  000.775  000.775: sourcing /home/hans/Install/neovim-20260407/v0.12.1/share/nvim/runtime/colors/vim.lua
011.172  000.865  000.090: sourcing nvim_exec2() called at /home/hans/.config/nvim/init.lua:0
011.236  000.017  000.017: sourcing /home/hans/Install/neovim-20260407/v0.12.1/share/nvim/runtime/indoff.vim
011.246  000.070  000.052: sourcing nvim_exec2() called at /home/hans/.config/nvim/init.lua:0
011.257  003.591  001.845: sourcing /home/hans/.config/nvim/init.lua
011.260  000.454: sourcing vimrc file(s)
011.434  000.062  000.062: sourcing nvim_exec2() called at /home/hans/Install/neovim-20260407/v0.12.1/share/nvim/runtime/filetype.lua:0
011.437  000.120  000.058: sourcing /home/hans/Install/neovim-20260407/v0.12.1/share/nvim/runtime/filetype.lua
011.577  000.055  000.055: sourcing /home/hans/Install/neovim-20260407/v0.12.1/share/nvim/runtime/syntax/synload.vim
011.644  000.176  000.121: sourcing /home/hans/Install/neovim-20260407/v0.12.1/share/nvim/runtime/syntax/syntax.vim
012.106  000.165  000.165: require('gitsigns')
012.696  000.297  000.297: require('gitsigns.util')
012.714  000.585  000.288: require('gitsigns.config')
013.083  000.359  000.359: require('gitsigns.highlight')
013.443  000.344  000.344: require('gitsigns.debug.log')
013.890  000.082  000.082: require('gitsigns.debounce')
013.900  002.008  000.473: sourcing /home/hans/.config/nvim/plugin/gitsigns.lua
014.647  000.249  000.249: require('ibl.utils')
014.652  000.408  000.160: require('ibl.config')
014.872  000.081  000.081: require('ibl.indent')
014.877  000.224  000.143: require('ibl.hooks')
014.879  000.711  000.080: require('ibl.highlights')
014.936  000.056  000.056: require('ibl.autocmds')
015.021  000.082  000.082: require('ibl.inlay_hints')
015.111  000.088  000.088: require('ibl.virt_text')
015.397  000.218  000.218: require('ibl.scope_languages')
015.400  000.288  000.070: require('ibl.scope')
015.405  001.481  000.255: require('ibl')
016.938  000.779  000.779: require('vim.lsp.protocol')
016.970  000.934  000.155: require('vim.lsp.log')
018.162  001.187  001.187: require('vim.lsp.util')
018.661  000.217  000.217: require('vim.lsp.sync')
018.666  000.501  000.284: require('vim.lsp._changetracking')
019.135  000.112  000.112: require('vim.lsp._transport')
019.143  000.005  000.005: require('vim._core.stringbuffer')
019.188  000.519  000.402: require('vim.lsp.rpc')
019.252  003.823  000.682: require('vim.lsp')
020.169  000.565  000.565: require('vim.lsp.completion')
020.214  000.959  000.393: require('vim.lsp.handlers')
020.323  006.410  000.148: sourcing /home/hans/.config/nvim/plugin/ibl.lua
020.611  000.105  000.105: require('nio.tasks')
020.709  000.095  000.095: require('nio.control')
020.851  000.140  000.140: require('nio.uv')
020.911  000.057  000.057: require('nio.tests')
021.109  000.172  000.172: require('vim.ui')
021.115  000.202  000.029: require('nio.ui')
021.232  000.082  000.082: require('nio.streams')
021.234  000.118  000.036: require('nio.file')
021.400  000.021  000.021: require('nio.util')
021.763  000.352  000.352: require('vim.iter')
021.786  000.478  000.106: require('nio.logger')
021.791  000.555  000.077: require('nio.lsp')
021.861  000.069  000.069: require('nio.process')
021.870  001.445  000.103: require('nio')
022.087  000.040  000.040: sourcing nvim_exec2() called at /home/hans/.config/nvim/plugin/neotest.lua:0
023.331  001.237  001.237: require('vim.diagnostic')
023.335  001.464  000.187: require('neotest.config')
023.337  002.980  000.071: require('neotest')
024.107  000.160  000.160: require('plenary.bit')
024.173  000.064  000.064: require('plenary.functional')
024.199  000.017  000.017: require('ffi')
024.215  000.733  000.493: require('plenary.path')
024.294  000.031  000.031: require('neotest.lib.require')
024.308  000.092  000.061: require('neotest.lib')
024.445  000.029  000.029: require('neotest.utils')
024.486  000.177  000.148: require('neotest.logging')
024.512  000.024  000.024: require('neotest.async')
024.668  000.025  000.025: require('neotest-go.patterns')
024.674  000.161  000.136: require('neotest-go.utils')
024.783  000.029  000.029: require('neotest-go.color')
024.808  000.024  000.024: require('neotest-go.test_status')
024.811  000.136  000.083: require('neotest-go.output')
025.940  000.861  000.861: require('plenary.filetype')
026.107  000.060  000.060: require('neotest.lib.func_util.memoize')
026.110  000.168  000.108: require('neotest.lib.func_util')
026.289  000.143  000.143: require('neotest.types.tree')
026.353  000.061  000.061: require('neotest.types.fanout_accum')
026.355  000.244  000.040: require('neotest.types')
026.363  001.550  000.278: require('neotest.lib.file')
026.375  003.036  000.163: require('neotest-go')
026.597  000.163  000.163: require('neotest-python.base')
026.780  000.079  000.079: require('neotest-python.pytest')
026.783  000.184  000.105: require('neotest-python.adapter')
026.786  000.410  000.063: require('neotest-python')
264.907  000.593  000.593: require('neotest.adapters')
267.890  000.430  000.430: require('neotest.client.events')
267.933  001.042  000.611: require('neotest.client.state')
269.695  001.755  001.755: require('neotest.client.runner')
270.283  000.576  000.576: require('neotest.client.strategies')
270.339  005.412  002.039: require('neotest.client')
271.175  000.580  000.580: require('neotest.consumers.run')
271.939  000.753  000.753: require('neotest.consumers.diagnostic')
272.418  000.468  000.468: require('neotest.consumers.status')
272.982  000.555  000.555: require('neotest.consumers.output')
273.519  000.153  000.153: require('neotest.consumers.output_panel.panel')
273.545  000.553  000.399: require('neotest.consumers.output_panel')
275.205  000.578  000.578: require('neotest.consumers.summary.canvas')
276.336  001.120  001.120: require('neotest.consumers.summary.component')
276.357  002.319  000.621: require('neotest.consumers.summary.summary')
276.392  002.840  000.521: require('neotest.consumers.summary')
276.861  000.462  000.462: require('neotest.consumers.jump')
278.238  000.008  000.008: require('jit.profile')
278.774  000.524  000.524: require('jit.vmdef')
278.801  001.459  000.927: require('plenary.profile.p')
278.810  001.647  000.188: require('plenary.profile')
278.820  001.949  000.303: require('neotest.consumers.benchmark')
279.174  000.348  000.348: require('neotest.consumers.quickfix')
280.090  000.544  000.544: require('neotest.consumers.state.tracker')
280.106  000.923  000.378: require('neotest.consumers.state')
281.428  000.678  000.678: require('neotest.consumers.watch.watcher')
281.458  001.287  000.609: require('neotest.consumers.watch')
281.465  011.086  000.367: require('neotest.consumers')
282.042  000.397  000.397: require('neotest.lib.window')
282.480  262.140  238.226: sourcing /home/hans/.config/nvim/plugin/neotest.lua
283.704  001.144  001.144: require('gitsigns.async')
285.150  000.701  000.701: sourcing /home/hans/.local/share/nvim/site/pack/core/opt/neotest/plugin/neotest.lua
285.512  000.129  000.129: sourcing /home/hans/.local/share/nvim/site/pack/core/opt/plenary.nvim/plugin/plenary.vim
285.912  000.125  000.125: sourcing /home/hans/.local/share/nvim/site/pack/core/opt/gitsigns.nvim/plugin/gitsigns.lua
287.678  000.703  000.703: sourcing /home/hans/Install/neovim-20260407/v0.12.1/share/nvim/runtime/plugin/gzip.vim
289.981  000.710  000.710: sourcing /home/hans/Install/neovim-20260407/v0.12.1/share/nvim/runtime/pack/dist/opt/matchit/plugin/matchit.vim
290.241  002.454  001.744: sourcing /home/hans/Install/neovim-20260407/v0.12.1/share/nvim/runtime/plugin/matchit.vim
290.819  000.503  000.503: sourcing /home/hans/Install/neovim-20260407/v0.12.1/share/nvim/runtime/plugin/matchparen.vim
293.366  000.948  000.948: sourcing /home/hans/Install/neovim-20260407/v0.12.1/share/nvim/runtime/pack/dist/opt/netrw/plugin/netrwPlugin.vim
293.621  002.719  001.771: sourcing /home/hans/Install/neovim-20260407/v0.12.1/share/nvim/runtime/plugin/netrwPlugin.vim
294.211  000.028  000.028: sourcing /home/hans/.local/share/nvim/rplugin.vim
294.242  000.524  000.496: sourcing /home/hans/Install/neovim-20260407/v0.12.1/share/nvim/runtime/plugin/rplugin.vim
294.696  000.379  000.379: sourcing /home/hans/Install/neovim-20260407/v0.12.1/share/nvim/runtime/plugin/tarPlugin.vim
294.863  000.071  000.071: sourcing /home/hans/Install/neovim-20260407/v0.12.1/share/nvim/runtime/plugin/tutor.vim
295.449  000.493  000.493: sourcing /home/hans/Install/neovim-20260407/v0.12.1/share/nvim/runtime/plugin/zipPlugin.vim
295.713  000.147  000.147: sourcing /home/hans/Install/neovim-20260407/v0.12.1/share/nvim/runtime/plugin/editorconfig.lua
296.035  000.217  000.217: sourcing /home/hans/Install/neovim-20260407/v0.12.1/share/nvim/runtime/plugin/man.lua
296.588  000.452  000.452: sourcing /home/hans/Install/neovim-20260407/v0.12.1/share/nvim/runtime/plugin/net.lua
297.003  000.323  000.323: sourcing /home/hans/Install/neovim-20260407/v0.12.1/share/nvim/runtime/plugin/osc52.lua
297.512  000.413  000.413: sourcing /home/hans/Install/neovim-20260407/v0.12.1/share/nvim/runtime/plugin/shada.lua
297.734  000.109  000.109: sourcing /home/hans/Install/neovim-20260407/v0.12.1/share/nvim/runtime/plugin/spellfile.lua
297.811  004.090: loading rtp plugins
298.518  000.707: loading packages
298.840  000.169  000.169: sourcing /home/hans/.local/share/nvim/site/pack/core/opt/indent-blankline.nvim/after/plugin/commands.lua
298.850  000.163: loading after plugins
298.877  000.027: inits 3
303.886  005.009: reading ShaDa
304.338  000.452: opening buffers
304.386  000.049: BufEnter autocommands
304.391  000.005: editing files in windows
304.716  000.325: VimEnter autocommands
304.763  000.046: UIEnter autocommands
304.767  000.004: before starting main loop
305.079  000.018  000.018: require('vim._core.util')
305.477  000.692: first screen update
305.481  000.004: --- NVIM STARTED ---
```

We know that `neotest` is not necessarily needed at start-up, and that manual initialization is mostly acceptable.
Therefore, we want to lazily load the `neotest` configuration file:

*   `~/.config/nvim/lua/neotest_setup.lua`.
*   `~/.config/nvim/plugin/gitsigns.lua`.
*   `~/.config/nvim/plugin/ibl.lua`.

Note that I renamed `neotest.lua` to `neotest_setup.lua` when moving from `plugin/` to `lua/`.
Otherwise, this will cause confusion between our configuration file and the corresponding Lua module.
In `startup.txt`, we observe that the total time is reduced to 22.698 milliseconds:

```
--- Startup times for process: Primary (or UI client) ---

times in msec
 clock   self+sourced   self:  sourced script
 clock   elapsed:              other lines

000.002  000.002: --- NVIM STARTING ---
000.385  000.384: event init
000.621  000.235: early init
000.768  000.147: locale set
000.863  000.095: init first window
002.096  001.234: inits 1
002.116  000.020: window checked
002.124  000.008: parsing arguments
002.531  000.034  000.034: require('vim._core.shared')
002.582  000.003  000.003: require('string.buffer')
002.600  000.033  000.029: require('vim.inspect')
002.634  000.028  000.028: require('vim._core.options')
002.637  000.103  000.042: require('vim._core.editor')https://github.com/nvim-telescope/telescope.nvim
002.658  000.021  000.021: require('vim._core.system')
002.659  000.180  000.022: require('vim._init_packages')
002.661  000.356: init lua interpreter
004.194  001.533: nvim_ui_attach
004.446  000.252: nvim_set_client_info
004.447  000.001: --- NVIM STARTED ---

--- Startup times for process: Embedded ---

times in msec
 clock   self+sourced   self:  sourced script
 clock   elapsed:              other lines

000.000  000.000: --- NVIM STARTING ---
000.068  000.068: event init
000.112  000.044: early init
000.140  000.028: locale set
000.159  000.020: init first window
000.372  000.212: inits 1
000.376  000.005: window checked
000.378  000.001: parsing arguments
000.739  000.031  000.031: require('vim._core.shared')
000.809  000.003  000.003: require('string.buffer')
000.827  000.048  000.045: require('vim.inspect')
000.862  000.029  000.029: require('vim._core.options')
000.864  000.123  000.045: require('vim._core.editor')
000.882  000.016  000.016: require('vim._core.system')
000.883  000.204  000.033: require('vim._init_packages')
000.884  000.302: init lua interpreter
000.911  000.027: expanding arguments
000.921  000.010: inits 2
001.155  000.235: init highlight
001.156  000.001: waiting for UI
001.244  000.088: done waiting for UI
001.252  000.008: clear screen
001.352  000.009  000.009: require('vim.keymap')
001.927  000.124  000.124: sourcing nvim_exec2()
001.948  000.005  000.005: require('vim._core.log')
003.935  002.681  002.543: require('vim._core.defaults')
003.940  000.006: init default mappings & autocommands
004.381  000.040  000.040: sourcing /home/hans/Install/neovim-20260407/v0.12.1/share/nvim/runtime/ftplugin.vim
004.431  000.020  000.020: sourcing /home/hans/Install/neovim-20260407/v0.12.1/share/nvim/runtime/indent.vim
005.353  000.074  000.074: require('vim._async')
005.361  000.781  000.707: require('vim.pack')
005.394  000.024  000.024: require('vim.fs')
005.437  000.004  000.004: require('vim.F')
008.184  000.865  000.865: sourcing /home/hans/Install/neovim-20260407/v0.12.1/share/nvim/runtime/colors/vim.lua
008.190  000.961  000.095: sourcing nvim_exec2() called at /home/hans/.config/nvim/init.lua:0
008.257  000.019  000.019: sourcing /home/hans/Install/neovim-20260407/v0.12.1/share/nvim/runtime/indoff.vim
008.266  000.073  000.054: sourcing nvim_exec2() called at /home/hans/.config/nvim/init.lua:0
008.278  003.802  001.961: sourcing /home/hans/.config/nvim/init.lua
008.281  000.478: sourcing vimrc file(s)
008.462  000.063  000.063: sourcing nvim_exec2() called at /home/hans/Install/neovim-20260407/v0.12.1/share/nvim/runtime/filetype.lua:0
008.465  000.125  000.062: sourcing /home/hans/Install/neovim-20260407/v0.12.1/share/nvim/runtime/filetype.lua
008.613  000.058  000.058: sourcing /home/hans/Install/neovim-20260407/v0.12.1/share/nvim/runtime/syntax/synload.vim
008.684  000.186  000.128: sourcing /home/hans/Install/neovim-20260407/v0.12.1/share/nvim/runtime/syntax/syntax.vim
009.103  000.157  000.157: require('gitsigns')
009.648  000.277  000.277: require('gitsigns.util')
009.665  000.542  000.265: require('gitsigns.config')
009.965  000.292  000.292: require('gitsigns.highlight')
010.292  000.310  000.310: require('gitsigns.debug.log')
010.680  000.075  000.075: require('gitsigns.debounce')
010.689  001.790  000.414: sourcing /home/hans/.config/nvim/plugin/gitsigns.lua
011.382  000.226  000.226: require('ibl.utils')
011.388  000.372  000.146: require('ibl.config')
011.587  000.072  000.072: require('ibl.indent')
011.592  000.203  000.132: require('ibl.hooks')
011.594  000.648  000.073: require('ibl.highlights')
011.647  000.051  000.051: require('ibl.autocmds')
011.725  000.077  000.077: require('ibl.inlay_hints')
011.850  000.123  000.123: require('ibl.virt_text')
012.188  000.260  000.260: require('ibl.scope_languages')
012.191  000.339  000.079: require('ibl.scope')
012.195  001.487  000.249: require('ibl')
013.786  000.757  000.757: require('vim.lsp.protocol')
013.820  000.915  000.158: require('vim.lsp.log')
014.918  001.094  001.094: require('vim.lsp.util')
015.333  000.191  000.191: require('vim.lsp.sync')
015.338  000.417  000.226: require('vim.lsp._changetracking')
015.918  000.216  000.216: require('vim.lsp._transport')
015.928  000.006  000.006: require('vim._core.stringbuffer')
015.975  000.635  000.413: require('vim.lsp.rpc')
016.091  003.890  000.828: require('vim.lsp')
017.243  000.641  000.641: require('vim.lsp.completion')
017.280  001.185  000.544: require('vim.lsp.handlers')
017.387  006.686  000.124: sourcing /home/hans/.config/nvim/plugin/ibl.lua
017.625  000.139  000.139: sourcing /home/hans/.local/share/nvim/site/pack/core/opt/neotest/plugin/neotest.lua
017.700  000.028  000.028: sourcing /home/hans/.local/share/nvim/site/pack/core/opt/plenary.nvim/plugin/plenary.vim
017.776  000.027  000.027: sourcing /home/hans/.local/share/nvim/site/pack/core/opt/gitsigns.nvim/plugin/gitsigns.lua
018.130  000.142  000.142: sourcing /home/hans/Install/neovim-20260407/v0.12.1/share/nvim/runtime/plugin/gzip.vim
018.589  000.140  000.140: sourcing /home/hans/Install/neovim-20260407/v0.12.1/share/nvim/runtime/pack/dist/opt/matchit/plugin/matchit.vim
018.642  000.494  000.355: sourcing /home/hans/Install/neovim-20260407/v0.12.1/share/nvim/runtime/plugin/matchit.vim
018.754  000.097  000.097: sourcing /home/hans/Install/neovim-20260407/v0.12.1/share/nvim/runtime/plugin/matchparen.vim
019.250  000.187  000.187: sourcing /home/hans/Install/neovim-20260407/v0.12.1/share/nvim/runtime/pack/dist/opt/netrw/plugin/netrwPlugin.vim
019.300  000.527  000.339: sourcing /home/hans/Install/neovim-20260407/v0.12.1/share/nvim/runtime/plugin/netrwPlugin.vim
019.418  000.006  000.006: sourcing /home/hans/.local/share/nvim/rplugin.vim
019.425  000.106  000.100: sourcing /home/hans/Install/neovim-20260407/v0.12.1/share/nvim/runtime/plugin/rplugin.vim
019.515  000.076  000.076: sourcing /home/hans/Install/neovim-20260407/v0.12.1/share/nvim/runtime/plugin/tarPlugin.vim
019.549  000.014  000.014: sourcing /home/hans/Install/neovim-20260407/v0.12.1/share/nvim/runtime/plugin/tutor.vim
019.671  000.104  000.104: sourcing /home/hans/Install/neovim-20260407/v0.12.1/share/nvim/runtime/plugin/zipPlugin.vim
019.723  000.030  000.030: sourcing /home/hans/Install/neovim-20260407/v0.12.1/share/nvim/runtime/plugin/editorconfig.lua
019.827  000.086  000.086: sourcing /home/hans/Install/neovim-20260407/v0.12.1/share/nvim/runtime/plugin/man.lua
019.936  000.090  000.090: sourcing /home/hans/Install/neovim-20260407/v0.12.1/share/nvim/runtime/plugin/net.lua
020.021  000.064  000.064: sourcing /home/hans/Install/neovim-20260407/v0.12.1/share/nvim/runtime/plugin/osc52.lua
020.127  000.087  000.087: sourcing /home/hans/Install/neovim-20260407/v0.12.1/share/nvim/runtime/plugin/shada.lua
020.170  000.022  000.022: sourcing /home/hans/Install/neovim-20260407/v0.12.1/share/nvim/runtime/plugin/spellfile.lua
020.185  000.982: loading rtp plugins
020.340  000.154: loading packages
020.437  000.050  000.050: sourcing /home/hans/.local/share/nvim/site/pack/core/opt/indent-blankline.nvim/after/plugin/commands.lua
020.440  000.050: loading after plugins
020.449  000.010: inits 3
022.040  001.591: reading ShaDa
022.239  000.199: opening buffers
022.262  000.023: BufEnter autocommands
022.264  000.002: editing files in windows
022.385  000.121: VimEnter autocommands
022.410  000.025: UIEnter autocommands
022.412  000.002: before starting main loop
022.550  000.012  000.012: require('vim._core.util')
022.696  000.272: first screen update
022.698  000.002: --- NVIM STARTED ---
```

### Example: Plugin events

We install the following plugins:

*   [`nvim-treesitter`](https://github.com/nvim-treesitter/nvim-treesitter).
*   [`telescope.nvim`](https://github.com/nvim-telescope/telescope.nvim).

In `~/.config/nvim/init.lua`, we execute the following the command:

```lua
vim.pack.add({
  {src='https://github.com/nvim-lua/plenary.nvim'},
  {src='https://github.com/nvim-telescope/telescope.nvim'},
  {src='https://github.com/nvim-telescope/telescope-fzf-native.nvim'},
  {src='https://github.com/nvim-treesitter/nvim-treesitter'},
})
```

We place the configuration files into `~/.config/nvim/plugin/`:

*   `~/.config/nvim/plugin/nvim-treesitter`.
*   `~/.config/nvim/plugin/telescope.lua`.

But this is not enough.
Both Treesitter and Telescope need to build code locally in order to work.
When Neovim is notified of events related to `vim.pack`, registered callbacks are executed.
More importantly, the callbacks have to be registered to the event before the event happens.
Therefore, we have to add a section before the call to `vim.pack.add()` in `~/.config/nvim/init.lua`:

```lua
vim.api.nvim_create_autocmd('PackChanged', {
  callback = function(ev)
    local name, kind = ev.data.spec.name, ev.data.kind

    if name == 'nvim-treesitter' then
      if kind == 'update' then
        if not ev.data.active then
          vim.cmd.packadd('nvim-treesitter')
        end

        vim.cmd('TSUpdate')
      end
    elseif name == 'telescope-fzf-native.nvim' then
      if kind == 'install' or kind == 'update' then
        vim.system({'make'}, {cwd=ev.data.path})
      end
    end
  end
})

vim.pack.add({
  {src='https://github.com/nvim-lua/plenary.nvim'},
  {src='https://github.com/nvim-telescope/telescope.nvim'},
  {src='https://github.com/nvim-telescope/telescope-fzf-native.nvim'},
  {src='https://github.com/nvim-treesitter/nvim-treesitter'},
})
```

In the case of Treesitter, we have to make sure that the Lua module is active, i.e. downloaded _and_ loaded, before the `TSUpdate` callback is triggered.
In the case of Telescope, there is no such external dependency, and the `make` callback is triggered immediately in the appropriate working directory.

## Neovim packages

Before we discuss how to develop your own plugins, let us peek a little under the hood of `vim.pack`.
On Unix, Neovim clones plugins to `~/.local/share/nvim/site/pack/core/opt/`.
For the examples above, the contents of the directory would look like this:

*   `~/.local/share/nvim/site/pack/core/opt/gitsigns.nvim/`.
*   `~/.local/share/nvim/site/pack/core/opt/indent-blankline.nvim/`.
*   `~/.local/share/nvim/site/pack/core/opt/neotest/`.
*   `~/.local/share/nvim/site/pack/core/opt/neotest-go/`.
*   `~/.local/share/nvim/site/pack/core/opt/neotest-python/`.
*   `~/.local/share/nvim/site/pack/core/opt/nvim-nio/`.
*   `~/.local/share/nvim/site/pack/core/opt/nvim-treesitter/`.
*   `~/.local/share/nvim/site/pack/core/opt/plenary.nvim/`.
*   `~/.local/share/nvim/site/pack/core/opt/telescope-fzf-native.nvim/`.
*   `~/.local/share/nvim/site/pack/core/opt/telescope.nvim/`.

Plugins such as `gitsigns.nvim` usually follow a familiar blueprint:

*   `~/.local/share/nvim/site/pack/core/opt/gitsigns.nvim/lua/gitsigns.lua`.
*   `~/.local/share/nvim/site/pack/core/opt/gitsigns.nvim/plugin/gitsigns.lua`.

This is very similar to the configuration found in `~/.config/nvim/`!
More specifically:

*   The code in `lua/gitsigns.lua` is lazily loaded.
    In general, `require('gitsigns')` will look for `lua/gitsigns.lua` or `lua/gitsigns/init.lua`.
*   The code in `plugin/gitsigns.lua` is eagerly loaded.
    It is a matter of convention to keep the eagerly loaded code lightweight, and to name the single Lua script in `plugin/` after the corresponding Lua module in `lua/`.

Other than plugins, there are also packages.
In essence, packages are collections of plugins.
In fact, `vim.pack` manages a single `core` package at `~/.local/share/nvim/site/pack/core/`!
The plugins in a package are divided into two subfolders:

*   In `start/`, plugins are loaded automatically.
    So for each plugin, the code in `plugin/` is immediately executed, and the code in `lua` is made available for import.
    It does not require any customization of `~/.config/nvim/init.lua`.
*   In `opt/`, plugins are loaded via the `packadd` command or the `vim.pack.add()` Lua function.
    In addition to loading, `vim.pack.add()` will clone the plugin if absent whereas `packadd` assumes that the plugin already exists.

`vim.pack.add()` always clones to `opt/` so you will only see a `~/.local/share/nvim/site/pack/core/opt/` subfolder but not a corresponding `start/` subfolder here.

It is possible to manually place plugins into the `core` package.
But it is generally discouraged because it will possibly interfere with `vim.pack`.
This is not a problem because it only requires you to add another package, e.g. `~/.local/share/nvim/site/pack/dev/` or `~/.local/share/nvim/site/pack/local/`.

### Example: trailing whitespace

With a more or less solid understanding of plugins and packages, let us develop a simple plugin.
The plugin will register an autocommand to remove trailing whitespace at the end of every line in a file whenever the file is written to disk.
In Vim, this is a well-known [one-liner](https://vim.fandom.com/wiki/Remove_unwanted_spaces#Automatically_removing_all_trailing_whitespace).
However, the details of the regular expression are beyond the scope of this example.
Imagine we are in the process of developing such a plugin for Neovim in Lua.
What does the development workflow look like?

Firstly, initialize a Git repository for the plugin code at a location of your choice.
Alternatively, clone my [Git repository](https://gitlab.com/hyu/white-trail.nvim).
For instance:

```
cd ~/Scratch/
git clone git@gitlab.com:hyu/white-trail.nvim
cd white-trail.nvim/
git checkout v0.2.0
```

It has the familiar plugin layout, and consists of both `lua/` and `plugin/` folders.

Secondly, make the plugin discoverable by Neovim.
Place the Git repository inside a package other than `core`.
For instance:

```
cd ~/.local/share/nvim/site/pack/
mkdir -p local/start
cd local/start/
ln -s ~/Scratch/white-trail.nvim
cd white-trail.nvim/
git status
```

Note that we use `start/` instead of `opt/` in order to by-pass explicit calls in `~/.config/nvim/init.lua` to `vim.pack.add()` or `packadd` during development.

Finally, once development is concluded and the code is released on [GitHub](https://github.com/), [GitLab](https://about.gitlab.com/) or [Codeberg](https://codeberg.org/), remove the Git repository from the package.
For instance:

```
cd ~/.local/share/nvim/site/pack/local/start/
rm white-trail.nvim
```

Add the released plugin to `~/.config/nvim/init.lua`:

```lua
vim.pack.add({
  {src='https://gitlab.com/hyu/white-trail.nvim'},
})
```

Upon start-up, the plugin will be automatically downloaded and loaded.
You will find the managed Git repository under `~/.local/share/nvim/site/pack/core/opt/white-trail.nvim/`.

---

I think this is enough to get you started with Neovim, and explore the plugin ecosystem on your own!
I have not addressed specific plugins, i.e. to turn Neovim into an IDE.
Perhaps, I will find the time to write about it after the next major release of Neovim makes me revisit my configuration and installed plugins.
