"""Offline validation helpers for DBS read-only verification evidence.

The helpers deliberately accept result metadata but never include row values in
the comparison summary. They are safe to pass to an AI apply request.
"""

from __future__ import annotations

import hashlib
import re
from datetime import datetime
from typing import Any, Dict, Iterable, List, Mapping, Optional, Sequence


EVIDENCE_SCHEMA_VERSION = 1
_HASH16 = re.compile(r"^[0-9a-f]{16}$")
_CONCLUSIONS = {"PASS", "FAIL", "NOT_VERIFIED"}
_SENSITIVE_KEYS = {
    "password",
    "passwd",
    "cookie",
    "session",
    "sessionid",
    "csrf",
    "csrf_token",
    "token",
    "authorization",
    "secret",
    "credential",
    "profile",
}
_SENSITIVE_FIELD_NAMES = {
    "rows",
    "rowValues",
    "sampleRows",
    "rawRows",
    "resultSet",
    "fullSql",
    "sqlText",
    "sql",
    "query",
    "statement",
}
_NORMALIZED_SENSITIVE_KEYS = {item.replace("_", "") for item in _SENSITIVE_KEYS}


class EvidenceError(ValueError):
    """Raised when evidence is not safe or does not match the schema."""


def sql_hash_prefix(sql: str) -> str:
    if not isinstance(sql, str) or not sql.strip():
        raise EvidenceError("SQL must be a non-empty string")
    return hashlib.sha256(sql.encode("utf-8")).hexdigest()[:16]


def _reject_sensitive_keys(value: Any, path: str = "evidence") -> None:
    if isinstance(value, Mapping):
        for key, child in value.items():
            key_text = str(key)
            normalized_key = key_text.lower().replace("_", "")
            if normalized_key in _NORMALIZED_SENSITIVE_KEYS:
                raise EvidenceError(f"sensitive field is not allowed: {path}.{key_text}")
            if key_text in _SENSITIVE_FIELD_NAMES:
                raise EvidenceError(f"row or raw SQL field is not allowed: {path}.{key_text}")
            _reject_sensitive_keys(child, f"{path}.{key_text}")
    elif isinstance(value, (list, tuple)):
        for index, child in enumerate(value):
            _reject_sensitive_keys(child, f"{path}[{index}]")


def validate_evidence(evidence: Mapping[str, Any]) -> Dict[str, Any]:
    """Validate and return a JSON-safe evidence summary.

    The schema contains target/environment summaries, query constraints, row
    counts and hashes only. It intentionally has no result rows or credentials.
    """

    if not isinstance(evidence, Mapping):
        raise EvidenceError("evidence must be an object")
    _reject_sensitive_keys(evidence)
    required = {
        "schemaVersion",
        "dbsTargetAlias",
        "dbVersionSummary",
        "sqlModeSummary",
        "readonlyChecks",
        "rewriteComparison",
        "capturedAt",
    }
    missing = sorted(required - set(evidence))
    if missing:
        raise EvidenceError(f"missing required fields: {', '.join(missing)}")
    if evidence["schemaVersion"] != EVIDENCE_SCHEMA_VERSION:
        raise EvidenceError("unsupported evidence schemaVersion")
    if not isinstance(evidence["dbsTargetAlias"], str) or not evidence["dbsTargetAlias"].strip():
        raise EvidenceError("dbsTargetAlias must be a non-empty string")
    for field in ("dbVersionSummary", "sqlModeSummary"):
        if not isinstance(evidence[field], str):
            raise EvidenceError(f"{field} must be a string summary")
    try:
        datetime.fromisoformat(str(evidence["capturedAt"]).replace("Z", "+00:00"))
    except ValueError as exc:
        raise EvidenceError("capturedAt must be ISO-8601") from exc

    checks = evidence["readonlyChecks"]
    if not isinstance(checks, list) or not checks:
        raise EvidenceError("readonlyChecks must be a non-empty array")
    for index, check in enumerate(checks):
        if not isinstance(check, Mapping):
            raise EvidenceError(f"readonlyChecks[{index}] must be an object")
        for field in ("sqlSha256", "whereSummary", "orderBySummary", "limit", "rowCount"):
            if field not in check:
                raise EvidenceError(f"readonlyChecks[{index}] missing {field}")
        if not isinstance(check["sqlSha256"], str) or not _HASH16.fullmatch(check["sqlSha256"]):
            raise EvidenceError(f"readonlyChecks[{index}].sqlSha256 must be 16 lowercase hex chars")
        if not isinstance(check["limit"], int) or not 1 <= check["limit"] <= 1000:
            raise EvidenceError(f"readonlyChecks[{index}].limit must be between 1 and 1000")
        if not isinstance(check["rowCount"], int) or check["rowCount"] < 0 or check["rowCount"] > check["limit"]:
            raise EvidenceError(f"readonlyChecks[{index}].rowCount is invalid")

    comparison = evidence["rewriteComparison"]
    if not isinstance(comparison, Mapping):
        raise EvidenceError("rewriteComparison must be an object")
    for field in (
        "beforeSqlSha256",
        "afterSqlSha256",
        "whereSummary",
        "orderBySummary",
        "limit",
        "beforeRowCount",
        "afterRowCount",
        "firstDifference",
        "conclusion",
    ):
        if field not in comparison:
            raise EvidenceError(f"rewriteComparison missing {field}")
    for field in ("beforeSqlSha256", "afterSqlSha256"):
        if not isinstance(comparison[field], str) or not _HASH16.fullmatch(comparison[field]):
            raise EvidenceError(f"rewriteComparison.{field} must be 16 lowercase hex chars")
    if not isinstance(comparison["limit"], int) or not 1 <= comparison["limit"] <= 1000:
        raise EvidenceError("rewriteComparison.limit must be between 1 and 1000")
    for field in ("beforeRowCount", "afterRowCount"):
        if not isinstance(comparison[field], int) or comparison[field] < 0 or comparison[field] > comparison["limit"]:
            raise EvidenceError(f"rewriteComparison.{field} is invalid")
    if comparison["conclusion"] not in _CONCLUSIONS:
        raise EvidenceError("rewriteComparison.conclusion is invalid")
    first = comparison["firstDifference"]
    if first is not None:
        if not isinstance(first, Mapping) or not isinstance(first.get("rowIndex"), int) or not isinstance(first.get("columnIndex"), int):
            raise EvidenceError("firstDifference must contain rowIndex and columnIndex")
        if first["rowIndex"] < 0 or first["columnIndex"] < 0:
            raise EvidenceError("firstDifference indexes must be non-negative")
    return dict(evidence)


def compare_result_sets(
    before: Mapping[str, Any],
    after: Mapping[str, Any],
    *,
    target_alias: str,
    where_summary: str,
    order_by_summary: str,
    limit: int,
) -> Dict[str, Any]:
    """Compare metadata and rows, returning a value-free first-diff summary."""

    if not target_alias:
        raise EvidenceError("target_alias is required")
    if not isinstance(limit, int) or not 1 <= limit <= 1000:
        raise EvidenceError("limit must be between 1 and 1000")
    for side, result in (("before", before), ("after", after)):
        if not isinstance(result, Mapping) or not isinstance(result.get("columns"), Sequence) or not isinstance(result.get("rows"), Sequence):
            raise EvidenceError(f"{side} result must contain columns and rows")
        # The executor wrapper must attach these values to both sides. This
        # prevents comparing results collected from different targets/ranges.
        for field, expected in (
            ("targetAlias", target_alias),
            ("whereSummary", where_summary),
            ("orderBySummary", order_by_summary),
            ("limit", limit),
        ):
            if result.get(field) != expected:
                raise EvidenceError(f"{side}.{field} does not match comparison constraints")
    before_columns = list(before["columns"])
    after_columns = list(after["columns"])
    before_rows = list(before["rows"])
    after_rows = list(after["rows"])
    first_difference: Optional[Dict[str, Any]] = None
    reason = None
    if before_columns != after_columns:
        reason = "COLUMN_NAMES"
        first_difference = {"rowIndex": 0, "columnIndex": 0, "reason": reason}
    elif len(before_rows) != len(after_rows):
        reason = "ROW_COUNT"
        first_difference = {"rowIndex": min(len(before_rows), len(after_rows)), "columnIndex": 0, "reason": reason}
    else:
        for row_index, (before_row, after_row) in enumerate(zip(before_rows, after_rows)):
            if not isinstance(before_row, Sequence) or isinstance(before_row, (str, bytes)) or not isinstance(after_row, Sequence) or isinstance(after_row, (str, bytes)):
                raise EvidenceError("rows must be arrays")
            if len(before_row) != len(after_row):
                first_difference = {"rowIndex": row_index, "columnIndex": min(len(before_row), len(after_row)), "reason": "COLUMN_COUNT"}
                break
            for column_index, (before_value, after_value) in enumerate(zip(before_row, after_row)):
                if before_value != after_value or (before_value is None) != (after_value is None):
                    reason = "NULL_SEMANTICS" if (before_value is None) != (after_value is None) else "VALUE"
                    first_difference = {"rowIndex": row_index, "columnIndex": column_index, "reason": reason}
                    break
            if first_difference:
                break
    return {
        "targetAlias": target_alias,
        "whereSummary": where_summary,
        "orderBySummary": order_by_summary,
        "limit": limit,
        "beforeSqlSha256": before.get("sqlSha256") or sql_hash_prefix(str(before.get("sql", ""))),
        "afterSqlSha256": after.get("sqlSha256") or sql_hash_prefix(str(after.get("sql", ""))),
        "beforeRowCount": len(before_rows),
        "afterRowCount": len(after_rows),
        "columnCount": len(before_columns),
        "firstDifference": first_difference,
        "conclusion": "PASS" if first_difference is None else "FAIL",
    }
