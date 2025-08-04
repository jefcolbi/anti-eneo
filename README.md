# Anti-Eneo

Anti-Eneo is a tool to automatically save your work on a git repository by committing and pushing changes periodically or when files change. It keeps your work safe by maintaining a rolling backup of your recent changes.

## Key Features

- **Automatic Backup**: Periodically commits and pushes your changes to keep work safe
- **Rolling Window**: Maintains only the 2 most recent commits to avoid cluttering history
- **Watch Mode**: Monitors file changes and commits automatically with debouncing
- **Save-to-Branch**: Squash merge all changes to any target branch with a single command
- **Graceful Shutdown**: Commits pending changes when stopped (Ctrl+C)
- **Branch Isolation**: Works on a dedicated `anti-eneo` branch to avoid interfering with your main workflow

## How it works

### Periodic Mode (Default)
When you run `anti-eneo`:

**At startup:**
- Checks if you're on the `anti-eneo` branch, creates and switches to it if needed
- Sets up remote tracking

**Every 3 minutes (configurable):**
- Commits all changes with timestamp: `git add . && git commit -m "periodic changes YYYY-MM-DD HH:MM:SS"`
- Pushes to the remote `anti-eneo` branch
- **Rolling window**: Keeps only 2 most recent commits by removing older ones

### Watch Mode
When you run `anti-eneo --watch`:

**At startup:**
- Same branch setup as periodic mode

**On file changes:**
- Detects when git-tracked files are modified, added, or deleted
- Waits for debounce period (60 seconds by default) to batch multiple rapid changes
- Commits and pushes the batched changes
- Also maintains the 2-commit rolling window

### Save-to-Branch Feature
Use `anti-eneo --save-to=BRANCH` to merge all your work to any branch:

- **Validates** you're on the `anti-eneo` branch
- **Switches** to the target branch and pulls latest changes
- **Squash merges** all changes from `anti-eneo` into a single commit
- **Prompts** for a meaningful commit message
- **Pushes** to remote and returns to `anti-eneo` branch

This is perfect for moving your work to `main`, `develop`, or feature branches when ready.


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
- Create symlink for the `anti-eneo` command
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

2. Make script executable (Linux/macOS):
   ```bash
   chmod +x ~/.local/bin/anti-eneo/anti-eneo
   ```

3. Add to PATH by adding this line to your shell configuration:
   ```bash
   export PATH="$HOME/.local/bin/anti-eneo:$PATH"
   ```

## Usage

### Basic Commands

```bash
# Start periodic backup (every 3 minutes)
anti-eneo

# Start file watching mode with automatic commits
anti-eneo --watch

# Save all changes to main branch
anti-eneo --save-to=main

# Save all changes to develop branch  
anti-eneo --save-to=develop

# Show help
anti-eneo --help
```

### All Options

| Option | Description | Default |
|--------|-------------|---------|
| `--interval=SECONDS` | Commit interval for periodic mode | 180 (3 minutes) |
| `--watch` | Enable watch mode for file change detection | Off |
| `--debounce=SECONDS` | Debounce time for watch mode | 60 seconds |
| `--save-to=BRANCH` | Save all changes to target branch and exit | - |
| `--branch=NAME` | Custom branch name for auto-saves | anti-eneo |
| `--remote=NAME` | Remote name to push to | origin |
| `--quiet, -q` | Suppress informational output | Off |
| `--help, -h` | Show usage information | - |

### Examples

```bash
# Quick start - periodic backup every 3 minutes
anti-eneo

# Watch mode with custom debounce
anti-eneo --watch --debounce=30

# Periodic mode with custom interval (every 5 minutes)
anti-eneo --interval=300

# Save work to main branch when ready
anti-eneo --save-to=main
# (prompts for commit message)

# Custom branch and remote
anti-eneo --branch=my-backup --remote=upstream

# Quiet mode
anti-eneo --quiet
```

### Typical Workflow

1. **Start anti-eneo** in your project directory:
   ```bash
   anti-eneo --watch  # or just 'anti-eneo' for periodic mode
   ```

2. **Work normally** - your changes are automatically backed up to the `anti-eneo` branch

3. **When ready to commit to main**:
   ```bash
   anti-eneo --save-to=main
   # Enter a meaningful commit message when prompted
   ```

4. **Continue working** - anti-eneo keeps running and backing up new changes

5. **Stop safely** with Ctrl+C - any pending changes are committed before exit

## Development & Testing

Anti-Eneo includes a comprehensive test suite to ensure reliability:

```bash
# Run all tests
./tests/run-all-tests.sh

# Run specific test suites
./tests/test-basic.sh              # Basic functionality
./tests/test-save-to.sh            # Save-to-branch feature
./tests/test-graceful-shutdown.sh  # Graceful shutdown
./tests/test-watch-mode.sh         # Watch mode functionality

# Run single test suite
./tests/run-all-tests.sh --suite=test-basic.sh
```

The test suite covers:
- ✅ Periodic commit functionality
- ✅ Rolling window behavior (2-commit limit)  
- ✅ Branch management and creation
- ✅ Save-to-branch feature with validation
- ✅ Graceful shutdown with pending changes
- ✅ Watch mode file detection
- ✅ Error handling and edge cases

## Troubleshooting

### Common Issues

**"Not a git repository"**
- Make sure you're in a git repository directory
- Run `git init` if you need to create a new repository

**Push failed**
- Check your remote repository configuration: `git remote -v`
- Ensure you have push permissions to the remote repository
- Verify your git credentials are set up correctly

**Branch conflicts**
- Anti-eneo works on the `anti-eneo` branch to avoid conflicts
- Use `--save-to=main` to merge changes to your main branch when ready

**Permission denied**
- Make sure the anti-eneo script is executable: `chmod +x anti-eneo`
- Check that `~/.local/bin` is in your PATH

### Debug Mode

For troubleshooting, remove the `--quiet` flag to see detailed logging:

```bash
anti-eneo                    # Shows all INFO messages
anti-eneo --quiet           # Shows only ERROR messages
```



