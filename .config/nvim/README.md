# Neovim configuration

Opinionated Neovim setup for **Lua**, **Go**, **JavaScript/TypeScript**, **C#**, and **Dart/Flutter**.

It uses:

- `lazy.nvim` for plugin management and bootstrapping
- Neovim's built-in LSP client
- `blink.cmp` + GitHub Copilot for completion
- `snacks.nvim` for pickers and LazyGit integration
- `oil.nvim` for file browsing
- `tree-sitter-manager.nvim` for parser installs
- `nvim-dap` for debugging

This config bootstraps itself. If `git` and `nvim` are available, `lazy.nvim` will clone itself automatically on first launch.

## What is configured

| Area | Plugins / behavior |
| --- | --- |
| Plugin manager | `folke/lazy.nvim` |
| Colors / UI | `smit4k/shale.nvim`, `folke/which-key.nvim`, `folke/trouble.nvim`, `nvim-mini/mini.icons` |
| Search / pickers | `folke/snacks.nvim` |
| File explorer | `stevearc/oil.nvim` replaces `netrw` |
| Completion | `saghen/blink.cmp`, `zbirenbaum/copilot.lua`, `giuxtaposition/blink-cmp-copilot` |
| LSP / tooling | `neovim/nvim-lspconfig`, `williamboman/mason.nvim`, `WhoIsSethDaniel/mason-tool-installer.nvim`, `folke/lazydev.nvim`, `seblyng/roslyn.nvim`, `nvim-flutter/flutter-tools.nvim` |
| Editing | `romus204/tree-sitter-manager.nvim`, `nvim-treesitter/nvim-treesitter-textobjects`, `nvim-mini/mini.ai`, `Wansmer/treesj`, `windwp/nvim-autopairs`, `unblevable/quick-scope` |
| Debugging | `mfussenegger/nvim-dap`, `rcarriga/nvim-dap-ui`, `theHamsta/nvim-dap-virtual-text`, `leoluz/nvim-dap-go`, `jbyuki/one-small-step-for-vimkind`, `Unity-Technologies/vscode-unity-debug` |
| Terminal / pane navigation | `christoomey/vim-tmux-navigator` |

## Language support

### LSP servers configured

- `lua_ls` for Lua
- `gopls` for Go
- `vtsls` for JavaScript / TypeScript
- `roslyn` for C#
- Dart / Flutter via `flutter-tools.nvim`

### Debug adapters configured

- Go via `delve`
- JavaScript / TypeScript via `js-debug-adapter`
- C# via `netcoredbg`
- Unity C# via `vscode-unity-debug`
- Dart / Flutter via `flutter debug-adapter`
- Lua via `one-small-step-for-vimkind`

## Dependencies

This section lists **everything this config expects**.

### Required on every machine

| Dependency | Why it is needed |
| --- | --- |
| **Neovim 0.12+** | `tree-sitter-manager.nvim` requires Neovim 0.12+, and this config also uses newer built-in LSP APIs |
| **Git** | `lazy.nvim` bootstrap, plugin installs, parser clones, Mason registry access |
| **Internet access on first launch** | plugins, Mason packages, and Tree-sitter parsers are downloaded the first time |
| **Node.js 22+** | required by `copilot.lua`, npm-based tooling, and JS/TS workflows |
| **Tree-sitter CLI** | required by `tree-sitter-manager.nvim` |
| **C compiler / build tools** | Tree-sitter parsers are compiled locally |
| **ripgrep (`rg`)** | required for `Snacks.picker.grep()` and `<leader>sg` |
| **.NET SDK (`dotnet`)** | required by `roslyn.nvim`, and the Unity debugger plugin build uses `dotnet msbuild` if `msbuild` is not present |

### Mason prerequisites

`mason.nvim` also expects a working archive/download toolchain:

- **Linux / macOS**
  - `curl` or `wget`
  - `unzip`
  - **GNU** `tar`
  - `gzip`
- **Windows**
  - PowerShell
  - `git`
  - **GNU** `tar`
  - an archive tool such as **7-Zip**

### Installed automatically by this config

On first start, `mason-tool-installer.nvim` will automatically install:

- `delve`
- `js-debug-adapter`
- `lua-language-server`
- `netcoredbg`
- `roslyn`
- `vtsls`

`tree-sitter-manager.nvim` installs these parsers on demand for real file buffers:

- `bash`
- `c_sharp`
- `css`
- `dart`
- `go`
- `gomod`
- `gosum`
- `gowork`
- `html`
- `javascript`
- `json`
- `lua`
- `markdown`
- `markdown_inline`
- `query`
- `tsx`
- `typescript`
- `vim`
- `vimdoc`
- `yaml`

### Feature-specific dependencies

These are not needed for a basic launch, but they **are** required for the related feature to work:

| Dependency | Needed for | Notes |
| --- | --- | --- |
| **GitHub account with Copilot access** | Copilot suggestions | run `:Copilot auth` after first launch |
| **Go toolchain** | Go editing, building, testing, debugging | install `gopls` manually; this config does **not** install it through Mason |
| **`gopls`** | Go LSP | install with `go install golang.org/x/tools/gopls@latest` |
| **Flutter SDK** | Dart / Flutter LSP and debugging | `flutter` must be on `PATH`; run `flutter doctor` |
| **Mono** (Linux/macOS only) | Unity debugging | needed to run `UnityDebug.exe` on non-Windows hosts |
| **`lazygit`** | `<leader>gg` and `<leader>gl` | optional but expected if you use the git UI mappings |
| **tmux 1.8+** | pane navigation with `<C-h/j/k/l>` | optional; you still need the tmux-side bindings from `vim-tmux-navigator` |
| **`wl-clipboard` or `xclip`** (Linux) | system clipboard | this config sets `clipboard=unnamedplus` |
| **local `typescript` package in JS/TS projects** | best TypeScript results | recommended because `vtsls` is configured to prefer the workspace TypeScript SDK |

### Nice to have, but not strictly required

| Dependency | Why |
| --- | --- |
| **`fd` / `fdfind`** | faster file picking; not required because Snacks can fall back to `rg` or `find` |
| **Nerd Font** | avoids broken icons in the UI |

## Install locations

| Platform | Config path |
| --- | --- |
| Linux | `~/.config/nvim` |
| macOS | `~/.config/nvim` |
| Windows | `%LOCALAPPDATA%\nvim` |

## Setup from a clean machine

### Linux

#### Ubuntu / Debian-based

1. Install base packages:

```bash
sudo apt update
sudo apt install -y \
  git curl unzip gzip tar \
  ripgrep fd-find \
  xclip wl-clipboard \
  build-essential ca-certificates
```

`fd-find` installs the `fdfind` binary on Ubuntu, which Snacks can use directly.

2. Install **Neovim 0.12+**. The distro package may lag behind, so the safest route is the official release archive. Example for **x86_64**:

```bash
cd /tmp
curl -LO https://github.com/neovim/neovim/releases/download/stable/nvim-linux-x86_64.tar.gz
sudo rm -rf /opt/nvim-linux-x86_64
sudo tar -C /opt -xzf nvim-linux-x86_64.tar.gz
sudo ln -sf /opt/nvim-linux-x86_64/bin/nvim /usr/local/bin/nvim
nvim --version
```

If you are on ARM64, download the matching Linux ARM64 release asset instead.

3. Install **Node.js 22+**:

```bash
curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
sudo apt install -y nodejs
node -v
npm -v
```

4. Install the **.NET SDK** and **Mono**:

```bash
source /etc/os-release
curl -LO https://packages.microsoft.com/config/ubuntu/$VERSION_ID/packages-microsoft-prod.deb
sudo dpkg -i packages-microsoft-prod.deb
rm packages-microsoft-prod.deb
sudo apt update
sudo apt install -y dotnet-sdk-8.0 mono-complete
dotnet --version
mono --version
```

5. Install the **Tree-sitter CLI**:

```bash
sudo npm install -g tree-sitter-cli
tree-sitter --version
```

6. Put the config in place:

```bash
mkdir -p ~/.config
git clone <your-repo-url> ~/.config/nvim
```

7. Start Neovim once to bootstrap everything:

```bash
nvim ~/.config/nvim/init.lua
```

#### Arch Linux

1. Install the required packages:

```bash
sudo pacman -Syu --noconfirm
sudo pacman -S --needed \
  neovim git curl unzip gzip tar \
  ripgrep fd tree-sitter-cli \
  base-devel \
  nodejs npm \
  dotnet-sdk mono \
  xclip wl-clipboard
```

2. Put the config in place:

```bash
mkdir -p ~/.config
git clone <your-repo-url> ~/.config/nvim
```

3. Start Neovim once:

```bash
nvim ~/.config/nvim/init.lua
```

### macOS

1. Install the Xcode Command Line Tools:

```bash
xcode-select --install
```

2. Install Homebrew if it is not already installed:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

3. Add Homebrew to your shell environment:

- Apple Silicon:

```bash
echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
eval "$(/opt/homebrew/bin/brew shellenv)"
```

- Intel:

```bash
echo 'eval "$(/usr/local/bin/brew shellenv)"' >> ~/.zprofile
eval "$(/usr/local/bin/brew shellenv)"
```

4. Install the required packages:

```bash
brew install neovim git ripgrep fd tree-sitter node dotnet gnu-tar mono
```

Notes:

- `curl`, `unzip`, and `gzip` are already present on macOS.
- Mason expects **GNU tar** on macOS; Homebrew provides that as `gtar`.
- `xcode-select --install` provides the compiler toolchain needed for Tree-sitter parser builds.

5. Put the config in place:

```bash
mkdir -p ~/.config
git clone <your-repo-url> ~/.config/nvim
```

6. Start Neovim once:

```bash
nvim ~/.config/nvim/init.lua
```

### Windows

#### Native Windows

Use **PowerShell** and run the following from an elevated terminal where needed.

1. Install the core tools:

```powershell
winget install --id Git.Git -e
winget install --id Neovim.Neovim -e
winget install --id OpenJS.NodeJS.LTS -e
winget install --id Microsoft.DotNet.SDK.8 -e
winget install --id BurntSushi.ripgrep.MSVC -e
winget install --id sharkdp.fd -e
winget install --id 7zip.7zip -e
winget install --id Microsoft.VisualStudio.2022.BuildTools -e
```

2. In the Visual Studio Build Tools installer, add the **Desktop development with C++** workload. That compiler toolchain is needed for Tree-sitter parser builds.

3. Open a new PowerShell window so the updated `PATH` is loaded, then install the Tree-sitter CLI:

```powershell
npm install -g tree-sitter-cli
tree-sitter --version
```

4. Put the config in place:

```powershell
git clone <your-repo-url> $env:LOCALAPPDATA\nvim
```

5. Start Neovim once:

```powershell
nvim $env:LOCALAPPDATA\nvim\init.lua
```

Windows notes:

- Mason requires **PowerShell**, **git**, **GNU tar**, and an archive tool such as **7-Zip**.
- On many Windows setups, Git + PowerShell + 7-Zip are enough in practice, but the documented Mason requirement is still **GNU tar**. If `:checkhealth mason` complains about `tar`, install a GNU tar implementation and put it on `PATH`.
- `tree-sitter-manager.nvim` is Unix-first. Native Windows works best when `tree-sitter`, the C++ build tools, and your `PATH` are all configured correctly. If parser builds are painful, WSL is usually the smoother fallback.
- You do **not** need Mono on Windows for the Unity debugger. The plugin launches `UnityDebug.exe` directly there.

## First launch checklist

After launching Neovim for the first time:

1. Let `lazy.nvim` install plugins.
2. Let Mason install its managed tools.
3. Open files in the languages you use and let `tree-sitter-manager.nvim` install their parsers on first use.
4. Run:
   - `:checkhealth`
   - `:checkhealth mason`
   - `:checkhealth snacks`
5. Authenticate Copilot with:
   - `:Copilot auth`

The first start can take a while because plugins and Mason-managed tools are downloaded then. Tree-sitter parsers are installed the first time you open a matching real file buffer.

## Extra steps for language-specific workflows

### Go

This config enables `gopls`, but **does not install it automatically**.

1. Install Go.
2. Install `gopls`:

```bash
go install golang.org/x/tools/gopls@latest
```

3. Make sure your Go bin directory is on `PATH`.

- Linux / macOS: usually `$(go env GOPATH)/bin` or `~/go/bin`
- Windows: usually `%USERPROFILE%\go\bin`

Go debugging uses `delve`, which Mason installs automatically.

### JavaScript / TypeScript

`vtsls` is installed automatically by Mason, but projects work best when they also have a local TypeScript dependency:

```bash
npm install --save-dev typescript
```

### C#

`roslyn` and `netcoredbg` are installed automatically by Mason, but you still need:

- `dotnet` on `PATH`
- a working solution / project file for the best C# experience

### Unity

The Unity debugger plugin is part of this config.

- On **all platforms**, its build step needs `msbuild` or `dotnet msbuild`
- On **Linux/macOS**, debugging Unity also needs **Mono**
- On **Windows**, Mono is not needed

### Dart / Flutter

Install the Flutter SDK and put `flutter` on `PATH`. Then run:

```bash
flutter doctor
```

This config uses the Flutter binary for:

- Dart / Flutter LSP startup
- the Dart debug adapter

If you want to actually run apps, you still need the usual Flutter platform toolchains as reported by `flutter doctor` (Android SDK, Xcode, emulators/devices, and so on).

### GitHub Copilot

Copilot is enabled for:

- `cs`
- `dart`
- `go`
- `javascript`
- `javascriptreact`
- `lua`
- `typescript`
- `typescriptreact`

Copilot is disabled for:

- `markdown`
- buffers that are not normal listed files
- `.env`-style files

Use:

```vim
:Copilot auth
```

## Keymaps

### LSP, diagnostics, and search

| Key | Action |
| --- | --- |
| `gd` | go to definition |
| `gD` | go to type definition |
| `gi` | go to implementation |
| `gr` | find references |
| `gb` | go to base / super definition |
| `K` | hover |
| `<C-k>` | signature help |
| `<leader>re` / `<leader>rr` | code actions |
| `<leader>rn` | rename symbol |
| `<leader>f` | format and apply fix/import actions |
| `<leader>sf` | search files |
| `<leader>sg` | live grep |
| `<leader>ss` | workspace symbols |
| `<leader>sd` | document symbols |
| `<leader>sr` | recent files |
| `<leader>q` | next workspace error |
| `]d` / `[d` | next / previous file error |
| `<leader>xx` | workspace diagnostics |
| `<leader>xX` | buffer diagnostics |
| `<leader>xq` | quickfix list |

### Files, git, editing, and debug

| Key | Action |
| --- | --- |
| `-` | open parent directory in Oil |
| `<leader>e` | open Oil in current file directory |
| `<leader>j` | toggle split/join |
| `<leader>J` | recursive split/join |
| `<leader>gg` | open LazyGit |
| `<leader>gl` | open LazyGit log |
| `<leader>tc` | debug continue |
| `<leader>tb` | toggle breakpoint |
| `<leader>tB` | conditional breakpoint |
| `<leader>tp` | pick debug configuration |
| `<leader>ti` | step into |
| `<leader>to` | step over |
| `<leader>tO` | step out |
| `<leader>tr` | toggle DAP REPL |
| `<leader>tu` | toggle debug UI |
| `<leader>tt` | terminate debug session |
| `<leader>ts` | launch Lua debug server |
| `<leader>td` | debug nearest Go test |
| `<Tab>` in insert mode | accept Copilot suggestion if one is visible |

## Notes

- `oil.nvim` is the default file explorer, so `netrw` is disabled.
- The system clipboard is enabled with `clipboard=unnamedplus`.
- `snacks.nvim` provides file picking and grep; `ripgrep` is the only hard requirement there.
- `vim-tmux-navigator` mappings are configured on the Neovim side, but tmux still needs its own companion bindings.
- The config is pinned through `lazy-lock.json`, so first installs and future updates should stay consistent until that lockfile changes.
