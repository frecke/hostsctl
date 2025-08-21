# hostsctl
Tiny zsh CLI to manage `/etc/hosts` on macOS — add/remove/list, enable/disable by tag, and DNS flush.  
“Managed” lines are labeled with `# hs:<tag>` so you can toggle whole sets safely.

- Safe: auto backup once per run
- Fast: instant DNS cache flush
- Focused: only touches `# hs:<tag>` lines

## Install

### Homebrew (recommended)
```zsh
brew tap frecke/tap
brew install hostsctl
```

### Manual
```zsh
mkdir -p ~/bin
curl -fsSL https://raw.githubusercontent.com/frecke/hostsctl/main/bin/hostsctl.zsh -o ~/bin/hostsctl.zsh
chmod +x ~/bin/hostsctl.zsh
echo 'alias hostsctl="zsh ~/bin/hostsctl.zsh"' >> ~/.zshrc
echo 'alias hs=hostsctl' >> ~/.zshrc
source ~/.zshrc
```

## Usage
```zsh
hs add <ip> <host> [alias ...] [-t tag]
hs rm (<host>... | --tag <tag>)
hs on <tag>
hs off <tag>
hs list [tag]
hs flush
hs backup
hs --version
```

### Examples
```zsh
hs add 127.0.0.1 local.test api.local.test -t demo
hs list
hs off demo
hs on demo
hs rm --tag demo
hs flush
```

### macOS permissions
Editing `/etc/hosts` needs `sudo`. `hostsctl` runs `cp/dscacheutil/killall` `mDNSResponder` with sudo.
You’ll be prompted the first time in a session.

## Testing
```zsh
brew install bats-core shellcheck shfmt
make test
```

## Dev
* Lint: make lint (shellcheck, shfmt)
* Format: make format
* Bump version: edit VERSION in bin/hostsctl.zsh, then make tag
* Release: push tag → GitHub Action publishes tarball + sha256

### Env toggles (for CI/dev)
* HOSTS_FILE=/path override target file
* SUDO= disable sudo
* SKIP_FLUSH=1 skip DNS flush
* DRY_RUN=1 don’t write to /etc/hosts, print intent

### Why tags?
Every managed line ends with `# hs:<tag>`. You can group and toggle whole stacks:
```text
1.2.3.4 foo.local bar.local  # hs:work
````
Then `hs off work` comments those lines; `hs on work` restores them.


---

## LICENSE (MIT)

```text
Copyright 2025 Fredrik Rundgren

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the “Software”), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
```
