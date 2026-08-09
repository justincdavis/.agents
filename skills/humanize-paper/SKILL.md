---
name: humanize-paper
description: Use when the user wants to revise a paper (or any long prose document) into a target voice defined in a style-guide markdown file, using a humanizer subagent checked by an adversarial critic subagent ping-ponged to consensus. Triggers on "make this sound like me / like <style file>", "apply my style guide to the paper", "humanize the paper", "match the voice in HUMANIZE.md".
disable-model-invocation: false
user-invocable: true
context: conversation
allowed-tools: Bash, Read, Agent, SendMessage, AskUserQuestion
---

# Humanize a Paper into a Target Voice (with an adversarial critic)

Restyle a document into the voice defined by a style-guide markdown file, using
two subagents: a **humanizer** that rewrites, and an **adversarial critic** that
tries to break its work — on both voice fidelity *and* the hard rule that no fact
changed. You (the main thread) orchestrate the loop and are the only one that
commits.

The whole method rests on one asymmetry: **restyling long prose is a factual
minefield.** A stylish rewrite that silently corrupts one number, re-associates a
citation, or flips a comparative is worse than no rewrite. So every round is
gated by an objective, independently-run factual check, and the critic is a
*fresh* agent (never a fork of the humanizer) with `git diff` access so it has no
stake in defending the edits.

## Inputs to confirm first

- **The document** (e.g. `paper/main.tex`). It should be committed, or commit it
  now — the factual gate diffs against a baseline commit. Record that baseline
  SHA; you will diff every round against it.
- **The style guide** (e.g. `HUMANIZE.md`). Read it in full yourself before
  briefing anyone, so you can adjudicate conflicts between style and fact.
- **A build/lint check** if one exists (e.g. `python paper/check.py`, `latexmk`,
  a markdown linter). Run it after every humanizer round.

If any is missing or ambiguous, ask with AskUserQuestion before spawning anything.

## The hard rules (put these verbatim in every subagent brief)

1. **Change no fact.** No number, percentage, multiplier, arrow value, unit,
   model/product name, citation key, `\ref`/`\label`, macro, equation, or table
   cell. Restyle the words around a number; never the number.
2. **Do not touch** the preamble/frontmatter, macro definitions, the system-name
   macro, bibliography, or the numeric content of any table/figure/equation
   environment. A table *caption*'s prose is fair game; its cells are not.
3. **Keep it building.** Run the build/lint check and make it pass before
   finishing. Do not add new macros.
4. **The style guide is a guide, not a checklist.** Never fabricate structure or
   claims to satisfy a rule. If a rule (a backronym expansion, a C1–C4 challenge
   callback, a "motivating question") would require inventing content, its
   absence is *correct*, not a failure. Voice fidelity is the bar, not mechanical
   coverage.

## The loop

### Round 1 — humanizer (fresh Agent, sonnet)

Spawn a `general-purpose` sonnet agent. Brief it with: the style-guide path, the
document path, the four hard rules verbatim, and the instruction to work section
by section and run the build check at the end. Tell it to report *categories* of
change with rough counts (e.g. "~110 em-dash conversions, 7 differentiators
added"), any place it chose the fact over the style rule, and any section it
deliberately left alone.

Subagents usually **cannot write report files** (tool-layer block) — tell it to
return everything in its final message, and you save/relay as needed.

### After every humanizer round — you verify the factual gate independently

Do not trust the humanizer's own fact-check. Run your own, from the baseline SHA:

```bash
python - <<'EOF'
import subprocess, re, collections
BASE="<baseline-sha>"; F="paper/main.tex"
old=subprocess.run(['git','show',f'{BASE}:{F}'],capture_output=True,text=True).stdout
new=open(F).read()
def c(s,p): return collections.Counter(re.findall(p,s))
for name,pat in [('numbers',r'\d+\.?\d*'),
                 ('cites',r'\\cite[a-zA-Z]*\{([^}]*)\}'),
                 ('refs',r'\\(?:ref|cref|Cref|autoref|eqref)\{([^}]*)\}'),
                 ('labels',r'\\label\{([^}]*)\}')]:
    o,n=c(old,pat),c(new,pat)
    print(f'{name:8s} '+('IDENTICAL' if o==n
          else f'only_new={sorted((n-o).elements())} only_old={sorted((o-n).elements())}'))
EOF
```

A multiset match on numbers/citations/refs/labels is necessary but **not
sufficient** — it misses a number moved to the wrong sentence or a citation
re-associated with the wrong claim. Those are the critic's job (below). A benign
delta is possible (e.g. a digit inside a newly-introduced product name like
"MC3"); inspect any delta and judge it, don't just accept a nonzero count.

Then run the build/lint check. If either fails, bounce it straight back to the
humanizer before involving the critic.

### Round 2 — adversarial critic (a DIFFERENT fresh Agent, sonnet)

Only after the humanizer's first pass passes your gate. Spawn a **new**
`general-purpose` sonnet agent — not the humanizer, not a fork. Give it:

- the style guide and the document,
- the baseline SHA and instructions to run `git diff <baseline> -- <file>` and
  inspect **every hunk**, not just a token count — flag as a HARD FAIL any hunk
  that alters a number, moves one to the wrong sentence, re-associates a
  citation, or flips a comparative,
- a section-by-section voice audit producing **line-level** failures: each with a
  line number, the offending text, the specific style-guide section it violates,
  and a concrete fix,
- the same calibration rule (#4 above): do **not** fail the paper for absent
  structure that would require fabrication.

Have it return: (1) factual gate PASS / HARD FAIL with specifics; (2) voice
verdict SIGN-OFF / REVISE with a capped list (~15) of concrete failures, most
important first; (3) one line: does it read as the target voice yet.

**Tell the critic not to manufacture trivia to justify another round.** An
adversarial agent left unconstrained will always find *something*; instruct it
that if the work is done, it signs off.

### Rounds 3+ — relay, revise, re-audit (bounded to ~3–4 total)

Triage the critic's list yourself before relaying — you are the adjudicator:
- **Legitimate + safe** (reformatting existing numbers, passive→active, missing
  differentiators): relay to the humanizer.
- **Requires new claim-bearing prose** (e.g. related-work differentiator
  sentences): relay *with an explicit anti-fabrication constraint* — the new
  sentence may only restate a contrast the document already establishes
  elsewhere; a missing sentence beats a fabricated one; if no true version
  exists, leave it and say so.
- **Would require fabrication or restructuring** (motivating question, C1–C4
  callbacks, backronym): drop it, or surface to the user as an editorial call.

Relay via **SendMessage to the humanizer's agent id/name** so it *resumes with
its context* and revises in place, rather than a fresh Agent that restarts cold.
Then re-run your factual gate + build check, and SendMessage the *critic* (also
resumed, so it audits against its own prior findings) for the next pass. On rounds
that add new prose, point the critic specifically at those new sentences — new
prose is the only place a fresh falsehood can enter.

**Consensus** = critic SIGN-OFF on voice AND factual gate PASS AND your
independent numeric diff clean AND build check passes. Cap at ~3–4 rounds so it
converges instead of bikeshedding punctuation; if it is still churning, take the
best passing state and report the residual nits to the user.

### Finish

Apply any final non-blocking polish the critic flagged (often cheaper to fix
yourself than another round-trip), run the gate + build one last time, then commit
— you, not the subagents. In the commit message, state that the revision is
prose-only and give the integrity evidence (e.g. "810 numbers, 71 citations, 63
refs, 40 labels byte-identical to baseline; only new token is the digit in
'MC3'"). Report to the user which round reached consensus and the critic's final
one-line verdict.

## Why each design choice matters (don't skip these)

- **Fresh critic, not a fork.** A fork inherits the humanizer's context and its
  investment in the edits. A fresh agent with `git diff` audits objectively.
- **You run the numeric gate, not the humanizer.** Self-reported fact-checks are
  the thing most likely to be motivated-reasoned. One extra script per round is
  cheap insurance against a corrupted value shipping.
- **Resume agents across rounds (SendMessage), don't respawn.** The humanizer
  revising its own prose keeps consistency; a cold restart re-derives and drifts.
- **Bound the loop and forbid trivia-mining.** Otherwise an adversarial critic
  never signs off and a perfectionist humanizer never stops.
- **Anti-fabrication on new sentences is the sharpest risk.** Verified *numbers*
  do not protect against a false *sentence*. Related-work differentiators that
  mischaracterize prior work get a paper caught by exactly the reviewer who knows
  that work. Constrain new prose to restating what the document already supports,
  and have the critic verify each new claim against its source paragraph.

## Adapting beyond LaTeX papers

The method is format-agnostic. For a plain-markdown doc, drop the macro/table
constraints and keep the numeric/link/quote integrity gate (`grep` for changed
numbers, URLs, quoted spans). For a non-git document, snapshot a baseline copy and
diff against that. The two invariants are always: **an objective factual gate you
run yourself**, and **a fresh adversarial reader with access to the before/after**.
