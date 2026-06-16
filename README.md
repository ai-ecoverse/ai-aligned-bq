# 💸 AI-ALIGNED-BQ: THE LAST LINE OF DEFENSE AGAINST THE BIGQUERYPOCALYPSE 💸

[![Vibe Coded](https://img.shields.io/badge/Vibe_Coded-ff69b4?style=for-the-badge&logo=claude&logoColor=white)](https://github.com/ai-ecoverse/vibe-coded-badge-action)

## THE EXISTENTIAL THREAT (NOW WITH A DOLLAR AMOUNT ATTACHED)

The other day a colleague handed an AI agent a BigQuery dataset and said "have a dig around." The agent dug around. Forty-five minutes and several `SELECT *` later, it had dug a **$600 hole** in the cloud bill.

Here's the thing about BigQuery on-demand pricing: you don't pay for rows returned. You pay for **bytes scanned** — **$6.25 per TiB**. And the table the agent was rummaging through? 11.58 TiB. Day-partitioned, columnar, the works — but only if you actually *use* the partition column and select real columns. The agent did neither. It ran the three queries that look completely harmless and cost a fortune:

### The Three Horsemen of the Query Apocalypse:
1. **`SELECT *`** — reads every column of a columnar store; the single most expensive thing you can type.
2. **No `WHERE` on the partition column** — turns a 5 GiB slice into a full 11.58 TiB scan.
3. **`LIMIT 10` for "safety"** — caps the rows you *see*, not the bytes you *pay for*. It scans the whole thing anyway. (This one fools everybody.)

## BUT WAIT! THERE'S A DRY RUN! 🌟

Introducing **AI-ALIGNED-BQ** — the `bq` wrapper that stands between your AI agents and your cloud bill.

It does the one thing your colleague forgot to do: it runs a **`--dry_run` before every single query**, reads back exactly how many bytes BigQuery *would* scan (for free, no query executed), converts that to dollars, and then refuses to proceed if the agent is about to do something stupid.

### 🚀 What It Enforces

- **🔍 MANDATORY DRY RUN** — every AI query is estimated before it runs. No more "find out at the invoice."
- **🧱 PER-QUERY HARD CAP** — a runaway full-table scan is blocked *and* a `--maximum_bytes_billed` backstop is injected so the real job can never bill past the cap even if the estimate is wrong.
- **📊 DAILY SPEND LEDGER** — every cleared query's estimated cost is logged, and a configurable **$100/day budget for agents** is a hard wall.
- **🙂 HUMANS UNAFFECTED** — if no AI is detected, your queries pass through completely untouched. This is about agents, not you.

## 🏃 INSTALL NOW BEFORE THE INVOICE ARRIVES

### One-Line Install (Recommended)

```bash
curl -fsSL https://raw.githubusercontent.com/ai-ecoverse/ai-aligned-bq/main/install.sh | sh
```

The installer checks that the Google Cloud SDK is present, drops the `bq` wrapper into `~/.local/bin`, and makes sure it shadows the real `bq` on your `PATH`. (Requires `~/.local/bin` to come *before* the gcloud SDK in `PATH`.)

## 📖 USAGE (IT'S AUTOMATIC)

Just use `bq` normally. The wrapper detects whether an AI tool is driving and, if so, enforces the guardrails. Otherwise it gets out of the way.

### The Dark Timeline (Without AI-Aligned-BQ)

```bash
# Claude, "having a dig around"
$ bq query --use_legacy_sql=false 'SELECT * FROM `proj.rum.cluster` LIMIT 10'
# ... 11.58 TiB scanned, $72 gone, repeat 8x ...
# Later, on the invoice: $600
```

### The Bright Future (With AI-Aligned-BQ)

```bash
$ bq query --use_legacy_sql=false 'SELECT * FROM `proj.rum.cluster` LIMIT 10'
[ai-aligned-bq] claude detected — running a mandatory dry run to estimate cost...
[ai-aligned-bq] Estimated scan: 11.58 TiB (~$72.40 at $6.25/TiB)
[ai-aligned-bq] Spent so far today: $0.03 / $100  →  after this query: $72.43

Error: 'claude' wants to scan 11.58 TiB, exceeding the per-query cap of 100.00 GiB.
This is how a $600 bill happens. Add a WHERE clause on the partition column,
select only the columns you need (never SELECT *), and remember LIMIT does NOT reduce bytes scanned.

If you really mean it, append the flag: --claude-is-a-budget-burner

# Claude learns and adapts
$ bq query --use_legacy_sql=false \
    'SELECT id, checkpoint FROM `proj.rum.cluster`
     WHERE time BETWEEN TIMESTAMP("2026-06-01") AND TIMESTAMP("2026-06-02")'
[ai-aligned-bq] claude detected — running a mandatory dry run to estimate cost...
[ai-aligned-bq] Estimated scan: 4.89 GiB (~$0.03 at $6.25/TiB)
[ai-aligned-bq] Spent so far today: $0.03 / $100  →  after this query: $0.06
+-----------+------------+
|    id     | checkpoint |
...
```

### The Daily Wall

Once the agent has burned through the daily budget, that's it until tomorrow:

```bash
$ bq query --use_legacy_sql=false 'SELECT ...'
Error: This query (~$40.00) would push today's spend to $112.00, over the $100 daily budget for agents.
The daily budget is a hard wall and cannot be overridden by a flag.
Either wait until tomorrow, narrow the query, or have a human raise AI_ALIGNED_BQ_DAILY_USD.
```

### The Budget-Burner Override™️ (Per-Query Only)

If an agent *insists* a giant scan is necessary, it must say so out loud — and the per-query cap lifts (the daily wall still stands):

```bash
$ bq query --use_legacy_sql=false 'SELECT * FROM `proj.rum.cluster`' --claude-is-a-budget-burner
[ai-aligned-bq] 🔥 claude invoked --claude-is-a-budget-burner. Per-query cap disabled. The money fire is on you.
```

The flag is stripped before reaching the real `bq`, so it never confuses the actual query.

### Free dry runs always pass through

Encouraging the right habit: if the agent runs its own `--dry_run`, the wrapper steps aside entirely (it costs nothing and is exactly what we want).

```bash
$ bq query --dry_run --use_legacy_sql=false 'SELECT * FROM `proj.rum.cluster`'
Query successfully validated. ... will process upper bound of 12737390469289 bytes of data.
```

## ⚙️ CONFIGURATION

All knobs are environment variables with sane defaults:

| Variable | Default | Meaning |
|----------|---------|---------|
| `AI_ALIGNED_BQ_MAX_BYTES` | `107374182400` (100 GiB) | Per-query hard cap on bytes scanned |
| `AI_ALIGNED_BQ_DAILY_USD` | `100` | Daily spend budget for agents (hard wall) |
| `AI_ALIGNED_BQ_PRICE_PER_TIB` | `6.25` | On-demand price per TiB (US multi-region) |
| `AI_ALIGNED_BQ_STATE_DIR` | `${XDG_STATE_HOME:-~/.local/state}/ai-aligned-bq` | Where the daily ledger lives |
| `AI_ALIGNED_BQ_BIN` | _(auto-detected)_ | Path to the real `bq` (for nonstandard installs) |

The daily ledger is a plain TSV at `$AI_ALIGNED_BQ_STATE_DIR/spend-YYYY-MM-DD.tsv` — `time`, `tool`, `bytes`, `usd` — so you can `awk` your agents' spending any way you like.

### A note on what this is (and isn't)

- The dollar figures assume **on-demand** pricing and ignore the monthly free TiB (conservative — better to over-estimate). If you're on **flat-rate / capacity reservations**, bytes scanned don't map to dollars at all; treat the caps as byte caps.
- The estimate is BigQuery's **upper bound** — the real job never bills *more*, and the injected `--maximum_bytes_billed` guarantees it.
- This is a per-developer safety net. The real org-wide backstop is a **BigQuery custom quota** (per-user bytes/day) in the GCP console. Wear both belts.

## 🌍 SUPPORTED AI TOOLS

Detection is powered by the shared [am-i-ai](https://github.com/ai-ecoverse/am-i-ai) library, so AI-Aligned-BQ constrains the same roster as the rest of the ecosystem: Claude Code, Codex CLI, Gemini, Qwen, Aider, Amp, Cursor, Copilot, Droid, Crush, Goose, Grok Build, Kimi, OpenCode, OpenHands, Auggie, Cline, Roo, Windsurf, Zed, Pi, and friends.

## 🧪 DEVELOPMENT

```bash
shellcheck executable_bq install.sh test.sh
./test.sh   # offline; stubs bq, needs no GCP credentials
```

## 🔗 Related Projects

Part of the **[AI Ecoverse](https://github.com/ai-ecoverse/.github)**:

- **[ai-aligned-git](https://github.com/ai-ecoverse/ai-aligned-git)** — git wrapper for safe staging + proper AI attribution
- **[ai-aligned-gh](https://github.com/ai-ecoverse/ai-aligned-gh)** — GitHub CLI wrapper for proper AI attribution
- **[am-i-ai](https://github.com/ai-ecoverse/am-i-ai)** — shared AI detection library (powers this tool)
- **[yolo](https://github.com/ai-ecoverse/yolo)** — AI CLI launcher with worktree isolation

## License

Apache-2.0
