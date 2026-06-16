.PHONY: health deploy logs test-run

REPO := $(shell git remote get-url origin 2>/dev/null | sed 's|.*github.com[:/]||; s|\.git$$||')

# Verify all three external dependencies are healthy.
health:
	@echo "=== gh CLI auth ==="
	@gh auth status 2>&1 | grep -q "Logged in" && echo "  ✅ authenticated" || echo "  ❌ not authed — run: gh auth login"
	@echo "=== GitHub Secrets ==="
	@SECRETS=$$(gh secret list --repo $(REPO) 2>/dev/null); \
	  for name in CLAUDE_ROUTINE_WEBHOOK_URL CLAUDE_ROUTINE_API_KEY FLOMO_API_TOKEN; do \
	    echo "$$SECRETS" | grep -q "$$name" && echo "  ✅ $$name" || echo "  ❌ $$name missing"; \
	  done
	@echo "=== Last 5 Workflow Runs ==="
	@OUT=$$(gh run list --repo $(REPO) --workflow flomo-logger-trigger.yml --limit 5 --json conclusion,startedAt 2>/dev/null); \
	  echo "$$OUT" | python3 -c 'import sys,json; data=sys.stdin.read().strip(); runs=json.loads(data) if data.startswith("[") else []; [print("  " + ("✅" if r["conclusion"]=="success" else ("⏳" if not r["conclusion"] else "❌")) + " " + r["startedAt"][:16] + "  " + (r["conclusion"] or "in_progress")) for r in runs] if runs else print("  (no runs yet — or not authed)")'
	@echo "=== flomo REST API ==="
	@if [ -n "$$FLOMO_API_TOKEN" ]; then \
	  CODE=$$(curl -s -X POST "https://flomoapp.com/api/v1/memo/" \
	    -H "Authorization: Bearer $$FLOMO_API_TOKEN" \
	    -H "Content-Type: application/json" \
	    -d '{"content": "#HEALTH-CHECK-DELETE-ME"}' \
	    | python3 -c "import sys,json; print(json.load(sys.stdin).get('code','?'))" 2>/dev/null); \
	  if [ "$$CODE" = "0" ]; then \
	    echo "  ✅ flomo write OK  ← delete '#HEALTH-CHECK-DELETE-ME' from flomo"; \
	  else \
	    echo "  ❌ flomo API code=$$CODE — token may lack write scope"; \
	  fi; \
	else \
	  echo "  (skip — export FLOMO_API_TOKEN=fmcp_... to test write access)"; \
	fi

# Copy SKILL.md to clipboard and open claude.ai for re-pasting.
deploy:
	@pbcopy < SKILL.md
	@echo "✅ SKILL.md copied to clipboard ($$(wc -l < SKILL.md | tr -d ' ') lines)"
	@echo "→ Paste into your claude.ai Routine system prompt and Save"
	@open "https://claude.ai" 2>/dev/null || true

# Show last 10 runs with timestamps and links.
logs:
	@gh run list --repo $(REPO) --workflow flomo-logger-trigger.yml --limit 10 \
	  --json conclusion,startedAt,url \
	  | python3 -c 'import sys,json; runs=json.load(sys.stdin); print("No runs yet.") if not runs else [print(("✅" if r["conclusion"]=="success" else ("⏳" if not r["conclusion"] else "❌")) + "  " + r["startedAt"][:16] + "  " + (r["conclusion"] or "in_progress") + "  " + r["url"]) for r in runs]'

# Manually fire the sync workflow and watch it run.
test-run:
	@echo "Triggering flomo-logger-trigger.yml on $(REPO)..."
	@gh workflow run flomo-logger-trigger.yml --repo $(REPO)
	@sleep 8
	@RUN_ID=$$(gh run list --repo $(REPO) --workflow flomo-logger-trigger.yml --limit 1 --json databaseId --jq '.[0].databaseId') && \
	  echo "Watching run $$RUN_ID..." && \
	  gh run watch $$RUN_ID --repo $(REPO) --exit-status
