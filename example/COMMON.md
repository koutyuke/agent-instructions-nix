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
