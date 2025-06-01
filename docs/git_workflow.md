# Git Workflow for the Metrics Project

This document outlines the recommended Git workflow for managing the metrics monitoring infrastructure.

## Initial Setup

If you haven't already, clone the repository:

```bash
git clone https://github.com/ait88/metrics.git
cd metrics
```

## Basic Workflow

### 1. Before Making Changes

Always pull the latest changes before starting work:

```bash
git pull origin main
```

### 2. Making Changes

It's good practice to create feature branches for significant changes:

```bash
git checkout -b feature/your-feature-name
```

### 3. Committing Changes

Stage your changes and commit them with a descriptive message:

```bash
git add .                               # Stage all changes (use with caution)
# Or stage specific files
git add terraform/frontend/main.tf      # Stage a specific file
git add docs/*.md                       # Stage all markdown files in docs directory

git commit -m "Add Vultr infrastructure configuration"
```

### 4. Pushing Changes

Push your changes to the remote repository:

```bash
git push origin feature/your-feature-name  # If using a feature branch
# Or
git push origin main                       # If working directly on main
```

### 5. Creating Pull Requests

For significant changes, create a pull request on GitHub:

1. Go to the repository on GitHub
2. Click on "Pull requests"
3. Click "New pull request"
4. Select your branch as the compare branch
5. Add a title and description
6. Click "Create pull request"

## Working with Sensitive Data

**IMPORTANT**: Never commit sensitive data to Git. The `.gitignore` file is set up to exclude common files containing secrets, but be vigilant.

### If you accidentally commit sensitive data:

1. Remove the sensitive data from the repository:
   ```bash
   git filter-branch --force --index-filter \
   "git rm --cached --ignore-unmatch PATH_TO_FILE" \
   --prune-empty --tag-name-filter cat -- --all
   ```

2. Force push to overwrite the remote repository:
   ```bash
   git push origin --force --all
   ```

3. Change your secrets immediately, as they may have been compromised.

## Best Practices

1. **Commit Messages**: Write clear, descriptive commit messages
2. **Frequent Commits**: Make small, focused commits rather than large, sweeping changes
3. **Pull Before Push**: Always pull the latest changes before pushing
4. **Feature Branches**: Use feature branches for larger changes
5. **Review Before Committing**: Double-check your changes with `git diff` before committing
6. **Descriptive Branch Names**: Use descriptive names for your branches (e.g., `feature/add-prometheus-alerts`)

## Git Hooks

Consider setting up Git hooks to prevent accidentally committing sensitive data:

```bash
cat > .git/hooks/pre-commit << 'EOF'
#!/bin/bash

# Check for potential secrets in staged files
if git diff --cached --name-only | xargs grep -l "API_KEY\|SECRET\|PASSWORD\|TOKEN" > /dev/null; then
  echo "WARNING: Potential secrets found in commit!"
  git diff --cached --name-only | xargs grep -l "API_KEY\|SECRET\|PASSWORD\|TOKEN"
  read -p "Continue with commit? (y/n) " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1
  fi
fi
EOF

chmod +x .git/hooks/pre-commit
```

This hook will warn you if it detects potential secrets in your commits.
