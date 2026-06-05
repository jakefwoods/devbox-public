---
name: emacs-daemon
description: Query and interact with the running Emacs daemon via emacsclient --eval. Use for org-mode journal/TODO queries (org-ql), org-roam-db lookups, file/buffer operations, and any task where the live Emacs state is authoritative. Prefer this over reading large org files directly.
---

# Emacs Daemon

## Overview

The user runs `emacs --fg-daemon` (or via launchd). All Emacs state — buffers, org-roam-db, org-ql indices — is live in that process. Use `emacsclient --eval '(...)'` to query or mutate it.

This is **always** preferred over reading org files directly because:
- org-ql parses headings/timestamps/tags semantically (not regex).
- org-roam-db has indexed links, IDs, titles, tags.
- File contents may be large; queries return only what you need.

## Daemon check

Before any emacsclient call, verify the daemon is running:

```bash
emacsclient --eval '(+ 1 1)' 2>/dev/null
```

If this fails (exit code != 0):
1. Check if the user has a launchd service: `launchctl list | grep emacs`
2. If so: `launchctl kickstart -k gui/$(id -u)/emacs` (or ask the user).
3. If not: suggest `emacs --fg-daemon` in a separate terminal.
4. **Fallback**: read files directly with Read/Grep tools if the daemon cannot be started.

## Core pattern

```bash
emacsclient --eval '(json-encode <expr>)'
```

Always wrap results in `json-encode` for structured output. The shell will return a JSON string (double-escaped inside shell quotes — parse accordingly).

For multi-line elisp, use a heredoc or `--eval` with escaped newlines.

## ~/org conventions (flat journal)

The user's org directory is `~/org/`. The primary file is `~/org/journal.org`:

- **Structure**: flat, newest-first.
- **Day headings**: `* YYYY-MM-DD Weekday` (level 1).
  - Property: `:ID: journal:YYYY-MM-DD` on each day heading.
- **Entries**: `** <entry>` (level 2) under day headings, newest-first within a day.
- **TODOs**: entries may have TODO/DONE keywords. DONE entries get a `CLOSED: [timestamp]`.
- **Tags**: on headings as usual (`:tag1:tag2:`).
- **Other files**: `~/org/ref/` contains reference wiki pages (each with `:ID:` and `#+TITLE:`).

Links between pages use `[[id:...]]` syntax. The `journal:YYYY-MM-DD` IDs allow linking to specific days.

## org-ql recipes

org-ql is loaded in the running Emacs. Use `org-ql-select` for programmatic queries.

### Last N days of journal entries

```elisp
(json-encode
  (org-ql-select "~/org/journal.org"
    '(and (level 2)
          (ts :from -7))
    :action '(list (org-get-heading t t t t)
                   (org-entry-get nil "CLOSED")
                   (org-entry-get nil "ID"))))
```

### Entries on a specific date

```elisp
(json-encode
  (org-ql-select "~/org/journal.org"
    '(and (level 2)
          (parent (heading-regexp "2026-06-04")))
    :action '(org-get-heading t t t t)))
```

### Open TODOs (across all org files)

```elisp
(json-encode
  (org-ql-select (org-agenda-files)
    '(todo)
    :action '(list (org-get-heading t t t t)
                   (buffer-file-name)
                   (org-entry-get nil "ID"))))
```

### Search by tag

```elisp
(json-encode
  (org-ql-select "~/org/journal.org"
    '(tags "project")
    :action '(org-get-heading t t t t)))
```

### Search by text content

```elisp
(json-encode
  (org-ql-select "~/org/journal.org"
    '(regexp "deployment")
    :action '(list (org-get-heading t t t t)
                   (org-entry-get nil "ID"))))
```

### Date range query

```elisp
(json-encode
  (org-ql-select "~/org/journal.org"
    '(and (level 2)
          (ts :from "2026-05-01" :to "2026-05-31"))
    :action '(org-get-heading t t t t)))
```

### Day headings (level 1) for a date range

```elisp
(json-encode
  (org-ql-select "~/org/journal.org"
    '(and (level 1)
          (heading-regexp "2026-06"))
    :action '(org-get-heading t t t t)))
```

## org-roam-db recipes

org-roam indexes all `:ID:`-bearing headings. The SQLite DB is queryable via `org-roam-db-query`.

### Find a node by ID

```elisp
(json-encode
  (org-roam-db-query
    [:select [title file pos]
     :from nodes
     :where (= id $s1)]
    "journal:2026-06-04"))
```

### Find nodes by title pattern

```elisp
(json-encode
  (org-roam-db-query
    [:select [id title file]
     :from nodes
     :where (like title $s1)]
    "%deploy%"))
```

### Get all links from a node

```elisp
(json-encode
  (org-roam-db-query
    [:select [dest type]
     :from links
     :where (= source $s1)]
    "journal:2026-06-04"))
```

### Get backlinks to a node

```elisp
(json-encode
  (org-roam-db-query
    [:select [source type]
     :from links
     :where (= dest $s1)]
    "some-page-id"))
```

### List all wiki pages (ref directory)

```elisp
(json-encode
  (org-roam-db-query
    [:select [id title file]
     :from nodes
     :where (like file $s1)]
    "%/ref/%"))
```

## General emacsclient recipes

### Open a file at a heading (by ID)

```bash
emacsclient --eval '(org-id-goto "journal:2026-06-04")'
```

### Get page title from a file

```elisp
(json-encode
  (with-current-buffer (find-file-noselect "~/org/ref/some-page.org")
    (cadar (org-collect-keywords '("TITLE")))))
```

### Run an interactive command

```bash
emacsclient --eval '(call-interactively #'\''org-agenda)'
```

### Get buffer list

```elisp
(json-encode (mapcar #'buffer-name (buffer-list)))
```

## Tips

- **Quoting**: shell eats one layer of quotes. Use single-quotes around the elisp, escape internal single-quotes with `'\''`.
- **Large results**: if a query might return many items, add `:limit N` or use `seq-take` in elisp.
- **Error handling**: if emacsclient returns an error string, it typically starts with `*ERROR*:` — check for that prefix.
- **Timeout**: emacsclient has no built-in timeout. For potentially slow queries, wrap in `with-timeout` in elisp or use the bash `timeout` command.
- **Side effects**: `org-ql-select` is read-only. Mutations (refile, state change) need `org-todo`, `org-refile`, etc. — confirm with user before mutating.
