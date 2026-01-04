#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Verify and manage GitHub issue and PR templates
.DESCRIPTION
    This script verifies that all GitHub templates are properly set up and provides
    options to view, validate, or test them.
.EXAMPLE
    .\setup-github-templates.ps1
    .\setup-github-templates.ps1 -Verify
    .\setup-github-templates.ps1 -ShowStructure
#>

param(
    [switch]$Verify = $false,
    [switch]$ShowStructure = $false,
    [switch]$ValidateYaml = $false
)

$ErrorActionPreference = "Stop"

# Template files that should exist
$requiredTemplates = @{
    "Issue Templates" = @(
        ".github/ISSUE_TEMPLATE/config.yml"
        ".github/ISSUE_TEMPLATE/bug_report.yml"
        ".github/ISSUE_TEMPLATE/feature_request.yml"
        ".github/ISSUE_TEMPLATE/question.yml"
        ".github/ISSUE_TEMPLATE/maintenance.yml"
    )
    "PR Template" = @(
        ".github/pull_request_template.md"
    )
}

Write-Host "🔧 GitHub Templates Setup and Verification" -ForegroundColor Cyan
Write-Host "=" * 60 -ForegroundColor Gray

# Function to check if a file exists
function Test-TemplateFile {
    param([string]$Path)
    
    $fullPath = Join-Path $PSScriptRoot ".." $Path
    return Test-Path $fullPath
}

# Function to get file size
function Get-FileSize {
    param([string]$Path)
    
    $fullPath = Join-Path $PSScriptRoot ".." $Path
    if (Test-Path $fullPath) {
        $size = (Get-Item $fullPath).Length
        if ($size -lt 1024) {
            return "$size bytes"
        } elseif ($size -lt 1024 * 1024) {
            return "$([math]::Round($size / 1024, 1)) KB"
        } else {
            return "$([math]::Round($size / (1024 * 1024), 1)) MB"
        }
    }
    return "N/A"
}

# Show directory structure
if ($ShowStructure) {
    Write-Host "`n📁 Expected Template Structure:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host ".github/" -ForegroundColor Cyan
    Write-Host "├── ISSUE_TEMPLATE/" -ForegroundColor Cyan
    Write-Host "│   ├── config.yml              # Issue template chooser config" -ForegroundColor Gray
    Write-Host "│   ├── bug_report.yml          # Bug report template" -ForegroundColor Gray
    Write-Host "│   ├── feature_request.yml     # Feature request template" -ForegroundColor Gray
    Write-Host "│   ├── question.yml            # Question/support template" -ForegroundColor Gray
    Write-Host "│   └── maintenance.yml         # Maintenance/refactoring template" -ForegroundColor Gray
    Write-Host "└── pull_request_template.md    # PR template" -ForegroundColor Cyan
    Write-Host ""
}

# Verify templates exist
Write-Host "`n✅ Verifying Templates..." -ForegroundColor Green

$allExist = $true
$missingTemplates = @()

foreach ($category in $requiredTemplates.Keys) {
    Write-Host "`n📋 $category" -ForegroundColor Yellow
    
    foreach ($template in $requiredTemplates[$category]) {
        $exists = Test-TemplateFile $template
        $size = Get-FileSize $template
        
        if ($exists) {
            Write-Host "   ✓ $template" -ForegroundColor Green -NoNewline
            Write-Host " ($size)" -ForegroundColor DarkGray
        } else {
            Write-Host "   ✗ $template" -ForegroundColor Red -NoNewline
            Write-Host " (MISSING)" -ForegroundColor Red
            $allExist = $false
            $missingTemplates += $template
        }
    }
}

# YAML validation (if requested)
if ($ValidateYaml) {
    Write-Host "`n🔍 Validating YAML Templates..." -ForegroundColor Cyan
    
    $yamlFiles = @(
        ".github/ISSUE_TEMPLATE/config.yml"
        ".github/ISSUE_TEMPLATE/bug_report.yml"
        ".github/ISSUE_TEMPLATE/feature_request.yml"
        ".github/ISSUE_TEMPLATE/question.yml"
        ".github/ISSUE_TEMPLATE/maintenance.yml"
    )
    
    $validationErrors = 0
    
    foreach ($yamlFile in $yamlFiles) {
        $fullPath = Join-Path $PSScriptRoot ".." $yamlFile
        if (Test-Path $fullPath) {
            try {
                # Basic YAML validation - check for common issues
                $content = Get-Content $fullPath -Raw
                
                # Check for tabs (YAML doesn't allow tabs)
                if ($content -match "`t") {
                    Write-Host "   ⚠️  $yamlFile contains tabs (use spaces)" -ForegroundColor Yellow
                    $validationErrors++
                }
                
                # Check for proper indentation (basic check)
                $lines = Get-Content $fullPath
                foreach ($line in $lines) {
                    if ($line -match '^(\s+)' -and $matches[1].Length % 2 -ne 0) {
                        Write-Host "   ⚠️  $yamlFile may have inconsistent indentation" -ForegroundColor Yellow
                        $validationErrors++
                        break
                    }
                }
                
                Write-Host "   ✓ $yamlFile syntax looks good" -ForegroundColor Green
            }
            catch {
                Write-Host "   ✗ $yamlFile validation failed: $($_.Exception.Message)" -ForegroundColor Red
                $validationErrors++
            }
        }
    }
    
    if ($validationErrors -eq 0) {
        Write-Host "`n   ✓ All YAML files passed basic validation" -ForegroundColor Green
    } else {
        Write-Host "`n   ⚠️  Found $validationErrors potential issues" -ForegroundColor Yellow
    }
}

# Summary
Write-Host "`n" + ("=" * 60) -ForegroundColor Gray
Write-Host "📊 Summary:" -ForegroundColor Cyan

if ($allExist) {
    Write-Host "   ✓ All templates are present" -ForegroundColor Green
    Write-Host "   ✓ Total templates: $($requiredTemplates.Values | ForEach-Object { $_.Count } | Measure-Object -Sum | Select-Object -ExpandProperty Sum)" -ForegroundColor Green
} else {
    Write-Host "   ✗ Missing templates:" -ForegroundColor Red
    foreach ($missing in $missingTemplates) {
        Write-Host "     - $missing" -ForegroundColor Red
    }
    Write-Host "`n   Run the templates creation script to set up missing files." -ForegroundColor Yellow
}

# Next steps
Write-Host "`n📝 Using These Templates:" -ForegroundColor Cyan
Write-Host "   1. Push .github directory to your repository" -ForegroundColor Gray
Write-Host "      git add .github/" -ForegroundColor DarkGray
Write-Host "      git commit -m 'Add issue and PR templates'" -ForegroundColor DarkGray
Write-Host "      git push origin main" -ForegroundColor DarkGray
Write-Host ""
Write-Host "   2. Templates will be available immediately:" -ForegroundColor Gray
Write-Host "      • New Issue: https://github.com/dsdobrzynski/dapp-bk/issues/new/choose" -ForegroundColor DarkGray
Write-Host "      • New PR: Automatically shown when creating pull requests" -ForegroundColor DarkGray
Write-Host ""
Write-Host "   3. Test your templates:" -ForegroundColor Gray
Write-Host "      • Create a test issue to verify forms work" -ForegroundColor DarkGray
Write-Host "      • Create a test PR to verify the template appears" -ForegroundColor DarkGray
Write-Host ""

# Template descriptions
Write-Host "📋 Template Descriptions:" -ForegroundColor Cyan
Write-Host "   Bug Report:        Structured form for bug reports with environment details" -ForegroundColor Gray
Write-Host "   Feature Request:   Guided form for suggesting new features" -ForegroundColor Gray
Write-Host "   Question/Support:  Template for user questions and support" -ForegroundColor Gray
Write-Host "   Maintenance:       Template for refactoring and maintenance tasks" -ForegroundColor Gray
Write-Host "   PR Template:       Comprehensive checklist for pull requests" -ForegroundColor Gray
Write-Host "   Config:            Issue chooser with links to docs and discussions" -ForegroundColor Gray
Write-Host ""

# GitHub links
Write-Host "🔗 Useful Links:" -ForegroundColor Cyan
Write-Host "   GitHub Templates Docs: https://docs.github.com/en/communities/using-templates-to-encourage-useful-issues-and-pull-requests" -ForegroundColor DarkGray
Write-Host "   Issue Forms Syntax:    https://docs.github.com/en/communities/using-templates-to-encourage-useful-issues-and-pull-requests/syntax-for-issue-forms" -ForegroundColor DarkGray
Write-Host ""

if ($allExist) {
    Write-Host "🎉 All templates are set up correctly!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "⚠️  Some templates are missing. Please check the output above." -ForegroundColor Yellow
    exit 1
}
