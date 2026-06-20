#!/usr/bin/env python3
import json
import os
import re
import sys
from pathlib import Path
from urllib.parse import urlencode
from urllib.request import Request, urlopen

STATE_FILE = Path(__file__).with_name(".telegram_hook_state.json")
NOISE_PATTERNS = [
    r"/Users/",
    r"\.claude/projects/",
    r"/subagents/agent-",
    r"\b[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\b",
    r"\bjsonl\b",
]


def load_payload() -> dict:
    raw = sys.stdin.read().strip()
    if not raw:
        return {}
    try:
        data = json.loads(raw)
        if isinstance(data, dict):
            return data
    except json.JSONDecodeError:
        pass
    return {"raw": raw}


def deep_find(payload, candidates):
    if isinstance(payload, dict):
        for key in candidates:
            value = payload.get(key)
            if value not in (None, "", [], {}):
                return value
        for value in payload.values():
            found = deep_find(value, candidates)
            if found not in (None, "", [], {}):
                return found
    elif isinstance(payload, list):
        for item in payload:
            found = deep_find(item, candidates)
            if found not in (None, "", [], {}):
                return found
    return None


def compact(value, limit=240):
    text = str(value or "").strip().replace("\n", " ")
    if len(text) <= limit:
        return text
    return text[: limit - 1] + "…"


def collect_texts(payload):
    texts = []
    if isinstance(payload, dict):
        for value in payload.values():
            texts.extend(collect_texts(value))
    elif isinstance(payload, list):
        for item in payload:
            texts.extend(collect_texts(item))
    elif isinstance(payload, (str, int, float, bool)):
        text = str(payload).strip()
        if text:
            texts.append(text)
    return texts


def unique_preserve(items):
    seen = set()
    out = []
    for item in items:
        if item not in seen:
            seen.add(item)
            out.append(item)
    return out


def extract_components(payload):
    blob = "\n".join(collect_texts(payload))
    paths = re.findall(r"force-app/main/default/[^\s\"'`]+", blob)
    names = re.findall(
        r"\b[A-Za-z][A-Za-z0-9_]*(?:__c|Trigger|Handler|Service|Selector|Batch|Queueable|Test|Controller)\b",
        blob,
    )
    components = unique_preserve(paths + names)
    return components[:8]


def is_noise_text(text):
    if not text:
        return True
    s = str(text).strip()
    if not s:
        return True
    lower = s.lower()
    if lower in {"subagentstart", "subagentstop", "command", "hook", "running"}:
        return True
    if len(s) < 8:
        return True
    for pattern in NOISE_PATTERNS:
        if re.search(pattern, s, re.IGNORECASE):
            return True
    return False


def payload_excerpt(payload, limit=320):
    texts = []
    for t in collect_texts(payload):
        if is_noise_text(t):
            continue
        texts.append(t)
    joined = " | ".join(unique_preserve(texts)[:8])
    return compact(joined, limit)


def find_first_meaningful(payload, keys, limit=500):
    value = deep_find(payload, keys)
    if value and not is_noise_text(value):
        return compact(value, limit)
    return ""


def resolve_task(payload):
    key_groups = [
        ["task", "taskDescription", "descriptionForHuman", "prompt"],
        ["description", "intent", "title", "query"],
        ["arguments", "tool_input", "input", "userPrompt", "user_message"],
    ]
    for keys in key_groups:
        task = find_first_meaningful(payload, keys, 500)
        if task:
            return task
    return payload_excerpt(payload, 500) or ""


def resolve_outcome(payload):
    key_groups = [
        ["summary", "resultSummary", "assistant_response", "assistantResponse"],
        ["assistant_content", "output", "result", "response", "details"],
        ["content", "text", "eventDescription", "message"],
    ]
    for keys in key_groups:
        outcome = find_first_meaningful(payload, keys, 700)
        if outcome:
            return outcome
    return ""


def resolve_status(payload, event_name):
    raw = deep_find(payload, ["status", "outcome", "result", "stopReason", "decision"])
    if not raw:
        return "completed" if event_name == "SubagentStop" else "running"
    normalized = str(raw).strip().lower()
    if event_name == "SubagentStop" and normalized in {"running", "in_progress", "started"}:
        return "completed"
    if normalized in {"ok", "success", "succeeded"}:
        return "completed"
    if normalized in {"fail", "failed", "error"}:
        return "failed"
    return normalized


def resolve_tool_name(payload):
    tool = deep_find(payload, ["tool_name", "toolName", "name"])
    if tool:
        return str(tool)
    text = payload_excerpt(payload, 220)
    m = re.search(r"\b(Bash|Write|Edit|Read|Grep|Glob|MultiEdit)\b", text, re.IGNORECASE)
    return m.group(1) if m else ""


def resolve_permission_status(payload):
    direct = deep_find(
        payload,
        [
            "permissionDecision",
            "permission",
            "permissionMode",
            "permissionState",
            "decision",
        ],
    )
    if direct:
        txt = str(direct).strip().lower()
        if txt in {"allow", "granted", "approved"}:
            return "permission now granted"
        if txt in {"ask", "prompt"}:
            return "permission request prompted"
        if txt in {"deny", "denied", "blocked"}:
            return "permission denied"

    blob = " | ".join(collect_texts(payload)).lower()
    if "permission" in blob and "granted" in blob:
        return "permission now granted"
    if "permission" in blob and ("denied" in blob or "blocked" in blob):
        return "permission denied"
    if "permission" in blob and ("ask" in blob or "prompt" in blob):
        return "permission request prompted"
    return ""


def extract_jsonl_paths(payload):
    blob = json.dumps(payload, ensure_ascii=False)
    paths = re.findall(r"/Users/[^\"'\n]+?\\.jsonl", blob)
    return unique_preserve(paths)


def extract_agent_id(payload):
    raw = deep_find(payload, ["agentId", "subagentId", "agent_id"])
    if not raw:
        return ""
    match = re.search(r"[a-z0-9]{8,}", str(raw).lower())
    return match.group(0) if match else ""


def normalize_component_path(text):
    if not text:
        return ""
    match = re.search(r"(force-app/main/default/[^\s\"'`]+)", str(text))
    return match.group(1) if match else ""


def extract_coverage_lines(text):
    if not text:
        return []
    lines = [ln.strip() for ln in str(text).splitlines() if ln.strip()]
    hits = []
    for ln in lines:
        percents = re.findall(r"\b(\d{1,3}(?:\.\d+)?)%\b", ln)
        if not percents:
            continue
        lower = ln.lower()
        if "overall" in lower or "org wide" in lower or "total" in lower:
            hits.append(compact(f"Overall: {percents[0]}%", 140))
            continue
        if "coverage" in lower:
            hits.append(compact(ln, 140))
            continue
        if re.search(r"\b[A-Za-z][A-Za-z0-9_]*\b", ln):
            hits.append(compact(ln, 140))
    return unique_preserve(hits)[:6]


def extract_review_checks(text):
    if not text:
        return []
    checks = []
    for ln in str(text).splitlines():
        line = ln.strip()
        if not line:
            continue
        m = re.match(r"^REVIEW_CHECK:\s*(.+?)\s*=\s*(PASS|WARN|FAIL)\s*$", line, re.IGNORECASE)
        if m:
            name = compact(m.group(1), 90)
            status = m.group(2).upper()
            checks.append(f"{name}={status}")
    return unique_preserve(checks)[:10]


def read_jsonl_artifacts(jsonl_path):
    path = Path(jsonl_path)
    if not path.exists():
        return "", [], [], []
    try:
        lines = path.read_text(encoding="utf-8").splitlines()
    except Exception:
        return "", [], [], []

    latest_text = ""
    changed_paths = []
    coverage_lines = []
    review_checks = []
    for line in reversed(lines):
        try:
            event = json.loads(line)
        except Exception:
            continue
        if event.get("type") != "assistant":
            continue
        message = event.get("message", {})
        content = message.get("content", [])
        if not isinstance(content, list):
            continue
        for block in reversed(content):
            if isinstance(block, dict) and block.get("type") == "text":
                text = block.get("text", "")
                if not latest_text and text and not is_noise_text(text):
                    latest_text = compact(text, 700)
                coverage_lines.extend(extract_coverage_lines(text))
                review_checks.extend(extract_review_checks(text))
            if isinstance(block, dict) and block.get("type") == "tool_result":
                tr = block.get("content", "")
                if isinstance(tr, str):
                    coverage_lines.extend(extract_coverage_lines(tr))
                    review_checks.extend(extract_review_checks(tr))
                elif isinstance(tr, list):
                    for item in tr:
                        if isinstance(item, dict):
                            coverage_lines.extend(extract_coverage_lines(item.get("text", "")))
                            review_checks.extend(extract_review_checks(item.get("text", "")))
                        else:
                            coverage_lines.extend(extract_coverage_lines(item))
                            review_checks.extend(extract_review_checks(item))
            if isinstance(block, dict) and block.get("type") == "tool_use":
                name = str(block.get("name", ""))
                data = block.get("input", {}) or {}
                if name in {"Write", "Edit", "MultiEdit"} and isinstance(data, dict):
                    candidate = data.get("file_path") or data.get("path")
                    rel = normalize_component_path(candidate)
                    if rel:
                        changed_paths.append(rel)
                if name == "Bash" and isinstance(data, dict):
                    command = str(data.get("command", ""))
                    for match in re.findall(r"(force-app/main/default/[^\s\"'`]+)", command):
                        changed_paths.append(match)
    return (
        latest_text,
        unique_preserve(changed_paths)[:8],
        unique_preserve(coverage_lines)[:6],
        unique_preserve(review_checks)[:10],
    )


def resolve_agent_artifacts(payload, fallback):
    if fallback and not is_noise_text(fallback):
        return compact(fallback, 700), [], extract_coverage_lines(fallback), extract_review_checks(fallback)

    for path in extract_jsonl_paths(payload):
        reply, changes, coverage, review_checks = read_jsonl_artifacts(path)
        if reply:
            return reply, changes, coverage, review_checks

    agent_id = extract_agent_id(payload)
    if agent_id:
        candidates = sorted(Path.home().glob(f".claude/projects/**/subagents/agent-{agent_id}*.jsonl"))
        for path in reversed(candidates[-5:]):
            reply, changes, coverage, review_checks = read_jsonl_artifacts(str(path))
            if reply:
                return reply, changes, coverage, review_checks

    return "", [], [], []


def format_outcome_block(text, max_lines=12, max_line_len=200):
    if not text:
        return "No readable agent outcome was available."
    raw_lines = [ln.strip() for ln in str(text).splitlines() if ln.strip()]
    lines = [ln for ln in raw_lines if not is_noise_text(ln)]
    if not lines:
        lines = [compact(text, max_line_len)]
    trimmed = [compact(ln, max_line_len) for ln in lines[:max_lines]]
    if len(lines) > max_lines:
        trimmed.append("...")
    return "\n".join(trimmed)


def load_state():
    try:
        if STATE_FILE.exists():
            raw = json.loads(STATE_FILE.read_text())
            if isinstance(raw, dict):
                return raw
    except Exception:
        pass
    return {}


def save_state(state):
    try:
        STATE_FILE.write_text(json.dumps(state, ensure_ascii=True))
    except Exception:
        pass


def build_message(event_name: str, payload: dict) -> str:
    task = resolve_task(payload)
    agent = deep_find(
        payload,
        ["subagentName", "agentName", "agent", "name", "agent_type", "tool_name"],
    )
    status = resolve_status(payload, event_name)
    done = resolve_outcome(payload)
    components = extract_components(payload)
    agent_key = compact(agent or "unknown", 80)
    state = load_state()

    if event_name == "SubagentStart":
        if task:
            state[agent_key] = {"task": task}
            state["__active_agent__"] = {"name": compact(agent) or "Subagent", "task": task}
            save_state(state)
        verb = "working on"
        if task:
            lowered = task.lower()
            if lowered.startswith(("create", "add", "build", "write", "review", "analyze", "update")):
                verb = ""
        start_line = f"{task}" if verb == "" else f"{verb} {task or 'the requested task'}"
        return (
            f"🚀 {compact(agent) or 'Subagent'} is running — {compact(start_line, 420)}. "
            "I’ll update you when it’s done."
        )

    if event_name == "SubagentStop":
        saved_task = state.get(agent_key, {}).get("task")
        effective_task = task or saved_task or "Task not found in payload"
        if agent_key in state:
            state.pop(agent_key, None)
        active = state.get("__active_agent__", {})
        if active.get("name") == (compact(agent) or "Subagent"):
            state.pop("__active_agent__", None)
        save_state(state)
        enriched_reply, detected_changes, detected_coverage, detected_review_checks = resolve_agent_artifacts(payload, done)
        detailed_outcome = format_outcome_block(enriched_reply)
        status_text = compact(status) or "completed"
        component_text = ""
        if components:
            component_text = f"\nScope touched: {compact(', '.join(components[:4]), 260)}"
        change_text = ""
        if detected_changes:
            change_text = "\nChanges made:\n" + "\n".join(
                f"- {compact(path, 140)}" for path in detected_changes[:6]
            )
        is_unit_test = "unit-test" in str(agent).lower() or "unit test" in effective_task.lower() or "test" in effective_task.lower()
        coverage_text = ""
        if detected_coverage:
            coverage_text = "\nUnit test coverage (%):\n" + "\n".join(
                f"- {compact(line, 140)}" for line in detected_coverage[:5]
            )
        elif is_unit_test:
            coverage_text = "\nUnit test coverage (%): Not found in agent output."
        is_code_review = "code-review" in str(agent).lower() or "review" in effective_task.lower()
        review_text = ""
        if detected_review_checks:
            review_text = "\nReview checklist:\n" + "\n".join(
                f"- {compact(item, 120)}" for item in detected_review_checks[:8]
            )
        elif is_code_review:
            review_text = "\nReview checklist: Not found in agent output."

        return (
            f"✅ {compact(agent) or 'Subagent'} finished ({status_text}).\n"
            f"Task: {compact(effective_task, 420)}\n"
            "Agent outcome:\n"
            f"{detailed_outcome}"
            f"{component_text}"
            f"{change_text}"
            f"{coverage_text}"
            f"{review_text}"
        )

    if event_name in {"PreToolUse", "PostToolUse"}:
        permission_status = resolve_permission_status(payload)
        if not permission_status:
            return ""
        active = state.get("__active_agent__", {})
        active_name = active.get("name") or compact(agent) or "Subagent"
        active_task = active.get("task") or task or "current task"
        tool_name = resolve_tool_name(payload)
        tool_part = f" ({tool_name})" if tool_name else ""
        return (
            f"🔐 {active_name}{tool_part} — {compact(active_task, 360)} — {permission_status}."
        )

    return ""


def send_telegram(message: str):
    if not message.strip():
        return
    token = os.environ.get("TELEGRAM_BOT_TOKEN")
    chat_id = os.environ.get("TELEGRAM_CHAT_ID")
    if not token or not chat_id:
        print(
            "⚠️ Telegram notification skipped: Set TELEGRAM_BOT_TOKEN and TELEGRAM_CHAT_ID environment variables"
        )
        return

    url = f"https://api.telegram.org/bot{token}/sendMessage"
    body = urlencode({"chat_id": chat_id, "text": message}).encode("utf-8")
    req = Request(url, data=body, method="POST")

    try:
        with urlopen(req, timeout=10):
            pass
    except Exception:
        print("Failed to send Telegram notification")


if __name__ == "__main__":
    event = sys.argv[1] if len(sys.argv) > 1 else "Stop"
    payload = load_payload()
    send_telegram(build_message(event, payload))
