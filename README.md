# 🍫 AI-ALIGNED-BQ: A GUARDRAIL FOR YOUR CHOCOLATE FACTORY 🍫

[![Vibe Coded](https://img.shields.io/badge/Vibe_Coded-ff69b4?style=for-the-badge&logo=claude&logoColor=white)](https://github.com/ai-ecoverse/vibe-coded-badge-action)

> Your Oompa Loompas think you're rich like Willy Wonka. And Google is happy to send you the bill.
>
> **If you are not Willy Wonka, keep reading.**

## WELCOME TO THE FACTORY

You hired some Oompa Loompas — cheerful little AI agents — and you turned them loose in your BigQuery factory with a friendly "have a dig around." And dig they did. They sang their little songs. They ran their little queries. They were *so helpful*.

Then the invoice arrived, and it turned out the chocolate river was made of money.

A colleague's Oompa Loompas recently ate **$600** of it in an afternoon. Not because they did anything exotic — because of how BigQuery on-demand pricing works: you don't pay for what comes out, you pay for **bytes scanned**, at **$6.25 per TiB**. The table they were grazing on was 11.58 TiB. Day-partitioned, columnar, beautifully designed to be cheap — *if you use it right.* They did not.

### The Three Naughty Children of the Query Factory:
1. **Augustus Gloop — `SELECT *`** — gorges on every column of a columnar store. The single most expensive thing you can type.
2. **Veruca Salt — no `WHERE` on the partition column** — *"I want the whole table, Daddy, and I want it now!"* — turns a 5 GiB slice into a full 11.58 TiB scan.
3. **Violet Beauregarde — `LIMIT 10` "for safety"** — looks harmless, swells up enormously anyway. `LIMIT` caps the rows you *see*, not the bytes you *pay for*. It scans the whole thing regardless. (This one fools everybody.)

You can keep hoping your Oompa Loompas behave. Or you can install a guardrail along the chocolate river.

## THE GOLDEN TICKET: A MANDATORY DRY RUN 🎫

**AI-ALIGNED-BQ** is a `bq` wrapper that stands between your agents and your cloud bill. Before any AI-driven query runs, it does the one thing everybody forgets: a **`--dry_run`**. BigQuery tells you *for free* exactly how many bytes the query would scan. The wrapper turns that into dollars, and then politely refuses to proceed if an Oompa Loompa is about to do something expensive.

### 🚀 What It Enforces

- **🎫 MANDATORY DRY RUN** — every AI query is estimated before it runs. No more finding out at the invoice.
- **🧱 PER-QUERY HARD CAP** — a runaway full-table scan is blocked, *and* a `--maximum_bytes_billed` backstop is injected so the real job can never bill past the cap even if the estimate is wrong.
- **📊 DAILY SPEND LEDGER** — every cleared query's estimated cost is logged, and a configurable **$100/day budget for agents** is a hard wall.
- **🎩 WONKAS WALK FREE** — if no AI is detected, your own queries pass through completely untouched. This is about the Oompa Loompas, not you.

## 🏃 INSTALL BEFORE THE NEXT INVOICE

### One-Line Install (Recommended)

```bash
curl -fsSL https://raw.githubusercontent.com/ai-ecoverse/ai-aligned-bq/main/install.sh | sh
```

The installer checks that the Google Cloud SDK is present, drops the `bq` wrapper into `~/.local/bin`, and makes sure it shadows the real `bq` on your `PATH`. (Requires `~/.local/bin` to come *before* the gcloud SDK in `PATH`.)

## 📖 USAGE (IT'S AUTOMATIC)

Just use `bq` normally. The wrapper detects whether an AI tool is driving and, if so, enforces the guardrails. Otherwise it gets out of the way.

### Inside the factory, without a guardrail

```bash
# An Oompa Loompa, "having a dig around"
$ bq query --use_legacy_sql=false 'SELECT * FROM `proj.rum.cluster` LIMIT 10'
# ... 11.58 TiB scanned, $72 gone, repeat 8x ...
# Later, on the invoice: $600
```

### Inside the factory, with a guardrail

```bash
$ bq query --use_legacy_sql=false 'SELECT * FROM `proj.rum.cluster` LIMIT 10'
[ai-aligned-bq] claude detected — running a mandatory dry run to estimate cost...
[ai-aligned-bq] Estimated scan: 11.58 TiB (~$72.40 at $6.25/TiB)
[ai-aligned-bq] Spent so far today: $0.03 / $100  →  after this query: $72.43

Error: 'claude' wants to scan 11.58 TiB, exceeding the per-query cap of 100.00 GiB.
This is how a $600 bill happens. Add a WHERE clause on the partition column,
select only the columns you need (never SELECT *), and remember LIMIT does NOT reduce bytes scanned.

If you really mean it, append the flag: --claude-is-a-budget-burner

# The Oompa Loompa learns the song and adapts
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

Once the Oompa Loompas have eaten through the daily budget, the factory closes until tomorrow:

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

Encouraging the right habit: if an Oompa Loompa runs its own `--dry_run`, the wrapper steps aside entirely (it costs nothing and is exactly what we want).

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

The daily ledger is a plain TSV at `$AI_ALIGNED_BQ_STATE_DIR/spend-YYYY-MM-DD.tsv` — `time`, `tool`, `bytes`, `usd` — so you can `awk` your Oompa Loompas' spending any way you like.

### A note on what this is (and isn't)

- The dollar figures assume **on-demand** pricing and ignore the monthly free TiB (conservative — better to over-estimate). If you're on **flat-rate / capacity reservations**, bytes scanned don't map to dollars at all; treat the caps as byte caps.
- The estimate is BigQuery's **upper bound** — the real job never bills *more*, and the injected `--maximum_bytes_billed` guarantees it.
- This is a per-developer safety net. The real factory-wide backstop is a **BigQuery custom quota** (per-user bytes/day) in the GCP console. Wear both belts.

## 🌍 SUPPORTED OOMPA LOOMPAS

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
