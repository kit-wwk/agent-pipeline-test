# Agent Pipeline Test

This is a test repository for validating the Agent Pipeline intake workflow.

## Project Context

- **Purpose**: Test the Phase 0 intake workflow (issue validation, branch creation, spec generation, plan validation)
- **Tech Stack**: Shell scripts, YAML (GitHub Actions), Markdown
- **Testing Focus**: GitHub Actions workflow orchestration

## Structure

```
.github/workflows/     # Agent pipeline workflows
.agent/                # Pipeline config, scripts, labels
.specify/              # Speckit templates and scripts
.claude/commands/      # Claude Code slash commands
specs/                 # Generated feature specs (created by pipeline)
```

## Development Rules

- Use conventional commits
- All shell scripts must pass shellcheck
- YAML files must be valid
