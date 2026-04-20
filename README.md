# X

A Rails app for practising the Polish driving license theory exam. It mirrors the
format used by the official test: 32 questions, 25 minutes, 68 out of 74 points
to pass. Questions come in two groups — 20 "basic" ones worth 1–3 points each
and 12 "specialist" ones tied to the license category you pick (A, B, C, and so
on).

Each question is timed on its own. Basic questions give you 20 seconds to read
and 15 seconds to answer; specialist questions give you 50 seconds. If the timer
runs out, the answer counts as wrong and the exam moves on. You can't go back to
a question once you've left it — same as the real thing.

Questions, options and the UI are available in Polish, English, German and
Ukrainian.

## Requirements

- Ruby (see `.ruby-version`)
- PostgreSQL
- Node.js and Yarn (for asset install)

## Running it locally

```bash
bin/setup --skip-server
bin/rails server
```

`bin/setup` installs gems and JS packages, prepares the database and clears old
logs. Drop the `--skip-server` flag if you want it to start the dev server for
you.

Once it's up, open http://localhost:3000, pick a license category and a
language, and start the exam.

## Tests

```bash
bin/rails db:test:prepare test test:system
```

System tests use Capybara with Selenium, so you'll need a recent Chrome
installed.

## How the data is organised

- **Question banks** hold the pool of questions loaded from an official source.
  Only one bank is active at a time.
- **Exam blueprints** define the rules for an exam — how many questions of each
  weight and scope, duration, pass score. The active blueprint is the one used
  when a new attempt is created.
- **Exam attempts** are the individual sessions. Each one freezes the set of
  questions at the moment it's built, so results stay reproducible even if the
  bank changes later. Attempts are addressed by UUID in the URL.

If you're poking around the code, `ExamAttemptsController` handles the exam
flow and `ExamAttemptBuilder` is where a new attempt is assembled.
