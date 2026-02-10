<!--
SYNC IMPACT REPORT
==================
Version Change: INITIAL → 1.0.0
Amendment Type: MINOR (Initial constitution ratification)

Modified Principles: N/A (initial creation)
Added Sections:
  - Core Principles (5 principles)
  - Development Workflow
  - Configuration Standards
  - Governance

Removed Sections: N/A

Templates Status:
  ✅ .specify/templates/plan-template.md - Constitution Check section aligns
  ✅ .specify/templates/spec-template.md - Requirements structure compatible
  ✅ .specify/templates/tasks-template.md - Task organization reflects principles
  ⚠️  README.md - Should reference constitution for development standards
  ⚠️  CLAUDE.md - Should reference constitution as source of truth

Follow-up TODOs:
  - Consider adding links to constitution in README.md and CLAUDE.md
  - Verify all future workflows reference constitution compliance
-->

# Claude CI/CD Bootstrap Constitution

## Core Principles

### I. Code Quality Standards (NON-NEGOTIABLE)

All project artifacts MUST pass automated validation before commit:

- YAML files MUST pass `yamllint` validation
- Shell scripts MUST pass `shellcheck` validation
- Markdown files MUST be properly formatted
- Consistent naming conventions MUST be enforced:
  - Files: kebab-case (e.g., `claude-pr-review.yml`)
  - Environment variables: UPPER_SNAKE_CASE (e.g., `API_KEY`)
  - Directories: kebab-case (e.g., `custom-commands/`)

**Rationale**: Automated quality gates prevent defects from entering the codebase and ensure
consistency across all templates and workflows. This is critical for a framework that others
will clone and adapt - poor quality would multiply across all downstream projects.

### II. Git Conventions

All commits MUST follow conventional commit format and structure:

- Commit message format: `<type>: <description>`
  - Valid types: `feat:`, `fix:`, `docs:`, `chore:`, `refactor:`
- One logical change per commit
- Clear, descriptive commit messages that explain the "why" not just the "what"
- No breaking changes without major version bump

**Rationale**: Conventional commits enable automated changelog generation, semantic versioning,
and clear project history. For a meta-project focused on CI/CD automation, our commit history
serves as both documentation and example for downstream users.

### III. Documentation First (NON-NEGOTIABLE)

Every component MUST be documented before or alongside implementation:

- Workflows: Inline comments explaining each step
- Templates: Usage instructions and example values
- Scripts: Help flag (`-h` or `--help`) with clear usage examples
- Features: User-facing documentation in `docs/` directory
- Changes: Updated documentation reflecting any behavioral changes

**Rationale**: As a template repository, our documentation IS our product. Users will clone
and adapt our work, so every template, workflow, and script must be self-documenting and
include clear usage instructions. Missing or poor documentation renders the entire framework
unusable.

### IV. Security By Default

Security MUST be built into every component from the start:

- NEVER hardcode secrets, API keys, or sensitive values in any file
- ALWAYS use GitHub Secrets references: `${{ secrets.* }}`
- Apply least-privilege permissions in all workflows
- Include security hardening steps where applicable
- Default to restrictive permissions, only expanding when justified
- Validate all inputs, especially in workflows triggered by external events

**Rationale**: This framework targets enterprise environments, including financial services.
A single security lapse in our templates could be replicated across dozens of downstream
projects. Security cannot be an afterthought - it must be the default posture.

### V. Incremental Implementation

All development MUST follow a read-plan-implement-test-document cycle:

- **Read**: Understand existing files and current state before any changes
- **Plan**: Design approach before writing code (use explicit planning for complex tasks)
- **Implement**: Make changes incrementally with clear commits
- **Test**: Validate YAML syntax, script execution, workflow logic
- **Document**: Update appropriate documentation to reflect changes

**Rationale**: Incremental development with validation at each step prevents large, brittle
changes that break existing functionality. For a framework that others depend on, stability
and predictability are paramount. Each phase must complete successfully before proceeding.

## Development Workflow

### Task Execution Process

When starting any new task:

1. Read relevant existing files to understand current state
2. Plan the approach (explicit planning required for complex changes)
3. Implement incrementally with atomic commits
4. Test by validating syntax and execution
5. Document changes in appropriate files

### Workflow Creation Standards

All GitHub Actions workflows MUST include:

- Descriptive name clearly stating the workflow purpose
- Clear trigger conditions with explanatory comments
- Explicit, least-privilege permissions (never use blanket permissions)
- Checkout step with appropriate fetch depth (`fetch-depth: 0` for analysis workflows)
- Step-by-step comments explaining each action
- Error handling and failure notifications

### Template Creation Standards

All templates MUST include:

- Placeholder markers using double curly braces: `{{PLACEHOLDER_NAME}}`
- Explanatory comments for each section
- Example values in comments showing expected format
- Clear instructions on how to fill out the template
- References to related documentation

### Command Creation Standards

All custom slash commands MUST follow this structure:

- Command metadata (name, description, usage)
- Usage examples showing common scenarios
- Step-by-step explanation of what the command does
- Clear parameter documentation
- Command implementation using `$ARGUMENTS`

## Configuration Standards

### File Naming Conventions

Consistent naming enables predictability and automation:

- **Workflows**: `claude-{action}.yml` (e.g., `claude-pr-review.yml`)
- **Templates**: `CLAUDE.md.{variant}` (e.g., `CLAUDE.md.spring-boot`)
- **Commands**: `{action}.md` (e.g., `review-pr.md`)
- **Scripts**: `{action}.sh` (e.g., `setup.sh`)
- **Documentation**: `SCREAMING_SNAKE_CASE.md` for root docs, Title Case for `docs/`

**Rationale**: Naming conventions eliminate ambiguity and enable automated discovery. Users
should be able to predict file names and locations without consulting documentation.

### Project Structure

All projects using this framework MUST maintain consistent structure:

- `.agent/` - Agent Pipeline template (workflows, scripts, config, state)
- `.specify/` - Speckit templates and project-specific specifications
- `workflows/` - Standalone GitHub Actions workflow templates
- `commands/` - Custom slash commands
- `mcp/` - Model Context Protocol configurations
- `scripts/` - Helper scripts for setup and automation
- `docs/` - User-facing documentation
- `examples/` - Working example implementations
- `specs/` - Feature specifications and design artifacts

## Governance

### Constitutional Authority

This Constitution supersedes all other practices and conventions. In cases of conflict
between this document and any other guidance, this Constitution prevails.

### Amendment Process

Amendments to this Constitution require:

1. Documentation of the proposed change and rationale
2. Approval via PR review (at minimum, project maintainer approval)
3. Migration plan for affected templates and workflows
4. Version bump following semantic versioning rules:
   - MAJOR: Backward incompatible governance changes or principle removals
   - MINOR: New principles or materially expanded guidance
   - PATCH: Clarifications, wording fixes, non-semantic refinements

### Compliance Review

All pull requests and code reviews MUST verify compliance with this Constitution:

- Automated checks for code quality (yamllint, shellcheck, markdown linting)
- Manual review for adherence to conventions and principles
- Documentation completeness verification
- Security review for any workflow or script changes

### Complexity Justification

Any deviation from simplicity MUST be explicitly justified in the implementation plan:

- Why is this complexity necessary?
- What simpler alternatives were considered?
- Why were simpler alternatives rejected?

Unjustified complexity is grounds for rejecting changes.

### Runtime Development Guidance

For runtime development practices and interactive guidance when working with AI agents,
refer to `CLAUDE.md`. This file provides context-specific instructions for AI-assisted
development and should be kept aligned with Constitutional principles.

**Version**: 1.0.0 | **Ratified**: 2026-01-26 | **Last Amended**: 2026-01-26
