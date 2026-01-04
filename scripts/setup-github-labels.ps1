#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Setup GitHub repository labels for Docker App Build Kit project
.DESCRIPTION
    This script creates custom labels for issue management using GitHub CLI.
    It preserves existing default labels and adds project-specific ones.
.EXAMPLE
    .\setup-github-labels.ps1
    .\setup-github-labels.ps1 -Repository "dsdobrzynski/dapp-bk"
#>

param(
    [string]$Repository = "dsdobrzynski/dapp-bk",
    [switch]$DryRun = $false,
    [switch]$DeleteExisting = $false
)

# Check if GitHub CLI is installed
try {
    $null = gh --version
    Write-Host "✅ GitHub CLI is available" -ForegroundColor Green
} catch {
    Write-Error "❌ GitHub CLI (gh) is not installed or not in PATH. Please install from: https://cli.github.com/"
    exit 1
}

# Check if user is authenticated
try {
    $null = gh auth status 2>$null
    Write-Host "✅ GitHub CLI is authenticated" -ForegroundColor Green
} catch {
    Write-Error "❌ Not authenticated with GitHub CLI. Please run: gh auth login"
    exit 1
}

Write-Host "🏷️  Setting up labels for repository: $Repository" -ForegroundColor Cyan

# Define default GitHub labels (verify these exist, create if missing)
$defaultLabels = @(
    @{
        name = "bug"
        color = "d73a4a"
        description = "Something isn't working"
    },
    @{
        name = "enhancement"
        color = "a2eeef"
        description = "New feature or request"
    },
    @{
        name = "documentation"
        color = "0075ca"
        description = "Improvements or additions to documentation"
    },
    @{
        name = "duplicate"
        color = "cfd3d7"
        description = "This issue or pull request already exists"
    },
    @{
        name = "good first issue"
        color = "7057ff"
        description = "Good for newcomers"
    },
    @{
        name = "help wanted"
        color = "008672"
        description = "Extra attention is needed"
    },
    @{
        name = "wontfix"
        color = "ffffff"
        description = "This will not be worked on"
    }
)

# Define custom labels to create (excluding default GitHub labels)
$customLabels = @(
    # Type Labels (additional to defaults: bug, enhancement, documentation)
    @{
        name = "maintenance"
        color = "fbca04"
        description = "Code refactoring, dependency updates, CI/CD improvements"
    },
    @{
        name = "question"
        color = "d876e3"
        description = "Support questions or discussions"
    },

    # Priority Labels
    @{
        name = "priority: critical"
        color = "b60205"
        description = "Security issues, data loss, breaking changes"
    },
    @{
        name = "priority: high"
        color = "d93f0b"
        description = "Important features or serious bugs affecting many users"
    },
    @{
        name = "priority: medium"
        color = "fbca04"
        description = "Standard features or bugs (default priority)"
    },
    @{
        name = "priority: low"
        color = "0e8a16"
        description = "Nice to have features or minor bugs"
    },

    # Component Labels
    @{
        name = "component: docker"
        color = "0052cc"
        description = "Docker-related issues (Dockerfiles, containers)"
    },
    @{
        name = "component: php"
        color = "4f5d95"
        description = "PHP implementation specific issues"
    },
    @{
        name = "component: python"
        color = "3572a5"
        description = "Python implementation specific issues"
    },
    @{
        name = "component: nodejs"
        color = "f1e05a"
        description = "Node.js implementation specific issues"
    },
    @{
        name = "component: database"
        color = "5319e7"
        description = "Database configuration or support"
    },
    @{
        name = "component: cli"
        color = "1d76db"
        description = "Command line interface issues"
    },
    @{
        name = "component: build"
        color = "c2e0c6"
        description = "Build system or CI/CD issues"
    },
    @{
        name = "component: networking"
        color = "bfd4f2"
        description = "Docker networking issues"
    },

    # Status Labels
    @{
        name = "status: needs-triage"
        color = "ededed"
        description = "New issues that need initial review"
    },
    @{
        name = "status: needs-info"
        color = "d4c5f9"
        description = "Waiting for more information from reporter"
    },
    @{
        name = "status: ready"
        color = "0e8a16"
        description = "Issue is well-defined and ready for implementation"
    },
    @{
        name = "status: in-progress"
        color = "fbca04"
        description = "Someone is actively working on this"
    },
    @{
        name = "status: blocked"
        color = "b60205"
        description = "Cannot proceed due to external dependency"
    },
    @{
        name = "status: needs-review"
        color = "0052cc"
        description = "Pull request is ready for review"
    },

    # Special Labels (additional to defaults: good first issue, help wanted, duplicate, wontfix)
    @{
        name = "discussion"
        color = "e4e669"
        description = "Needs community discussion before proceeding"
    }
)

Write-Host "`n📋 Verifying default GitHub labels..." -ForegroundColor Yellow
Write-Host "   These standard labels should exist (will create if missing):" -ForegroundColor Gray
$defaultLabels | ForEach-Object { Write-Host "   • $($_.name)" -ForegroundColor Gray }

Write-Host "`n🆕 Custom labels to create:" -ForegroundColor Yellow
$customLabels | ForEach-Object { Write-Host "   • $($_.name)" -ForegroundColor Gray }

if ($DryRun) {
    Write-Host "`n🔍 DRY RUN MODE - No labels will be created" -ForegroundColor Yellow
    Write-Host "   Remove -DryRun flag to actually create labels" -ForegroundColor Gray
    exit 0
}

# Confirm before proceeding
Write-Host "`n❓ Do you want to verify/create default labels and add $($customLabels.Count) custom labels? [Y/n]: " -ForegroundColor Cyan -NoNewline
$confirm = Read-Host
if ($confirm -eq 'n' -or $confirm -eq 'no') {
    Write-Host "❌ Cancelled by user" -ForegroundColor Red
    exit 0
}

# Verify and create default labels
Write-Host "`n🔍 Verifying default GitHub labels..." -ForegroundColor Cyan
$defaultCreated = 0
$defaultExisted = 0
$defaultErrors = 0

foreach ($label in $defaultLabels) {
    try {
        # Try to create the label (will fail if it exists)
        gh label create "$($label.name)" `
            --color "$($label.color)" `
            --description "$($label.description)" `
            --repo $Repository 2>&1 | Out-Null

        Write-Host "   ✅ Created: $($label.name)" -ForegroundColor Green
        $defaultCreated++
    }
    catch {
        if ($_.Exception.Message -like "*already exists*") {
            Write-Host "   ✓  Exists: $($label.name)" -ForegroundColor DarkGray
            $defaultExisted++
        } else {
            Write-Host "   ❌ Error: $($label.name) - $($_.Exception.Message)" -ForegroundColor Red
            $defaultErrors++
        }
    }
}

# Create custom labels
Write-Host "`n🚀 Creating custom labels..." -ForegroundColor Green
$created = 0
$skipped = 0
$errors = 0

foreach ($label in $customLabels) {
    try {
        if ($DeleteExisting) {
            # Try to delete existing label first (ignore errors)
            gh label delete "$($label.name)" --repo $Repository --yes 2>$null
        }
        
        # Create the label
        gh label create "$($label.name)" `
            --color "$($label.color)" `
            --description "$($label.description)" `
            --repo $Repository

        Write-Host "   ✅ Created: $($label.name)" -ForegroundColor Green
        $created++
    }
    catch {
        if ($_.Exception.Message -like "*already exists*") {
            Write-Host "   ⏭️  Exists: $($label.name)" -ForegroundColor Yellow
            $skipped++
        } else {
            Write-Host "   ❌ Error: $($label.name) - $($_.Exception.Message)" -ForegroundColor Red
            $errors++
        }
    }
}

# Summary
Write-Host "`n📊 Summary:" -ForegroundColor Cyan
Write-Host "   Default Labels:" -ForegroundColor White
Write-Host "     • Already existed: $defaultExisted labels" -ForegroundColor DarkGray
Write-Host "     • Created: $defaultCreated labels" -ForegroundColor Green
Write-Host "     • Errors: $defaultErrors labels" -ForegroundColor Red
Write-Host "   Custom Labels:" -ForegroundColor White
Write-Host "     • Created: $created labels" -ForegroundColor Green
Write-Host "     • Skipped: $skipped labels (already existed)" -ForegroundColor Yellow
Write-Host "     • Errors: $errors labels" -ForegroundColor Red

$totalErrors = $defaultErrors + $errors
if ($totalErrors -eq 0) {
    Write-Host "`n🎉 Label setup completed successfully!" -ForegroundColor Green
    Write-Host "   Total labels verified/created: $($defaultExisted + $defaultCreated + $created + $skipped)" -ForegroundColor Gray
    Write-Host "   View labels at: https://github.com/$Repository/labels" -ForegroundColor Gray
} else {
    Write-Host "`n⚠️  Label setup completed with errors. Check the output above." -ForegroundColor Yellow
}

# Show next steps
Write-Host "`n📝 Next Steps:" -ForegroundColor Cyan
Write-Host "   1. Review labels at: https://github.com/$Repository/labels" -ForegroundColor Gray
Write-Host "   2. Create issue templates in .github/ISSUE_TEMPLATE/" -ForegroundColor Gray
Write-Host "   3. Create pull request template in .github/pull_request_template.md" -ForegroundColor Gray
Write-Host "   4. Start using labels when creating issues!" -ForegroundColor Gray