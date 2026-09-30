# AGENTS.md

## Communication

- Lead with the conclusion, then give the reasons needed to act on it.
- Keep explanations short and skip filler praise.
- Separate verified facts from assumptions and open questions.

## Workflow

- Read the relevant code, tests, and docs before editing.
- Check `git status` and protect changes you did not make.
- Choose the smallest change that meets the requirements; do not add unrequested abstractions.
- Ask only when a decision belongs to the user and cannot be resolved by investigation.

## Verification

- Run the tests, linters, and type checks that cover the change.
- For bug fixes, reproduce the failure first and confirm the fix afterwards.
- Report failed or skipped checks as they are; never claim unverified results.

## Safety

- Never hard-code secrets or print them in logs or replies.
- Confirm before pushing, deploying, or running destructive commands.

## Context7

Use the Context7 MCP server to fetch current documentation whenever a question involves a library, framework, SDK, API, or CLI tool. Prefer it over web search, and use it even for well-known libraries, since training data may be outdated.

### When not to use it

- Refactoring or debugging business logic
- Writing scripts from scratch
- General programming concepts

### Steps

1. Call `resolve-library-id` with the library name, unless the user gives an ID in `/org/project` form.
2. Pick the best match by name, description, and source reputation.
3. Call `query-docs` with that ID, one concept per query.
4. Answer based on the fetched documentation.

```text
# Headings inside code fences are left as they are.
resolve-library-id "next.js" -> /vercel/next.js
query-docs /vercel/next.js "middleware configuration"
```

## Sandbox

- Work inside the sandbox and request escalation only when a command needs network or files outside the workspace.
- Prefer `rg` over `grep` for searching.

## Final Report

- Summarize what changed and which files were touched.
- List the checks you ran and their results.
- Mention anything left unverified and what is needed to finish it.
