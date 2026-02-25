#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import re
import sys
import time
from typing import Any

DEFAULT_URL = "https://browserbench.org/Speedometer3.1/"
DEFAULT_BENCHMARK_TIMEOUT_SEC = 15 * 60
DEFAULT_NAV_TIMEOUT_MS = 60_000

TEXT_SNAPSHOT_JS = r"""
() => {
  const shadowBlocks = [];
  const seen = new Set();

  function walk(root) {
    if (!root || seen.has(root)) return;
    seen.add(root);

    let elements = [];
    try {
      elements = Array.from(root.querySelectorAll ? root.querySelectorAll('*') : []);
    } catch (_) {
      elements = [];
    }

    for (const el of elements) {
      try {
        if (el.shadowRoot) {
          const text = (el.shadowRoot.innerText || el.shadowRoot.textContent || "").trim();
          if (text) {
            shadowBlocks.push(text);
          }
          walk(el.shadowRoot);
        }
      } catch (_) {}
    }
  }

  walk(document);

  return {
    title: document.title || "",
    bodyText: document.body ? (document.body.innerText || document.body.textContent || "") : "",
    shadowText: shadowBlocks.join("\n"),
  };
}
"""


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Run Speedometer 3.1 in Playwright Firefox and print the final score."
    )
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument(
        "--headless",
        dest="headless",
        action="store_true",
        help="Run without a visible browser window (default).",
    )
    mode.add_argument(
        "--headful",
        "--headed",
        dest="headless",
        action="store_false",
        help="Run with a visible Firefox window.",
    )
    parser.set_defaults(headless=True)

    parser.add_argument("--url", default=DEFAULT_URL, help=f"Benchmark URL (default: {DEFAULT_URL})")
    parser.add_argument(
        "--timeout-seconds",
        type=float,
        default=DEFAULT_BENCHMARK_TIMEOUT_SEC,
        help=f"Max time to wait for benchmark completion (default: {DEFAULT_BENCHMARK_TIMEOUT_SEC}s).",
    )
    parser.add_argument(
        "--nav-timeout-ms",
        type=int,
        default=DEFAULT_NAV_TIMEOUT_MS,
        help=f"Navigation timeout for page load and Start button discovery (default: {DEFAULT_NAV_TIMEOUT_MS}).",
    )
    parser.add_argument(
        "--json",
        action="store_true",
        help="Print result as JSON instead of human-readable text.",
    )
    parser.add_argument(
        "--screenshot",
        default="",
        help="Optional path to write a screenshot after the run finishes.",
    )
    return parser.parse_args()


def extract_score(text: str) -> dict[str, str] | None:
    compact = re.sub(r"\s+", " ", text).strip()
    if not compact:
        return None

    patterns = [
        re.compile(
            r"score\s*[: ]+\s*([0-9]+(?:\.[0-9]+)?)\s*(?:[±\+\-]\s*([0-9]+(?:\.[0-9]+)?))?",
            re.IGNORECASE,
        ),
        re.compile(
            r"([0-9]+(?:\.[0-9]+)?)\s*±\s*([0-9]+(?:\.[0-9]+)?)",
            re.IGNORECASE,
        ),
    ]

    for idx, pattern in enumerate(patterns):
        matches = list(pattern.finditer(compact))
        if not matches:
            continue

        # Prefer a match near the word "Score" when using the generic ± pattern.
        chosen = matches[-1]
        if idx == 1:
            for m in reversed(matches):
                start = max(0, m.start() - 80)
                context = compact[start : m.end() + 80]
                if re.search(r"\bscore\b", context, re.IGNORECASE):
                    chosen = m
                    break

        score = chosen.group(1)
        ci = chosen.group(2) if chosen.lastindex and chosen.lastindex >= 2 else None
        return {"score": score, "confidence_interval": ci or ""}

    return None


def click_start(page: Any, timeout_ms: int) -> None:
    candidates = [
        page.get_by_role("button", name=re.compile(r"start test", re.IGNORECASE)),
        page.locator("text=/^Start Test$/i"),
        page.locator("button:has-text('Start Test')"),
    ]
    last_error: Exception | None = None
    for locator in candidates:
        try:
            locator.first.wait_for(state="visible", timeout=timeout_ms)
            locator.first.click(timeout=timeout_ms)
            return
        except Exception as exc:  # noqa: BLE001 - fallback across locator variants
            last_error = exc
    if last_error is not None:
        raise last_error
    raise RuntimeError("Start button not found")


def poll_result(page: Any, timeout_seconds: float) -> dict[str, str]:
    deadline = time.monotonic() + timeout_seconds
    last_text = ""

    while time.monotonic() < deadline:
        snapshot = page.evaluate(TEXT_SNAPSHOT_JS)
        text = "\n".join(
            x for x in [snapshot.get("title", ""), snapshot.get("bodyText", ""), snapshot.get("shadowText", "")] if x
        )
        last_text = text
        result = extract_score(text)
        if result and result["score"]:
            return result
        time.sleep(2.0)

    tail = re.sub(r"\s+", " ", last_text)[-500:]
    raise TimeoutError(f"Timed out waiting for benchmark result. Last page text tail: {tail}")


def main() -> int:
    args = parse_args()

    try:
        try:
            from playwright.sync_api import TimeoutError as PlaywrightTimeoutError
            from playwright.sync_api import sync_playwright
        except ImportError:
            print(
                "Error: Playwright is not installed. Run 'pip install playwright' and 'playwright install firefox'.",
                file=sys.stderr,
            )
            return 1

        with sync_playwright() as pw:
            browser = pw.firefox.launch(headless=args.headless)
            context = browser.new_context(viewport={"width": 1440, "height": 900})
            page = context.new_page()
            page.set_default_timeout(args.nav_timeout_ms)

            print(f"Opening {args.url}", file=sys.stderr)
            page.goto(args.url, wait_until="domcontentloaded", timeout=args.nav_timeout_ms)
            try:
                page.wait_for_load_state("networkidle", timeout=10_000)
            except PlaywrightTimeoutError:
                # Speedometer may keep background activity; proceed anyway.
                pass

            print("Starting Speedometer...", file=sys.stderr)
            click_start(page, timeout_ms=args.nav_timeout_ms)

            print("Waiting for result...", file=sys.stderr)
            result = poll_result(page, timeout_seconds=args.timeout_seconds)

            if args.screenshot:
                page.screenshot(path=args.screenshot, full_page=True)
                print(f"Saved screenshot: {args.screenshot}", file=sys.stderr)

            output = {
                "url": args.url,
                "headless": bool(args.headless),
                "score": result["score"],
            }
            if result.get("confidence_interval"):
                output["confidence_interval"] = result["confidence_interval"]

            if args.json:
                print(json.dumps(output))
            else:
                if "confidence_interval" in output:
                    print(f"Speedometer score: {output['score']} ± {output['confidence_interval']}")
                else:
                    print(f"Speedometer score: {output['score']}")

            context.close()
            browser.close()
            return 0
    except KeyboardInterrupt:
        print("Interrupted", file=sys.stderr)
        return 130
    except Exception as exc:  # noqa: BLE001 - CLI tool should report readable error
        print(f"Error: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
