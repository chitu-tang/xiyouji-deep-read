#!/usr/bin/env python3
"""Minimal Volcengine Ark Web Search adapter for the Xiyouji research pipeline.

The API key is read only from ARK_API_KEY. This module never writes credentials
or raw responses to disk.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from typing import Any
from urllib import error, request

DEFAULT_BASE_URL = "https://ark.cn-beijing.volces.com/api/v3/responses"
DEFAULT_MODEL = "doubao-seed-2-1-pro-260628"


def _text_from_value(value: Any) -> list[str]:
    parts: list[str] = []
    if isinstance(value, str):
        return [value]
    if isinstance(value, list):
        for item in value:
            parts.extend(_text_from_value(item))
    elif isinstance(value, dict):
        for key in ("text", "content", "output_text"):
            if key in value:
                parts.extend(_text_from_value(value[key]))
    return parts


def _annotations_from_output(output: Any) -> list[dict[str, str]]:
    annotations: list[dict[str, str]] = []
    if not isinstance(output, list):
        return annotations
    for item in output:
        if not isinstance(item, dict):
            continue
        for content in item.get("content", []) or []:
            if not isinstance(content, dict):
                continue
            for annotation in content.get("annotations", []) or []:
                if not isinstance(annotation, dict):
                    continue
                url = annotation.get("url") or annotation.get("target_url")
                title = annotation.get("title") or annotation.get("source_title") or ""
                if url:
                    annotations.append({"title": str(title), "url": str(url)})
    return annotations


def search(
    query: str,
    *,
    api_key: str | None = None,
    model: str = DEFAULT_MODEL,
    max_keyword: int = 3,
    limit: int = 10,
    base_url: str = DEFAULT_BASE_URL,
    timeout: int = 60,
) -> dict[str, Any]:
    key = api_key or os.environ.get("ARK_API_KEY")
    if not key:
        raise RuntimeError("ARK_API_KEY is not set")

    payload = {
        "model": model,
        "input": [{
            "role": "user",
            "content": [{"type": "input_text", "text": query}],
        }],
        "tools": [{
            "type": "web_search",
            "max_keyword": max(1, min(max_keyword, 50)),
            "limit": max(1, min(limit, 50)),
        }],
        "max_tool_calls": 3,
    }
    body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
    req = request.Request(
        base_url,
        data=body,
        method="POST",
        headers={
            "Authorization": f"Bearer {key}",
            "Content-Type": "application/json",
        },
    )
    try:
        with request.urlopen(req, timeout=timeout) as response:
            raw = json.loads(response.read().decode("utf-8"))
    except error.HTTPError as exc:
        detail = exc.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"Ark Web Search HTTP {exc.code}: {detail[:500]}") from exc
    except error.URLError as exc:
        raise RuntimeError(f"Ark Web Search network error: {exc.reason}") from exc

    text_parts = _text_from_value(raw.get("output_text", ""))
    if not text_parts:
        text_parts = _text_from_value(raw.get("output", []))
    return {
        "query": query,
        "answer": "\n".join(part for part in text_parts if part),
        "sources": _annotations_from_output(raw.get("output", [])),
        "usage": raw.get("usage", {}),
        "raw_response_id": raw.get("id"),
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Search via Ark Web Search")
    parser.add_argument("query")
    parser.add_argument("--model", default=DEFAULT_MODEL)
    parser.add_argument("--max-keyword", type=int, default=3)
    parser.add_argument("--limit", type=int, default=10)
    args = parser.parse_args()
    try:
        result = search(
            args.query,
            model=args.model,
            max_keyword=args.max_keyword,
            limit=args.limit,
        )
    except RuntimeError as exc:
        print(str(exc), file=sys.stderr)
        return 1
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
