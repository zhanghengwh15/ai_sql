import io
import json
import stat
import sys
import tempfile
import threading
import unittest
import urllib.parse
from contextlib import redirect_stderr, redirect_stdout
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

SKILL_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(SKILL_DIR))

from scripts import dbs  # noqa: E402


class FakeArcheryHandler(BaseHTTPRequestHandler):
    counts = {
        "login": 0,
        "authenticate": 0,
        "instances": 0,
        "databases": 0,
        "query": 0,
        "desc": 0,
    }

    def log_message(self, format, *args):
        return

    def send_json(self, payload, cookies=()):
        body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        for cookie in cookies:
            self.send_header("Set-Cookie", cookie)
        self.end_headers()
        self.wfile.write(body)

    def require_session(self):
        cookie = self.headers.get("Cookie", "")
        csrf = self.headers.get("X-CSRFToken", "")
        return "sessionid=test-session" in cookie and csrf == "test-csrf"

    def do_GET(self):
        parsed = urllib.parse.urlparse(self.path)
        if parsed.path == "/login/":
            type(self).counts["login"] += 1
            self.send_response(200)
            self.send_header("Set-Cookie", "csrftoken=test-csrf; Path=/")
            self.end_headers()
            return
        if not self.require_session():
            self.send_response(403)
            self.end_headers()
            return
        if parsed.path == "/group/user_all_instances/":
            type(self).counts["instances"] += 1
            query = urllib.parse.parse_qs(parsed.query)
            if query.get("tag_codes[]") != ["can_read"]:
                self.send_json({"status": 1, "msg": "missing can_read", "data": None})
                return
            self.send_json(
                {
                    "status": 0,
                    "msg": "ok",
                    "data": [
                        {
                            "id": 80,
                            "type": "master",
                            "db_type": "mysql",
                            "instance_name": "测试生产MySQL",
                        },
                        {
                            "id": 82,
                            "type": "master",
                            "db_type": "redis",
                            "instance_name": "测试生产Redis",
                        },
                    ],
                }
            )
            return
        if parsed.path == "/instance/instance_resource/":
            type(self).counts["databases"] += 1
            query = urllib.parse.parse_qs(parsed.query)
            if query.get("instance_name") != ["测试生产MySQL"]:
                self.send_json({"status": 1, "msg": "bad instance", "data": None})
                return
            self.send_json(
                {"status": 0, "msg": "ok", "data": ["app-data", "app-cloud"]}
            )
            return
        self.send_response(404)
        self.end_headers()

    def do_POST(self):
        length = int(self.headers.get("Content-Length", "0"))
        form = urllib.parse.parse_qs(self.rfile.read(length).decode("utf-8"))
        if self.path == "/authenticate/":
            type(self).counts["authenticate"] += 1
            if form.get("username") != ["tester"] or form.get("password") != [
                "test-password"
            ]:
                self.send_json({"status": 1, "msg": "bad credentials", "data": None})
                return
            self.send_json(
                {"status": 0, "msg": "ok", "data": None},
                cookies=("sessionid=test-session; Path=/",),
            )
            return
        if not self.require_session():
            self.send_response(403)
            self.end_headers()
            return
        if self.path == "/query/":
            type(self).counts["query"] += 1
            expected = {
                "instance_name": ["测试生产MySQL"],
                "db_name": ["app-data"],
                "tb_name": ["sample_table"],
                "limit_num": ["1"],
            }
            if any(form.get(key) != value for key, value in expected.items()):
                self.send_json({"status": 1, "msg": "bad query target", "data": None})
                return
            self.send_json(
                {
                    "status": 0,
                    "msg": "ok",
                    "data": {
                        "column_list": ["id"],
                        "rows": [[1]],
                        "full_sql": form["sql_content"][0],
                    },
                }
            )
            return
        if self.path == "/instance/describetable/":
            type(self).counts["desc"] += 1
            self.send_json(
                {"status": 0, "msg": "ok", "data": [{"Field": "id", "Type": "bigint"}]}
            )
            return
        self.send_response(404)
        self.end_headers()


class SqlSafetyTests(unittest.TestCase):
    def test_allows_select_and_read_only_cte(self):
        dbs.validate_select_sql("SELECT id FROM sample WHERE note = 'delete';")
        dbs.validate_select_sql(
            "WITH recent AS (SELECT id FROM sample) SELECT id FROM recent"
        )

    def test_rejects_mutation_multiple_statements_and_locking(self):
        rejected = (
            "DELETE FROM sample",
            "WITH removed AS (DELETE FROM sample RETURNING id) SELECT id FROM removed",
            "SELECT 1; SELECT 2",
            "SELECT * FROM sample FOR UPDATE",
            "SELECT * FROM sample FOR SHARE",
            "SELECT pg_sleep(10)",
            "SELECT * INTO copied FROM sample",
            "SELECT 1 /*! UNION SELECT secret FROM credentials */",
            "SHOW TABLES",
            "USE app_data",
            "START TRANSACTION",
            "SELECT pg_advisory_lock(1)",
            "SELECT * FROM sample INTO OUTFILE '/tmp/leak'",
        )
        for sql in rejected:
            with self.subTest(sql=sql), self.assertRaises(dbs.DbsError):
                dbs.validate_select_sql(sql)

    def test_rejects_unclosed_literal(self):
        with self.assertRaises(dbs.DbsError):
            dbs.validate_select_sql("SELECT * FROM sample WHERE name = 'broken")

    def test_rejects_oversized_sql(self):
        with self.assertRaises(dbs.DbsError):
            dbs.validate_select_sql("SELECT " + ("x" * dbs.MAX_SQL_CHARS))

    def test_sanitizes_secret_like_output(self):
        payload = {
            "cookie": "sessionid=do-not-print",
            "message": "password=hunter2 token=abc123 Authorization: Bearer bearer-secret",
            "headers": "Cookie: sessionid=do-not-print; csrftoken=csrf-secret",
            "safe": "SELECT id FROM sample",
        }
        sanitized = dbs.sanitize_payload(payload)
        self.assertEqual("[REDACTED]", sanitized["cookie"])
        self.assertNotIn("hunter2", sanitized["message"])
        self.assertNotIn("bearer-secret", sanitized["message"])
        self.assertNotIn("csrf-secret", sanitized["headers"])
        self.assertEqual("SELECT id FROM sample", sanitized["safe"])


class ConfigurationTests(unittest.TestCase):
    def test_rejects_secrets_in_shared_config(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            config_path = root / "dbs-config.json"
            config_path.write_text(
                json.dumps(
                    {
                        "version": 1,
                        "default_site": "private",
                        "sites": {
                            "private": {
                                "base_url": "https://dbs.example.com",
                                "username": "tester",
                                "password": "must-not-be-here",
                            }
                        },
                        "targets": {},
                    }
                ),
                encoding="utf-8",
            )
            store = dbs.Store(root / "state", config_path)
            with self.assertRaises(dbs.DbsError) as error:
                store.load_config()
            self.assertEqual("CONFIG_INVALID", error.exception.code)

    def test_reads_password_only_from_user_secret_config(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            config_path = root / "dbs-config.json"
            config_path.write_text(
                json.dumps(
                    {
                        "version": 1,
                        "default_site": "private",
                        "sites": {
                            "private": {
                                "base_url": "https://dbs.example.com",
                                "username": "tester",
                            }
                        },
                        "targets": {},
                    }
                ),
                encoding="utf-8",
            )
            secret_path = root / ".dbs_config.json"
            secret_path.write_text(
                json.dumps(
                    {
                        "version": 1,
                        "sites": {"private": {"password": "secret-value"}},
                    }
                ),
                encoding="utf-8",
            )
            store = dbs.Store(root / "state", config_path, secret_path)
            self.assertEqual("secret-value", store.resolve_password("private"))
            self.assertIsNone(store.resolve_password("missing"))


class CliFlowTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        for key in FakeArcheryHandler.counts:
            FakeArcheryHandler.counts[key] = 0
        cls.server = ThreadingHTTPServer(("127.0.0.1", 0), FakeArcheryHandler)
        cls.thread = threading.Thread(target=cls.server.serve_forever, daemon=True)
        cls.thread.start()
        cls.base_url = f"http://127.0.0.1:{cls.server.server_port}"

    @classmethod
    def tearDownClass(cls):
        cls.server.shutdown()
        cls.server.server_close()
        cls.thread.join(timeout=5)

    def setUp(self):
        self.temp_dir = tempfile.TemporaryDirectory()
        self.home = Path(self.temp_dir.name) / "dbs-home"
        self.config_path = Path(self.temp_dir.name) / "dbs-config.json"
        self.secret_path = Path(self.temp_dir.name) / ".dbs_config.json"
        self.secret_path.write_text(
            json.dumps({"version": 1, "sites": {}}), encoding="utf-8"
        )
        self.config_path.write_text(
            json.dumps(
                {
                    "version": 1,
                    "default_site": "private-test",
                    "sites": {
                        "private-test": {
                            "base_url": self.base_url,
                            "username": "tester",
                        }
                    },
                    "targets": {},
                },
                ensure_ascii=False,
            ),
            encoding="utf-8",
        )

    def tearDown(self):
        self.temp_dir.cleanup()

    def run_cli(self, *args):
        stdout = io.StringIO()
        stderr = io.StringIO()
        argv = [
            "--home",
            str(self.home),
            "--config",
            str(self.config_path),
            "--secrets",
            str(self.secret_path),
            *args,
        ]
        with redirect_stdout(stdout), redirect_stderr(stderr):
            code = dbs.main(argv)
        output = stdout.getvalue() if code == 0 else stderr.getvalue()
        return code, json.loads(output)

    def login(self):
        return self.run_cli(
            "auth",
            "login",
            "-p",
            "test-password",
        )

    def test_auto_login_uses_user_secret_config_when_session_is_missing(self):
        self.secret_path.write_text(
            json.dumps(
                {
                    "version": 1,
                    "sites": {"private-test": {"password": "test-password"}},
                }
            ),
            encoding="utf-8",
        )
        code, payload = self.run_cli(
            "instance", "list", "--db-type", "mysql"
        )
        self.assertEqual(0, code)
        self.assertTrue(payload["ok"])
        self.assertEqual(1, payload["count"])
        self.assertEqual(1, FakeArcheryHandler.counts["authenticate"])

    def test_discovery_cache_target_query_and_desc(self):
        code, payload = self.login()
        self.assertEqual(0, code)
        self.assertTrue(payload["authenticated"])

        session_files = list((self.home / "sessions").glob("*.json"))
        self.assertEqual(1, len(session_files))
        self.assertEqual(0o600, stat.S_IMODE(session_files[0].stat().st_mode))

        initial_instance_calls = FakeArcheryHandler.counts["instances"]
        code, first = self.run_cli("instance", "list", "--db-type", "mysql")
        self.assertEqual(0, code)
        self.assertFalse(first["from_cache"])
        self.assertEqual(1, first["count"])

        code, second = self.run_cli("instance", "list", "--db-type", "mysql")
        self.assertEqual(0, code)
        self.assertTrue(second["from_cache"])
        self.assertEqual(
            initial_instance_calls + 1, FakeArcheryHandler.counts["instances"]
        )

        initial_database_calls = FakeArcheryHandler.counts["databases"]
        code, databases = self.run_cli("database", "list", "--instance-id", "80")
        self.assertEqual(0, code)
        self.assertFalse(databases["from_cache"])
        self.assertIn("app-data", databases["databases"])

        code, target = self.run_cli(
            "target",
            "add",
            "test-prod-data",
            "--instance-id",
            "80",
            "--database",
            "app-data",
            "--description",
            "测试数据服务生产库",
            "--alias",
            "测试数据中心",
        )
        self.assertEqual(0, code)
        self.assertEqual("test-prod-data", target["target"]["name"])
        self.assertEqual(["测试数据中心"], target["target"]["aliases"])
        self.assertEqual(
            initial_database_calls + 1, FakeArcheryHandler.counts["databases"]
        )

        code, search = self.run_cli("target", "list", "--search", "数据中心")
        self.assertEqual(0, code)
        self.assertEqual(
            ["test-prod-data"], [item["name"] for item in search["targets"]]
        )

        code, query = self.run_cli(
            "query",
            "--target",
            "test-prod-data",
            "--table",
            "sample_table",
            "--columns",
            "id",
            "--where",
            "id = 1",
            "--limit",
            "1",
        )
        self.assertEqual(0, code)
        self.assertEqual("测试生产MySQL", query["target"]["instance_name"])
        self.assertEqual([[1]], query["result"]["data"]["rows"])

        code, description = self.run_cli(
            "desc", "--target", "test-prod-data", "sample_table"
        )
        self.assertEqual(0, code)
        self.assertEqual("sample_table", description["table"])

    def test_rejects_redis_target_and_unknown_database(self):
        self.login()
        self.run_cli("instance", "list")
        code, error = self.run_cli(
            "target",
            "add",
            "redis-target",
            "--instance-id",
            "82",
            "--database",
            "0",
        )
        self.assertEqual(1, code)
        self.assertEqual("UNSUPPORTED_DB_TYPE", error["error"]["code"])

        code, error = self.run_cli(
            "target",
            "add",
            "missing-db",
            "--instance-id",
            "80",
            "--database",
            "does-not-exist",
        )
        self.assertEqual(1, code)
        self.assertEqual("DATABASE_NOT_FOUND", error["error"]["code"])


if __name__ == "__main__":
    unittest.main()
