#!/bin/bash
# Offline test suite for ai-aligned-bq.
# Stubs the real `bq` binary so no GCP credentials or network are required.
# The stub's dry-run byte count is controlled via STUB_BYTES.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WRAPPER="$SCRIPT_DIR/executable_bq"

PASS=0
FAIL=0

# --- Build a throwaway environment with a stub `bq` on PATH -----------------
STUB_DIR=$(mktemp -d)
STATE_DIR=$(mktemp -d)
cat > "$STUB_DIR/bq" <<'STUB'
#!/bin/bash
# Stub bq. Finds the subcommand (first non-flag token) and fakes output.
sub=""
skip=false
for a in "$@"; do
    if [ "$skip" = true ]; then skip=false; continue; fi
    case "$a" in
        --*=*) ;;
        --project_id|--location|--format) skip=true ;;
        --*|-*) ;;
        *) sub="$a"; break ;;
    esac
done
case "$sub" in
    version) echo "This is BigQuery CLI 9.9.9"; exit 0 ;;
    query)
        for a in "$@"; do [ "$a" = "--dry_run" ] && { \
            echo "Query successfully validated. Assuming the tables are not modified, running this query will process upper bound of ${STUB_BYTES:-1000000000} bytes of data."; exit 0; }; done
        echo "STUB-RAN-REAL-QUERY: $*"
        exit 0 ;;
    *) echo "STUB-RAN: $sub"; exit 0 ;;
esac
STUB
chmod +x "$STUB_DIR/bq"

run_wrapper() {
    # Force AI detection on, isolate ledger, put stub bq first on PATH.
    CLAUDECODE=1 CLAUDE_CODE_ENTRYPOINT=cli AMI_PASSTHROUGH="" \
    AI_ALIGNED_BQ_STATE_DIR="$STATE_DIR" \
    AI_ALIGNED_BQ_BIN="$STUB_DIR/bq" \
    "$WRAPPER" "$@" 2>&1
}

check() {
    local name="$1" expected="$2" got="$3"
    if echo "$got" | grep -q "$expected"; then
        echo "  ✓ $name"
        PASS=$((PASS + 1))
    else
        echo "  ✗ $name"
        echo "    expected to find: $expected"
        echo "    got: $got"
        FAIL=$((FAIL + 1))
    fi
}

echo "=== ai-aligned-bq test suite ==="

# 1. Small query within caps runs the real query.
out=$(STUB_BYTES=1000000000 run_wrapper query 'SELECT 1')
check "small query runs" "STUB-RAN-REAL-QUERY" "$out"
check "small query reports estimate" "Estimated scan" "$out"

# 2. Full-table scan (12 TiB) blocked by per-query cap.
out=$(STUB_BYTES=12000000000000 run_wrapper query 'SELECT * FROM big')
check "big query blocked" "exceeding the per-query cap" "$out"
if echo "$out" | grep -q "STUB-RAN-REAL-QUERY"; then
    echo "  ✗ big query should NOT have run"; FAIL=$((FAIL + 1))
else
    echo "  ✓ big query did not run"; PASS=$((PASS + 1))
fi

# 3. Override flag lets the big query through (and is stripped from real args).
out=$(STUB_BYTES=12000000000000 run_wrapper query 'SELECT * FROM big' --claude-is-a-budget-burner)
check "override runs big query" "STUB-RAN-REAL-QUERY" "$out"
check "override shames the burner" "budget-burner" "$out"
if echo "$out" | grep -q "budget-burner: SELECT\|is-a-budget-burner SELECT\|STUB-RAN-REAL-QUERY.*budget-burner"; then
    echo "  ✗ override flag leaked into real bq args"; FAIL=$((FAIL + 1))
else
    echo "  ✓ override flag stripped from real bq args"; PASS=$((PASS + 1))
fi

# 4. Daily budget is a hard wall even with the override flag.
out=$(STUB_BYTES=12000000000000 AI_ALIGNED_BQ_DAILY_USD=1 run_wrapper query 'SELECT * FROM big' --claude-is-a-budget-burner)
check "daily wall blocks even with override" "over the \$1 daily budget" "$out"

# 5. Explicit --dry_run passes straight through.
out=$(STUB_BYTES=12000000000000 run_wrapper query --dry_run 'SELECT * FROM big')
check "dry_run passes through" "upper bound of 12000000000000 bytes" "$out"

# 6. Non-query commands pass through untouched (no guardrail chatter).
out=$(run_wrapper version)
check "version passes through" "BigQuery CLI 9.9.9" "$out"
if echo "$out" | grep -q "ai-aligned-bq"; then
    echo "  ✗ version printed guardrail chatter"; FAIL=$((FAIL + 1))
else
    echo "  ✓ version is silent"; PASS=$((PASS + 1))
fi

# 7. Per-query cap is configurable via env.
out=$(STUB_BYTES=1000000000 AI_ALIGNED_BQ_MAX_BYTES=1 run_wrapper query 'SELECT 1')
check "configurable cap blocks small query" "exceeding the per-query cap" "$out"

rm -rf "$STUB_DIR" "$STATE_DIR"

echo
echo "=== $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ]
