# Contributing to Docker App Build Kit

Thank you for considering contributing to Docker App Build Kit! This document provides guidelines for contributing to this project using GitHub's fork and pull request workflow.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Issue Management](#issue-management)
- [Fork and Pull Request Workflow](#fork-and-pull-request-workflow)
- [Development Setup](#development-setup)
- [Testing](#testing)
- [Code Style](#code-style)
- [Documentation](#documentation)
- [Release Process](#release-process)

## Code of Conduct

This project follows a code of conduct to ensure a welcoming environment for all contributors. Please be respectful and professional in all interactions.

## Getting Started

Before contributing, please:

1. **Check existing issues** to see if your bug report or feature request already exists
2. **Create an issue first** before starting work on significant changes
3. **Join the discussion** on existing issues to understand the problem/feature better

## Issue Management

### Creating Issues

**Always create an issue before submitting a pull request.** This helps us:
- Track and prioritize work
- Discuss solutions before implementation
- Avoid duplicate efforts
- Maintain project history

### Issue Types and Labels

We use the following labels to categorize issues. GitHub provides some default labels, and we've added project-specific ones for better organization.

#### Type Labels (Required)
**Default GitHub Labels:**
- 🐛 **`bug`** - Something isn't working correctly
- ✨ **`enhancement`** - New feature or improvement to existing functionality
- 📝 **`documentation`** - Documentation updates or improvements

**Custom Labels:**
- 🔧 **`maintenance`** - Code refactoring, dependency updates, CI/CD improvements
- ❓ **`question`** - Support questions or discussions

#### Priority Labels
- 🚨 **`priority: critical`** - Security issues, data loss, breaking changes
- 🔥 **`priority: high`** - Important features or serious bugs affecting many users
- 📋 **`priority: medium`** - Standard features or bugs (default priority)
- 🔖 **`priority: low`** - Nice to have features or minor bugs

#### Component Labels
- 🐳 **`component: docker`** - Docker-related issues (Dockerfiles, containers)
- 🐘 **`component: php`** - PHP implementation specific issues
- 🐍 **`component: python`** - Python implementation specific issues
- 🟢 **`component: nodejs`** - Node.js implementation specific issues
- 🗃️ **`component: database`** - Database configuration or support
- 🔧 **`component: cli`** - Command line interface issues
- 📦 **`component: build`** - Build system or CI/CD issues
- 🌐 **`component: networking`** - Docker networking issues

#### Status Labels
- 🏷️ **`status: needs-triage`** - New issues that need initial review
- 🤔 **`status: needs-info`** - Waiting for more information from reporter
- ✅ **`status: ready`** - Issue is well-defined and ready for implementation
- 🔄 **`status: in-progress`** - Someone is actively working on this
- ⏳ **`status: blocked`** - Cannot proceed due to external dependency
- 🔍 **`status: needs-review`** - Pull request is ready for review

#### Special Labels
**Default GitHub Labels:**
- 👋 **`good first issue`** - Good for newcomers to the project
- 🎓 **`help wanted`** - We need community help with this issue
- 📋 **`duplicate`** - This issue already exists elsewhere
- 🚫 **`wontfix`** - This issue will not be addressed

**Custom Labels:**
- 💬 **`discussion`** - Needs community discussion before proceeding

### Setting Up Repository Labels

The repository includes a script to automatically create all custom labels:

```bash
# Run from the project root
./scripts/setup-github-labels.ps1

# Or specify a different repository
./scripts/setup-github-labels.ps1 -Repository "your-username/your-fork"

# Dry run to see what would be created
./scripts/setup-github-labels.ps1 -DryRun
```

**Prerequisites:**
- [GitHub CLI](https://cli.github.com/) installed and authenticated
- Repository admin access (for creating labels)

This script will preserve existing default GitHub labels and add the project-specific ones listed above.

### Issue Templates

The repository includes structured issue templates that guide you through creating well-formed issues. When you create a new issue on GitHub, you'll be presented with a template chooser:

**Available Templates:**
- **🐛 Bug Report** - Report bugs with structured environment and reproduction information
- **✨ Feature Request** - Propose new features with problem statements and solutions
- **❓ Question/Support** - Ask questions about usage and configuration
- **🔧 Maintenance** - Suggest refactoring, dependency updates, or maintenance tasks

**Creating an Issue:**
1. Go to [New Issue](https://github.com/dsdobrzynski/dapp-bk/issues/new/choose)
2. Select the appropriate template
3. Fill out all required fields
4. The template will automatically apply relevant labels

**Template Features:**
- Dropdown menus for environment and component selection
- Required and optional fields clearly marked
- Automatic label application based on issue type
- Structured format ensures all necessary information is provided

For more details, see the template files in [.github/ISSUE_TEMPLATE/](.github/ISSUE_TEMPLATE/)

## Fork and Pull Request Workflow

### 1. Fork the Repository

1. Go to https://github.com/dsdobrzynski/dapp-bk
2. Click the "Fork" button in the top-right corner
3. Clone your fork locally:
   ```bash
   git clone https://github.com/YOUR_USERNAME/dapp-bk.git
   cd dapp-bk
   ```

### 2. Set Up Remote Tracking

```bash
# Add the original repository as upstream
git remote add upstream https://github.com/dsdobrzynski/dapp-bk.git

# Verify remotes
git remote -v
```

### 3. Create a Feature Branch

```bash
# Make sure you're on main and it's up to date
git checkout main
git pull upstream main

# Create and switch to a new feature branch
git checkout -b feature/issue-123-add-java-support

# Or for bug fixes:
git checkout -b fix/issue-456-network-timeout
```

**Branch Naming Convention:**
- `feature/issue-###-short-description` for new features
- `fix/issue-###-short-description` for bug fixes
- `docs/issue-###-short-description` for documentation updates
- `refactor/issue-###-short-description` for code refactoring

### 4. Make Changes

- Write clear, focused commits
- Follow the existing code style
- Add tests for new functionality
- Update documentation as needed

### 5. Commit Your Changes

```bash
# Stage your changes
git add .

# Commit with a descriptive message
git commit -m "Add Java application support

- Add Dockerfile-app-java with OpenJDK 17
- Add Java-specific build logic to all implementations
- Add Java configuration examples to README
- Add tests for Java container builds

Fixes #123"
```

**Commit Message Format:**
```
Short summary (50 chars or less)

More detailed explanation if needed. Wrap at 72 characters.
Explain what was changed and why, not how.

- Use bullet points for multiple changes
- Reference issues with "Fixes #123" or "Closes #123"
- Use imperative mood: "Add feature" not "Added feature"
```

### 6. Push to Your Fork

```bash
git push origin feature/issue-123-add-java-support
```

### 7. Create a Pull Request

1. Go to your fork on GitHub
2. Click "Compare & pull request" button
3. The PR template will automatically load with sections for:
   - Description and related issue
   - Type of change checkboxes
   - Testing information and results
   - Documentation updates
   - Comprehensive review checklist
4. Fill out all relevant sections of the template
5. Ensure all checklist items are addressed

The PR template includes:
- **Change description** - What was changed and why
- **Testing checklist** - Verification that tests pass and new tests are added
- **Documentation** - Ensuring docs are updated
- **Configuration changes** - Documenting any .env or config changes
- **Breaking changes** - Clear migration path if applicable
- **Review checklist** - Code style, comments, self-review

For the complete PR template, see [.github/pull_request_template.md](.github/pull_request_template.md)

### 8. Code Review Process

1. **Automated Checks**: Wait for CI/CD to complete
2. **Maintainer Review**: A maintainer will review your PR
3. **Address Feedback**: Make requested changes if needed
4. **Approval**: Once approved, your PR will be merged

### 9. Keep Your Fork Updated

```bash
# Regularly sync with upstream
git checkout main
git pull upstream main
git push origin main

# Update your feature branch if needed
git checkout feature/issue-123-add-java-support
git rebase main
```

## Development Setup

### Prerequisites

Ensure you have the required tools for your preferred implementation:

**For PHP Development:**
- PHP >= 7.4
- Composer
- PHPUnit for testing

**For Python Development:**
- Python >= 3.7
- pip
- pytest for testing

**For Node.js Development:**
- Node.js >= 16.0.0
- npm
- Jest for testing

**All Implementations:**
- Docker Desktop
- Git

### Local Development Setup

1. **Clone and setup:**
   ```bash
   git clone https://github.com/YOUR_USERNAME/dapp-bk.git
   cd dapp-bk
   ```

2. **For PHP development:**
   ```bash
   composer install
   composer test
   ```

3. **For Python development:**
   ```bash
   pip install -e .
   pip install -r requirements-dev.txt
   pytest
   ```

4. **For Node.js development:**
   ```bash
   npm install
   npm test
   ```

5. **Test all implementations:**
   ```bash
   # Test PHP version
   php bin/dapp-bk build --help

   # Test Python version  
   dapp-bk-py build --help

   # Test Node.js version
   node nodejs/bin/dapp-bk-node.js build --help
   ```

## Testing

### Running Tests

**PHP:**
```bash
composer test                    # Run all tests
composer test -- --filter=SomeTest  # Run specific test
```

**Python:**
```bash
pytest                          # Run all tests
pytest tests/test_cli.py        # Run specific test file
pytest -v                       # Verbose output
```

**Node.js:**
```bash
npm test                        # Run all tests
npm test -- --testNamePattern="build"  # Run specific tests
```

### Test Requirements

- **Unit Tests**: All new functionality must have unit tests
- **Integration Tests**: Complex features should have integration tests
- **Manual Testing**: Test your changes with real Docker containers
- **Cross-Platform**: Test on different operating systems when possible

### Test Structure

```
tests/
├── php/
│   ├── Unit/
│   │   ├── Commands/
│   │   └── Services/
│   └── Integration/
├── python/
│   ├── unit/
│   └── integration/
└── nodejs/
    ├── unit/
    └── integration/
```

## Code Style

### PHP Code Style
- Follow PSR-12 coding standard
- Use meaningful variable and method names
- Add PHPDoc blocks for all public methods
- Run code style fixer: `composer cs-fix`

### Python Code Style
- Follow PEP 8 style guide
- Use type hints where appropriate
- Add docstrings for all public functions and classes
- Run linter: `flake8` and formatter: `black`

### Node.js Code Style
- Follow JavaScript Standard Style
- Use meaningful variable and function names
- Add JSDoc comments for complex functions
- Run linter: `npm run lint`

### General Guidelines
- Keep functions small and focused
- Use descriptive commit messages
- Write self-documenting code
- Add comments for complex business logic

## Documentation

### Documentation Standards

- **README.md**: Keep up-to-date with new features
- **CHANGELOG.md**: Document all changes following [Keep a Changelog](https://keepachangelog.com/)
- **Code Comments**: Document complex logic and business rules
- **API Documentation**: Document all public APIs and CLI commands

### Documentation Updates Required

When making changes, ensure you update:

1. **README.md** - For new features or changed usage
2. **CHANGELOG.md** - For all user-facing changes
3. **Code Documentation** - For new public APIs
4. **.env.example** - For new configuration options
5. **Error Messages** - Should be clear and actionable

## Release Process

Releases are managed by maintainers, but here's the process:

1. **Version Bump**: Update version in all package files
2. **Changelog**: Update CHANGELOG.md with release notes
3. **Testing**: Comprehensive testing across all implementations
4. **Tagging**: Create git tag following semantic versioning
5. **Publishing**: 
   - PHP: Publish to Packagist
   - Python: Publish to PyPI
   - Node.js: Publish to npm registry
6. **GitHub Release**: Create GitHub release with notes

### Semantic Versioning

We follow [Semantic Versioning](https://semver.org/):
- **MAJOR**: Breaking changes
- **MINOR**: New features (backward compatible)
- **PATCH**: Bug fixes (backward compatible)

## Questions and Support

- **General Questions**: Open a GitHub issue with the `question` label
- **Implementation Help**: Check existing issues or create a new one
- **Security Issues**: Email maintainers directly (see SECURITY.md)
- **Feature Discussions**: Use GitHub Discussions

## Recognition

Contributors will be recognized in:
- CHANGELOG.md for their contributions
- GitHub contributors section
- Special recognition for significant contributions

---

Thank you for contributing to Docker App Build Kit! Your help makes this project better for everyone. 🚀