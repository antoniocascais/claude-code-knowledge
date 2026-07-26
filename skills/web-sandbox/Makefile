# web-sandbox — isolated web search/fetch via the official Claude Code CLI in Docker.
# Auth: reuses your host Claude login via read-only mount of the host credentials file.
# Audit: each search's full stream-json transcript is teed to ./logs.

IMAGE  := web-sandbox
NAME   := web-sandbox
MODEL  ?= sonnet
LOGDIR := logs
CREDS  := $(HOME)/.claude/.credentials.json

# The sandbox may use ONLY WebSearch/WebFetch. --tools is a hard allowlist on the
# tool *schema* (anything unnamed is stripped from the model's context), so it's
# future-proof: new built-in tools (Skill/Workflow/Cron*/ScheduleWakeup/Agent...)
# are excluded by construction, not by chasing a denylist. Kept ALLOW as the name.
ALLOW := WebSearch,WebFetch

.PHONY: build start stop status search audit shell

build:
	docker build -t $(IMAGE) .

# Reuses your existing host login: mounts ~/.claude/.credentials.json read-only.
# No token/.env step. Rebuild not needed on token rotation (mount is always current).
start:
	@test -f "$(CREDS)" || { echo "No host credentials at $(CREDS). Log in on the host first (run 'claude' and /login)."; exit 1; }
	@mkdir -p $(LOGDIR)
	docker run -d --name $(NAME) \
		-v $(CREDS):/home/node/.claude/.credentials.json:ro \
		--cap-drop ALL \
		--security-opt no-new-privileges \
		--pids-limit 512 \
		--memory 2g --cpus 2 \
		$(IMAGE)
	@echo 'sandbox up. search with: make search Q="your query"'

stop:
	-docker rm -f $(NAME)

status:
	@docker ps --filter name=$(NAME)

# Sandboxed search. Prints the answer to stdout; tees the full transcript
# (queries + fetched URLs + prompts) to logs/ for audit.
# Usage: make search Q="what changed in kubernetes 1.31 sidecar containers"
search:
	@test -n "$(Q)" || { echo 'usage: make search Q="your query"'; exit 1; }
	@mkdir -p $(LOGDIR)
	@ts=$$(date +%Y%m%d-%H%M%S); \
	docker exec $(NAME) claude -p "$(Q)" \
		--model $(MODEL) \
		--output-format stream-json --verbose \
		--tools "$(ALLOW)" \
		--allowedTools "$(ALLOW)" \
		--strict-mcp-config \
		--permission-mode dontAsk \
	  | tee $(LOGDIR)/search-$$ts.jsonl \
	  | jq -r 'select(.type=="result") | .result'

# What the most recent search actually did: search queries + fetched URLs.
audit:
	@f=$$(ls -t $(LOGDIR)/search-*.jsonl 2>/dev/null | head -1); \
	test -n "$$f" || { echo "no logs yet"; exit 0; }; \
	echo "== $$f =="; \
	jq -r 'select(.type=="assistant") | .message.content[]? | select(.type=="tool_use") | "\(.name): \(.input.query // .input.url // (.input|tostring))"' "$$f"

shell:
	docker exec -it $(NAME) bash
