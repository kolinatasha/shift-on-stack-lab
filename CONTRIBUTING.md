# Contributing to Shift-on-Stack Lab

Thanks for your interest in contributing!

## Getting Started

1. Fork the repository
2. Clone your fork: `git clone https://github.com/YOUR_USERNAME/shift-on-stack-lab.git`
3. Create a feature branch: `git checkout -b feature/your-feature-name`
4. Make your changes
5. Test your changes thoroughly
6. Commit with clear messages
7. Push and create a pull request

## Code Standards

### Shell Scripts

- Use bash strict mode: `set -euo pipefail`
- Include descriptive function names
- Add comments for complex logic
- Use consistent logging format: `[TIMESTAMP] LEVEL: message`
- Exit codes: 0 for success, non-zero for failure

### Documentation

- Keep docs up-to-date with code changes
- Use clear, concise language
- Include examples where helpful
- Update FAILURE-MATRIX.md for new failure scenarios

### Commits

Follow conventional commit format:

- `feat:` new feature
- `fix:` bug fix
- `docs:` documentation changes
- `chore:` maintenance tasks
- `refactor:` code refactoring

Example: `feat: add network MTU validation check`

## Testing

Before submitting:

1. Run `make bootstrap` on a clean environment
2. Test `make openstack-up` and `make validate`
3. Verify documentation accuracy
4. Check that scripts handle errors gracefully

## Pull Request Process

1. Update README.md if adding new features
2. Add/update relevant documentation
3. Ensure all scripts pass shellcheck (if available)
4. Describe your changes clearly in the PR description
5. Link any related issues

## Reporting Issues

When reporting issues, include:

- Environment details (OS, RAM, CPU)
- Steps to reproduce
- Expected vs actual behavior
- Relevant logs from `artifacts/logs/`
- Output of `make validate`

## Questions?

Open an issue with the `question` label.
