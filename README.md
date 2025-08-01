# Anti-Eneo

Anti-Eneo is a tool to save your work periodically on a git repo by committing and pushing your work.


## How it works

Anti-Eneo comes with a bash command `anti-eneo`, once you run it:

at the start

- it checks the current branch if the current branch is not `anti-eneo` create a branch named `anti-eneo` and checkout to it

then it sleeps and every 3 min (the interval is configurable with --interval=X)
it will do:

 - `git commit -am "periodic changes"` to commit the current changes
 - check the result of the commit command, if no commit was done do nothing
 - if a commit happened it will push to the `anti-eneo` branch


 Anti-Eneo comes with another bash command `anti-eneo-watch`, once you run it:

 at the start

- it checks the current branch if the current branch is not `anti-eneo` create a branch named `anti-eneo` and checkout to it

then it starts watching the repository, when a file followed by git is modified or created, 
it waits for 1 min (debounce configurable with --debounce=X)) to see if another changes happened then

 - `git commit -am "periodic changes"` to commit the current changes
 - check the result of the commit command, if no commit was done do nothing
 - if a commit happened it will push to the `anti-eneo` branch


## Installation

### Linux and macOS

Run the following command in your terminal:

```bash
curl -fsSL https://raw.githubusercontent.com/jefcolbi/anti-eneo/main/install.sh | bash
```

Or if you prefer wget:

```bash
wget -qO- https://raw.githubusercontent.com/jefcolbi/anti-eneo/main/install.sh | bash
```

The installer will:
- Clone the repository to `~/.local/bin/anti-eneo`
- Create symlinks for `anti-eneo` and `anti-eneo-watch` commands
- Automatically update your shell configuration to include `~/.local/bin` in PATH
- Work without requiring root privileges

To update to the latest version, simply run the installer again.

### Windows

#### Option 1: Using Git Bash or WSL

If you have Git Bash or WSL (Windows Subsystem for Linux) installed, follow the Linux installation instructions above.

#### Option 2: Manual Installation

1. Clone the repository:
   ```cmd
   git clone https://github.com/jefcolbi/anti-eneo %USERPROFILE%\.local\bin\anti-eneo
   ```

2. Add the directory to your PATH:
   - Press Win + X and select "System"
   - Click "Advanced system settings"
   - Click "Environment Variables"
   - Under "User variables", select "Path" and click "Edit"
   - Click "New" and add: `%USERPROFILE%\.local\bin\anti-eneo`
   - Click "OK" to save

3. Restart your terminal

### Manual Installation (All Platforms)

1. Clone the repository:
   ```bash
   git clone https://github.com/jefcolbi/anti-eneo ~/.local/bin/anti-eneo
   ```

2. Make scripts executable (Linux/macOS):
   ```bash
   chmod +x ~/.local/bin/anti-eneo/anti-eneo
   chmod +x ~/.local/bin/anti-eneo/anti-eneo-watch
   ```

3. Add to PATH by adding this line to your shell configuration:
   ```bash
   export PATH="$HOME/.local/bin/anti-eneo:$PATH"
   ```

## Usage

After installation, you can use the following commands:

- `anti-eneo` - Periodically saves your work every 3 minutes
- `anti-eneo-watch` - Watches for file changes and saves automatically

### Options

- `--interval=X` - Set the interval in minutes for periodic saves (default: 3)
- `--debounce=X` - Set the debounce time in minutes for watch mode (default: 1)



