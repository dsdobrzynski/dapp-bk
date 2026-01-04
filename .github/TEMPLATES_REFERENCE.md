# GitHub Templates Quick Reference

This document provides a quick reference for using the GitHub issue and PR templates.

## Issue Templates

### When to Use Each Template

| Template | Use When | Auto Labels |
|----------|----------|-------------|
| 🐛 **Bug Report** | Something isn't working correctly | `bug`, `status: needs-triage` |
| ✨ **Feature Request** | Suggesting new functionality or improvements | `enhancement`, `status: needs-triage` |
| ❓ **Question/Support** | Need help or have usage questions | `question`, `status: needs-triage` |
| 🔧 **Maintenance** | Code refactoring, dependencies, or CI/CD | `maintenance`, `status: needs-triage` |

### Creating Issues

1. Go to: https://github.com/dsdobrzynski/dapp-bk/issues/new/choose
2. Select the appropriate template
3. Fill in all required fields (marked with red asterisk)
4. Submit the issue

### Template Features

All templates include:
- ✅ Guided forms with dropdowns and checkboxes
- ✅ Required and optional field validation
- ✅ Automatic label application
- ✅ Environment and version tracking
- ✅ Pre-submission checklist

### Quick Links

**Documentation & Help:**
- 📖 README: Check usage instructions first
- 💬 Discussions: For general questions and discussions
- 🔒 Security: Report vulnerabilities privately

These links appear in the issue template chooser.

## Pull Request Template

### When Creating a PR

The PR template automatically loads when you create a pull request from your fork.

### Template Sections

1. **Description** - What changed and why
2. **Related Issue** - Link to the issue this PR addresses
3. **Type of Change** - Bug fix, feature, breaking change, etc.
4. **Testing** - Environment tested, test cases, results
5. **Documentation** - What docs were updated
6. **Checklist** - Code style, self-review, tests, etc.

### Key Checklist Items

Before submitting your PR, ensure:

- [ ] Code follows project style guidelines
- [ ] Self-review completed
- [ ] Code is commented where needed
- [ ] Documentation updated
- [ ] Tests added and passing
- [ ] No new warnings or errors

### Breaking Changes

If your PR includes breaking changes:

1. Check the "Breaking change" box
2. Fill out the "Breaking Changes" section
3. Provide migration guide for users
4. Document what breaks and why

## Verification Script

Use the verification script to check templates are set up correctly:

```powershell
# Verify all templates exist
.\scripts\setup-github-templates.ps1

# Show directory structure
.\scripts\setup-github-templates.ps1 -ShowStructure

# Validate YAML syntax
.\scripts\setup-github-templates.ps1 -ValidateYaml
```

## Template Customization

### Adding New Templates

To add a new issue template:

1. Create a new `.yml` file in `.github/ISSUE_TEMPLATE/`
2. Follow the [GitHub issue forms syntax](https://docs.github.com/en/communities/using-templates-to-encourage-useful-issues-and-pull-requests/syntax-for-issue-forms)
3. Add it to `config.yml` if needed
4. Update this reference guide

### Modifying Existing Templates

To modify templates:

1. Edit the relevant `.yml` or `.md` file
2. Test changes by creating a test issue/PR
3. Commit and push changes
4. Templates update automatically on GitHub

## Common Fields

### Environment Information

Most templates ask for:
- **OS**: Windows, Linux, macOS, WSL2
- **Docker Version**: From `docker --version`
- **DAPP-BK Version**: From package manager or git tag
- **Implementation**: PHP, Python, or Node.js

### Component Selection

Available components:
- Docker/Containers
- PHP Implementation
- Python Implementation
- Node.js Implementation
- Database Support
- CLI Commands
- Build System
- Networking
- Documentation

### Priority Levels

When applicable:
- **Critical**: Security, data loss, breaking changes
- **High**: Important features, serious bugs
- **Medium**: Standard priority (default)
- **Low**: Nice to have, minor issues

## Tips for Quality Issues

### Bug Reports

✅ **Do:**
- Include full error messages and logs
- Provide exact steps to reproduce
- Share relevant `.env` configuration (sanitized)
- Test with latest version first

❌ **Don't:**
- Leave required fields empty
- Use vague descriptions like "it doesn't work"
- Skip environment information
- Submit duplicates without searching first

### Feature Requests

✅ **Do:**
- Explain the problem you're solving
- Describe the use case clearly
- Consider alternative solutions
- Check if feature already exists

❌ **Don't:**
- Request features outside project scope
- Skip the "problem statement" section
- Ignore existing similar requests
- Provide vague requirements

### Pull Requests

✅ **Do:**
- Reference the related issue
- Fill out all template sections
- Test thoroughly before submitting
- Update documentation
- Add tests for new functionality

❌ **Don't:**
- Submit PRs without related issues
- Skip the testing section
- Ignore failing tests
- Leave the template mostly empty
- Make unrelated changes

## Label System Integration

Templates automatically apply initial labels:

| Template | Initial Labels |
|----------|----------------|
| Bug Report | `bug`, `status: needs-triage` |
| Feature Request | `enhancement`, `status: needs-triage` |
| Question | `question`, `status: needs-triage` |
| Maintenance | `maintenance`, `status: needs-triage` |

Maintainers will add additional labels during triage:
- **Priority labels**: `priority: critical/high/medium/low`
- **Component labels**: `component: docker/php/python/nodejs/etc`
- **Status labels**: Updated as work progresses

## Resources

- **GitHub Templates Docs**: https://docs.github.com/en/communities/using-templates-to-encourage-useful-issues-and-pull-requests
- **Issue Forms Syntax**: https://docs.github.com/en/communities/using-templates-to-encourage-useful-issues-and-pull-requests/syntax-for-issue-forms
- **Contributing Guide**: See [CONTRIBUTING.md](../CONTRIBUTING.md)
- **Label Reference**: See label section in [CONTRIBUTING.md](../CONTRIBUTING.md#issue-types-and-labels)

## Getting Help

If you need help with templates:

1. Check this reference guide
2. Read [CONTRIBUTING.md](../CONTRIBUTING.md)
3. Ask in [GitHub Discussions](https://github.com/dsdobrzynski/dapp-bk/discussions)
4. Create a `question` issue

---

**Last Updated**: January 2026
