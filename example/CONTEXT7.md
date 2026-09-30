# Context7

Use the Context7 MCP server to fetch current documentation whenever a question involves a library, framework, SDK, API, or CLI tool. Prefer it over web search, and use it even for well-known libraries, since training data may be outdated.

## When not to use it

- Refactoring or debugging business logic
- Writing scripts from scratch
- General programming concepts

## Steps

1. Call `resolve-library-id` with the library name, unless the user gives an ID in `/org/project` form.
2. Pick the best match by name, description, and source reputation.
3. Call `query-docs` with that ID, one concept per query.
4. Answer based on the fetched documentation.

```text
# Headings inside code fences are left as they are.
resolve-library-id "next.js" -> /vercel/next.js
query-docs /vercel/next.js "middleware configuration"
```
