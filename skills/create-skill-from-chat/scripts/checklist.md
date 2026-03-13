# Implementation Checklist Template

Use this as a reference when creating TaskCreate items in Step 4.
Copy relevant items based on which supporting files the user approved.

## Core (always required)

- [ ] Create `~/.claude/skills/{name}/` directory
- [ ] Write SKILL.md with frontmatter (name, description, model, context, tools)
- [ ] Verify description starts with "Use when..."
- [ ] Verify allowed-tools list is minimal (only what the skill actually uses)

## Supporting Files (include based on user approval)

### Template file (`scripts/template.*`)
- [ ] Extract the primary artifact from the conversation
- [ ] Generalize: replace domain-specific names with placeholders
- [ ] Pre-seed: keep 80%+ of the working code intact
- [ ] Add customize-here comments at the 3-5 adaptation points
- [ ] Verify it runs standalone (no imports from outside the skill)

### Exploration script (`scripts/explore.sh`)
- [ ] Capture the discovery commands that were run during the conversation
- [ ] Include directory scanning, format detection, data shape inspection
- [ ] Add comments explaining what each block discovers and why

### Setup script (`scripts/setup.sh`)
- [ ] List all dependencies that needed installing
- [ ] Include venv creation if applicable
- [ ] Make idempotent (safe to run twice)

### Verification script (`scripts/verify.sh`)
- [ ] Capture the smoke tests that validated the deliverable
- [ ] Include expected output patterns or assertions
- [ ] Test data loading, API responses, round-trip correctness

### Example files (`scripts/examples/`)
- [ ] Include sample inputs that demonstrate the expected format
- [ ] Include sample configs if configuration was involved
- [ ] Include expected outputs for comparison

### Decision log (`references/decisions.md`)
- [ ] Document each major technical choice with: decision, alternatives considered, why this one won
- [ ] Include user-stated constraints that drove the choice

### Pitfalls reference (`references/pitfalls.md`)
- [ ] Document non-obvious gotchas discovered during the conversation
- [ ] Include: what went wrong, why, and the fix
- [ ] Focus on things a future agent wouldn't know to avoid

## Final Verification (always required)

- [ ] Read back ALL created files
- [ ] Confirm `~/.claude/skills` token used for all internal paths
- [ ] Confirm SKILL.md body is under 500 words
- [ ] Inform user the skill is ready and show invocation command
