# Working with Christian

## Verify before claiming it works

- Exercise the changed path with realistic input, then read what it actually
  produced. Parsing, compiling or linting checks syntax, not behaviour.
- When nothing is executable — docs, config — verify the effect instead:
  re-read the resolved value, render the file, grep the result.
- State plainly what was and was not verified. "Validates, but I could not
  test X" beats a confident claim that collapses on his first try.
- After two failed fixes, stop guessing and get data — instrument, log,
  bisect, or ask for one specific observation. A third guess is almost never
  right.
- Beware the test that passes for the wrong reason. Pick fixtures that could
  actually fail.

## Do the verification yourself

Never hand back a placeholder like "REF TO VERIFY" or "check this figure". If
something needs confirming, confirm it — read the file, run the query, search
the web — then report what was found.

Never invent a fact to fill a gap: an acronym's expansion, a function's
argument, a package's behaviour. Look it up or say it is unknown.

## Work in small steps

Prefer a small correct step he can react to over a large speculative one.
Address the evidence he reports — an error, an output, a screenshot — rather
than restating the theory.

Replies: tight, no preamble, no recap of what he just said.

## Git

- Commit as work completes, without waiting to be asked — one fix or one
  coherent change per commit, never a single batch at the end. With several
  bugs in flight, commit them one by one. He rolls back to specific commits,
  so each has to stand alone.
- Follow Conventional Commits: `type(scope): summary`, lowercase summary, no
  trailing period. Types: feat, fix, docs, refactor, perf, test, build, ci,
  chore. Breaking changes take `!` before the colon.
- Keep bodies short — a few lines. Omit entirely when the subject says it
  all. A durable constraint belongs in a code comment, where it is read at
  the point of use; do not also restate it here.
- Use the body only for what has no home in the code: why now, an
  alternative that was rejected, how the change was verified.
- Never push unless asked.

## Style

- Markdown hard-wrapped at 77 columns. Count characters, not bytes — `awk`'s
  `length()` over-reports on em dashes and arrows.
- Comments explain *why*. One restating the code is noise; one recording the
  constraint that forced it is worth keeping.
