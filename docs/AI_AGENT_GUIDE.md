# AI Agent Contribution Guide

This guide outlines expectations for autonomous and semi-autonomous contributors when working in the Novus repository. Review it before performing any automated changes.

## Core Principles
- **Follow Repository Instructions First**: Always locate and obey every relevant `AGENTS.md` file. Local instructions override higher-level ones.
- **Stay Within Scope**: Make only the changes required by the task request. Flag ambiguous asks for clarification instead of guessing.
- **Preserve Game Stability**: Avoid experimental refactors unless explicitly requested. Favor incremental updates that keep the game bootable.

## Workflow Checklist
1. **Understand the Request**
   - Restate the task in your own words.
   - Identify impacted files and confirm their instructions.
2. **Plan Before Editing**
   - Outline proposed changes and tests.
   - Highlight risky modifications for human review.
3. **Implement Carefully**
   - Respect Lua style conventions: 4-space indent, snake_case locals, PascalCase modules.
   - Keep data changes consistent with loader expectations documented in `SYSTEMS_GUIDE.md` and `CONTENT_GUIDE.md`.
4. **Validate**
   - Run available scripts (e.g., `love .`) when possible or document why not.
   - Describe manual verification steps if automation is unavailable.
5. **Document the Work**
   - Update relevant guides when behavior or workflows change.
   - Provide thorough PR summaries, including gameplay impact and test notes.

## Safety & Review Practices
- **Guard Sensitive Data**: Do not commit secrets. Use example placeholders in docs.
- **Surface Limitations**: Call out environment constraints (missing dependencies, no audio, etc.).
- **Request Help**: If required actions would break instructions or exceed permissions, pause and ask for guidance.

## Communication Standards
- Maintain professional tone in commit messages and PR descriptions.
- Include citations to modified files and commands when summarizing work.
- When introducing new tooling, document installation and execution steps for maintainers.

By following this playbook, agents help keep the Novus project consistent, maintainable, and safe.
