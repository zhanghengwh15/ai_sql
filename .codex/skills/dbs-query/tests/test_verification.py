import json
import sys
import unittest
from pathlib import Path

SKILL_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(SKILL_DIR))

from scripts.verification import (  # noqa: E402
    EvidenceError,
    compare_result_sets,
    validate_evidence,
)


class EvidenceContractTests(unittest.TestCase):
    def load_fixture(self, name):
        return json.loads((SKILL_DIR / "fixtures" / name).read_text(encoding="utf-8"))

    def test_valid_evidence_fixture_is_machine_checkable(self):
        evidence = validate_evidence(self.load_fixture("verification_evidence.json"))
        self.assertEqual(1, evidence["schemaVersion"])
        self.assertEqual("PASS", evidence["rewriteComparison"]["conclusion"])

    def test_invalid_fixture_rejects_rows_secrets_and_bad_limit(self):
        with self.assertRaises(EvidenceError):
            validate_evidence(self.load_fixture("verification_evidence_invalid.json"))

    def test_evidence_rejects_raw_sql_or_profile_fields(self):
        evidence = self.load_fixture("verification_evidence.json")
        evidence["profile"] = "production"
        with self.assertRaises(EvidenceError):
            validate_evidence(evidence)

    def test_illegal_json_fixture_requires_runtime_semantic_verification(self):
        fixture = self.load_fixture("illegal_json_comparison.json")
        self.assertEqual("NOT_VERIFIED", fixture["conclusion"])
        self.assertEqual(
            "INVALID_JSON_DOCUMENT", fixture["jsonValueReturning"]["errorCode"]
        )
        self.assertEqual(
            "INVALID_JSON_DOCUMENT", fixture["rewrittenExpression"]["errorCode"]
        )
        encoded = json.dumps(fixture)
        self.assertNotIn("rowValues", encoded)
        self.assertNotIn("rows", encoded)

    def test_compare_requires_same_constraints_from_caller_and_finds_first_null_diff(self):
        summary = compare_result_sets(
            {"sql": "SELECT id, amount FROM t", "targetAlias": "confirmed-mysql8-readonly", "whereSummary": "id > 0", "orderBySummary": "id ASC", "limit": 100, "columns": ["id", "amount"], "rows": [[1, None], [2, 3]]},
            {"sql": "SELECT id, CAST(amount AS DECIMAL) FROM t", "targetAlias": "confirmed-mysql8-readonly", "whereSummary": "id > 0", "orderBySummary": "id ASC", "limit": 100, "columns": ["id", "amount"], "rows": [[1, 0], [2, 3]]},
            target_alias="confirmed-mysql8-readonly",
            where_summary="id > 0",
            order_by_summary="id ASC",
            limit=100,
        )
        self.assertEqual("FAIL", summary["conclusion"])
        self.assertEqual(
            {"rowIndex": 0, "columnIndex": 1, "reason": "NULL_SEMANTICS"},
            summary["firstDifference"],
        )
        self.assertNotIn("rows", json.dumps(summary))
        self.assertNotIn("amount", json.dumps(summary["firstDifference"]))

    def test_compare_pass_summary_contains_hashes_and_no_row_values(self):
        summary = compare_result_sets(
            {"sql": "SELECT id FROM t", "targetAlias": "confirmed-mysql8-readonly", "whereSummary": "id > 0", "orderBySummary": "id ASC", "limit": 100, "columns": ["id"], "rows": [[1], [2]]},
            {"sql": "SELECT id FROM t WHERE id > 0", "targetAlias": "confirmed-mysql8-readonly", "whereSummary": "id > 0", "orderBySummary": "id ASC", "limit": 100, "columns": ["id"], "rows": [[1], [2]]},
            target_alias="confirmed-mysql8-readonly",
            where_summary="id > 0",
            order_by_summary="id ASC",
            limit=100,
        )
        self.assertEqual("PASS", summary["conclusion"])
        self.assertRegex(summary["beforeSqlSha256"], r"^[0-9a-f]{16}$")
        self.assertNotIn("1", json.dumps(summary["firstDifference"]))

    def test_compare_rejects_target_or_limit_mismatch(self):
        base = {"columns": ["id"], "rows": [[1]], "targetAlias": "a", "whereSummary": "id > 0", "orderBySummary": "id ASC", "limit": 100}
        changed = dict(base, targetAlias="b")
        with self.assertRaises(EvidenceError):
            compare_result_sets(base, changed, target_alias="a", where_summary="id > 0", order_by_summary="id ASC", limit=100)


if __name__ == "__main__":
    unittest.main()
