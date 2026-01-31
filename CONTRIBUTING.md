# Contributing to updateLITE Arch Edition

Thank you for your interest in contributing to updateLITE Arch Edition.

## Code of Conduct

Be respectful and constructive. We're all here to make a useful tool.

## How to Contribute

### Reporting Bugs

1. Check if the issue already exists
2. Include your system info: `updatelite --version`
3. Describe steps to reproduce
4. Include relevant error messages

### Suggesting Features

1. Check existing issues for similar requests
2. Describe the use case clearly
3. Explain why it would benefit users

### Pull Requests

1. Fork the repository
2. Create a feature branch: `git checkout -b feat/my-feature`
3. Make your changes
4. Test on Arch Linux
5. Run shellcheck: `shellcheck updatelite lib/*.sh`
6. Commit with a clear message
7. Push and create a PR

## Commit Messages

Use conventional commit format:

```
feat: add new feature
fix: resolve bug in X
docs: update README
refactor: improve code structure
test: add test for X
```

## Coding Standards

### Shell Scripts

- Use Bash 4.0+ features only
- Always quote variables: `"$var"` not `$var`
- Use `[[ ]]` for tests, not `[ ]`
- Prefer `$(command)` over backticks
- Add comments for non-obvious logic
- Run shellcheck before committing

### File Structure

- Core utilities go in `lib/utils.sh`
- Each module should be self-contained
- New modules need documentation

### Functions

```bash
# Good
my_function() {
    local var="$1"
    # ...
}

# Bad
function my_function {
    var=$1
    # ...
}
```

## Testing

Before submitting:

1. Test on a clean Arch Linux installation
2. Test with `--dry-run` flag
3. Verify all modules can be disabled
4. Check that errors are handled gracefully

## Questions

Open an issue with the "question" label.
