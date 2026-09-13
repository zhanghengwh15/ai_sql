#!/usr/bin/env python3
"""Read-only CLI for querying remote databases through DBS/Archery."""

from __future__ import annotations

import argparse
import getpass
import hashlib
import http.cookiejar
import json
import os
import re
import stat
import sys
import tempfile
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, Iterable, List, Optional, Sequence, Tuple

DEFAULT_SITE = "poit"
DEFAULT_BASE_URL = "https://dbs.poi-t.cn"
SKILL_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_CONFIG_PATH = SKILL_ROOT / "config" / "dbs-config.json"
DEFAULT_SECRET_PATH = Path.home() / ".dbs_config.json"
DEFAULT_LIMIT = 100
MAX_LIMIT = 1000
MAX_SQL_CHARS = 100_000
CONFIG_VERSION = 1
SUPPORTED_SQL_TYPES = {"mysql", "pgsql"}
IDENTIFIER_RE = re.compile(r"^[A-Za-z0-9_.]+$")
ALIAS_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$")
FORBIDDEN_SQL_TOKENS = {
    "alter",
    "analyze",
    "attach",
    "call",
    "comment",
    "copy",
    "create",
    "delete",
    "detach",
    "drop",
    "execute",
    "grant",
    "insert",
    "into",
    "load",
    "lock",
    "merge",
    "optimize",
    "prepare",
    "refresh",
    "rename",
    "replace",
    "revoke",
    "set",
    "truncate",
    "update",
    "vacuum",
    "show",
    "use",
    "start",
    "begin",
    "commit",
    "rollback",
    "grant",
    "handler",
    "call",
}
FORBIDDEN_SQL_FUNCTIONS = {
    "benchmark",
    "dblink",
    "get_lock",
    "load_file",
    "lo_export",
    "lo_import",
    "nextval",
    "pg_sleep",
    "release_lock",
    "setval",
    "sleep",
    "advisory_lock",
    "pg_advisory_lock",
    "pg_try_advisory_lock",
    "pg_advisory_xact_lock",
}


class DbsError(Exception):
    def __init__(self, code: str, message: str):
        super().__init__(message)
        self.code = code
        self.message = message


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def safe_file_key(*parts: str) -> str:
    raw = "::".join(parts)
    readable = (
        re.sub(r"[^A-Za-z0-9._-]+", "_", "-".join(parts)).strip("._-") or "default"
    )
    return f"{readable[:48]}-{hashlib.sha256(raw.encode('utf-8')).hexdigest()[:10]}"


def ensure_private_directory(path: Path) -> None:
    path.mkdir(parents=True, exist_ok=True)
    try:
        path.chmod(stat.S_IRWXU)
    except OSError:
        pass


def atomic_write_json(
    path: Path,
    value: Dict[str, Any],
    mode: int = 0o600,
    private_directory: bool = True,
) -> None:
    if private_directory:
        ensure_private_directory(path.parent)
    else:
        path.parent.mkdir(parents=True, exist_ok=True)
    fd, temp_name = tempfile.mkstemp(prefix=f".{path.name}.", dir=str(path.parent))
    try:
        os.fchmod(fd, mode)
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            json.dump(value, handle, ensure_ascii=False, indent=2, sort_keys=True)
            handle.write("\n")
        os.replace(temp_name, path)
        path.chmod(mode)
    finally:
        try:
            os.unlink(temp_name)
        except FileNotFoundError:
            pass


def load_json(path: Path, default: Dict[str, Any]) -> Dict[str, Any]:
    if not path.exists():
        return default
    try:
        with path.open("r", encoding="utf-8") as handle:
            value = json.load(handle)
    except (OSError, json.JSONDecodeError) as exc:
        raise DbsError("CONFIG_INVALID", f"无法读取配置文件 {path}: {exc}") from exc
    if not isinstance(value, dict):
        raise DbsError("CONFIG_INVALID", f"配置文件 {path} 的根节点必须是对象")
    return value


class Store:
    def __init__(
        self, home: Path, config_path: Path, secret_path: Optional[Path] = None
    ):
        self.home = home.expanduser().resolve()
        self.config_path = config_path.expanduser().resolve()
        self.secret_path = (secret_path or DEFAULT_SECRET_PATH).expanduser().resolve()
        self.sessions_dir = self.home / "sessions"
        self.cache_dir = self.home / "cache"

    def default_config(self) -> Dict[str, Any]:
        return {
            "version": CONFIG_VERSION,
            "default_site": DEFAULT_SITE,
            "sites": {
                DEFAULT_SITE: {
                    "base_url": os.environ.get("DBS_BASE_URL", DEFAULT_BASE_URL).rstrip(
                        "/"
                    ),
                    "username": "",
                }
            },
            "targets": {},
        }

    def load_config(self) -> Dict[str, Any]:
        config = load_json(self.config_path, self.default_config())
        config.setdefault("version", CONFIG_VERSION)
        config.setdefault("default_site", DEFAULT_SITE)
        config.setdefault("sites", {})
        config.setdefault("targets", {})
        if config["version"] != CONFIG_VERSION:
            raise DbsError(
                "CONFIG_INVALID",
                f"配置文件版本 {config['version']!r} 不受支持，当前版本为 {CONFIG_VERSION}",
            )
        if not isinstance(config["sites"], dict) or not isinstance(
            config["targets"], dict
        ):
            raise DbsError("CONFIG_INVALID", "sites 和 targets 必须是 JSON 对象")
        default_site = config["default_site"]
        if not isinstance(default_site, str) or default_site not in config["sites"]:
            raise DbsError(
                "CONFIG_INVALID", "default_site 必须引用 sites 中已配置的站点"
            )
        forbidden_keys = {"password", "cookie", "sessionid", "csrf_token"}
        for site, site_config in config["sites"].items():
            validate_alias(site, "站点名")
            if not isinstance(site_config, dict):
                raise DbsError("CONFIG_INVALID", f"站点 {site!r} 必须是 JSON 对象")
            found_secrets = forbidden_keys & set(site_config)
            if found_secrets:
                raise DbsError(
                    "CONFIG_INVALID",
                    f"站点 {site!r} 禁止配置敏感字段: {', '.join(sorted(found_secrets))}",
                )
            base_url = site_config.get("base_url")
            parsed_url = urllib.parse.urlparse(
                base_url if isinstance(base_url, str) else ""
            )
            if parsed_url.scheme not in {"http", "https"} or not parsed_url.netloc:
                raise DbsError(
                    "CONFIG_INVALID", f"站点 {site!r} 的 base_url 不是有效 HTTP(S) URL"
                )
            if not isinstance(site_config.get("username", ""), str):
                raise DbsError(
                    "CONFIG_INVALID", f"站点 {site!r} 的 username 必须是字符串"
                )
        for name, target in config["targets"].items():
            validate_alias(name, "Target 名称")
            if not isinstance(target, dict):
                raise DbsError("CONFIG_INVALID", f"Target {name!r} 必须是 JSON 对象")
            required = ("site", "instance_id", "instance_name", "db_type", "database")
            if not all(key in target for key in required):
                raise DbsError("CONFIG_INVALID", f"Target {name!r} 配置不完整")
            if target["site"] not in config["sites"]:
                raise DbsError(
                    "CONFIG_INVALID",
                    f"Target {name!r} 引用了未知站点 {target['site']!r}",
                )
            if not isinstance(target["instance_id"], int):
                raise DbsError(
                    "CONFIG_INVALID", f"Target {name!r} 的 instance_id 必须是整数"
                )
            for key in (
                "instance_name",
                "db_type",
                "database",
                "schema",
                "description",
            ):
                if key in target and not isinstance(target[key], str):
                    raise DbsError(
                        "CONFIG_INVALID", f"Target {name!r} 的 {key} 必须是字符串"
                    )
            aliases = target.get("aliases", [])
            if not isinstance(aliases, list) or not all(
                isinstance(alias, str) for alias in aliases
            ):
                raise DbsError(
                    "CONFIG_INVALID", f"Target {name!r} 的 aliases 必须是字符串数组"
                )
        return config

    def save_config(self, config: Dict[str, Any]) -> None:
        atomic_write_json(self.config_path, config, mode=0o644, private_directory=False)

    def load_secret_config(self) -> Dict[str, Any]:
        config = load_json(self.secret_path, {"version": CONFIG_VERSION, "sites": {}})
        version = config.get("version", CONFIG_VERSION)
        if version != CONFIG_VERSION:
            raise DbsError(
                "SECRET_CONFIG_INVALID",
                f"密码配置文件版本 {version!r} 不受支持，当前版本为 {CONFIG_VERSION}",
            )
        sites = config.get("sites", {})
        if not isinstance(sites, dict):
            raise DbsError("SECRET_CONFIG_INVALID", "密码配置文件的 sites 必须是 JSON 对象")
        for site, site_config in sites.items():
            validate_alias(site, "站点名")
            if not isinstance(site_config, dict):
                raise DbsError(
                    "SECRET_CONFIG_INVALID", f"站点 {site!r} 的密码配置必须是 JSON 对象"
                )
            password = site_config.get("password")
            if password is not None and (
                not isinstance(password, str) or not password
            ):
                raise DbsError(
                    "SECRET_CONFIG_INVALID", f"站点 {site!r} 的 password 必须是非空字符串"
                )
        return config

    def resolve_password(self, site: str) -> Optional[str]:
        config = self.load_secret_config()
        site_config = config.get("sites", {}).get(site, {})
        if not isinstance(site_config, dict):
            return None
        password = site_config.get("password")
        return password if isinstance(password, str) and password else None

    def default_site(self) -> str:
        site = self.load_config().get("default_site") or DEFAULT_SITE
        if not isinstance(site, str):
            raise DbsError("CONFIG_INVALID", "default_site 必须是字符串")
        return site

    def ensure_site(
        self,
        site: str,
        base_url: Optional[str] = None,
        username: Optional[str] = None,
    ) -> Dict[str, Any]:
        validate_alias(site, "站点名")
        config = self.load_config()
        sites = config["sites"]
        site_config = sites.get(site)
        if site_config is None:
            if not base_url:
                raise DbsError(
                    "SITE_NOT_FOUND",
                    f"站点 {site!r} 未配置，请先执行 auth login --base-url",
                )
            site_config = {
                "base_url": base_url.rstrip("/"),
                "username": username or "",
            }
            sites[site] = site_config
            self.save_config(config)
        else:
            changed = False
            if base_url and site_config.get("base_url", "").rstrip(
                "/"
            ) != base_url.rstrip("/"):
                site_config["base_url"] = base_url.rstrip("/")
                changed = True
            if username and site_config.get("username") != username:
                site_config["username"] = username
                changed = True
            if changed:
                self.save_config(config)
        return site_config

    def get_site(self, site: str) -> Dict[str, Any]:
        config = self.load_config()
        site_config = config["sites"].get(site)
        if not isinstance(site_config, dict) or not site_config.get("base_url"):
            raise DbsError("SITE_NOT_FOUND", f"站点 {site!r} 未配置")
        return site_config

    def resolve_username(self, site: str, username: Optional[str] = None) -> str:
        if username:
            return username
        site_config = self.get_site(site)
        configured = site_config.get("username") or site_config.get("active_username")
        if not configured:
            raise DbsError(
                "USERNAME_REQUIRED",
                f"站点 {site!r} 未配置 username，请编辑 {self.config_path} 或传 --username",
            )
        return str(configured)

    def session_path(self, site: str, username: str) -> Path:
        return self.sessions_dir / f"{safe_file_key(site, username)}.json"

    def cache_path(self, site: str, username: str) -> Path:
        return self.cache_dir / f"{safe_file_key(site, username)}.json"

    def save_session(self, session: Dict[str, Any]) -> None:
        atomic_write_json(
            self.session_path(session["site"], session["username"]), session
        )

    def load_session(self, site: str, username: Optional[str] = None) -> Dict[str, Any]:
        resolved_username = self.resolve_username(site, username)
        path = self.session_path(site, resolved_username)
        session = load_json(path, {})
        if not session.get("sessionid") or not session.get("csrf_token"):
            raise DbsError(
                "AUTH_REQUIRED",
                f"未找到站点 {site!r} 用户 {resolved_username!r} 的有效登录态",
            )
        return session

    def ensure_session(
        self, site: str, username: Optional[str], timeout: int
    ) -> Dict[str, Any]:
        """Load a cached Session or refresh it from the user-only password file."""
        resolved_username = self.resolve_username(site, username)
        try:
            return self.load_session(site, resolved_username)
        except DbsError as exc:
            if exc.code != "AUTH_REQUIRED":
                raise
        password = self.resolve_password(site)
        if password is None:
            raise DbsError(
                "AUTH_REQUIRED",
                f"未找到有效登录态；请执行 auth login，或在 {self.secret_path} 配置该站点 password",
            )
        site_config = self.get_site(site)
        csrf_token, sessionid = ArcheryClient.login(
            site_config["base_url"], resolved_username, password, timeout=timeout
        )
        session = {
            "version": CONFIG_VERSION,
            "site": site,
            "username": resolved_username,
            "base_url": site_config["base_url"],
            "csrf_token": csrf_token,
            "sessionid": sessionid,
            "logged_in_at": utc_now(),
        }
        self.save_session(session)
        return session

    def remove_session(
        self, site: str, username: Optional[str] = None
    ) -> Tuple[str, bool]:
        resolved_username = self.resolve_username(site, username)
        path = self.session_path(site, resolved_username)
        if not path.exists():
            return resolved_username, False
        path.unlink()
        return resolved_username, True

    def load_cache(self, site: str, username: str) -> Dict[str, Any]:
        return load_json(
            self.cache_path(site, username),
            {
                "version": CONFIG_VERSION,
                "site": site,
                "username": username,
                "instances": {},
                "databases": {},
            },
        )

    def save_cache(self, site: str, username: str, cache: Dict[str, Any]) -> None:
        atomic_write_json(self.cache_path(site, username), cache)


def validate_alias(value: str, label: str = "别名") -> None:
    if not value or not ALIAS_RE.fullmatch(value):
        raise DbsError(
            "INVALID_ALIAS",
            f"{label}只能包含字母、数字、点、下划线和连字符，长度不超过 64",
        )


def validate_identifier(value: str, label: str = "标识符") -> None:
    if not value or not IDENTIFIER_RE.fullmatch(value):
        raise DbsError("INVALID_IDENTIFIER", f"{label}只能包含字母、数字、下划线和点号")


def mask_sql_literals_and_comments(sql: str) -> str:
    result: List[str] = []
    index = 0
    state = "normal"
    while index < len(sql):
        char = sql[index]
        nxt = sql[index + 1] if index + 1 < len(sql) else ""
        if state == "normal":
            if char == "'":
                state = "single"
                result.append(" ")
            elif char == '"':
                state = "double"
                result.append(" ")
            elif char == "`":
                state = "backtick"
                result.append(" ")
            elif char == "-" and nxt == "-":
                state = "line_comment"
                result.extend((" ", " "))
                index += 1
            elif char == "/" and nxt == "*":
                state = "block_comment"
                result.extend((" ", " "))
                index += 1
            else:
                result.append(char)
        elif state == "single":
            result.append("\n" if char == "\n" else " ")
            if char == "'":
                if nxt == "'":
                    result.append(" ")
                    index += 1
                else:
                    state = "normal"
            elif char == "\\" and nxt:
                result.append(" ")
                index += 1
        elif state == "double":
            result.append("\n" if char == "\n" else " ")
            if char == '"':
                if nxt == '"':
                    result.append(" ")
                    index += 1
                else:
                    state = "normal"
        elif state == "backtick":
            result.append("\n" if char == "\n" else " ")
            if char == "`":
                if nxt == "`":
                    result.append(" ")
                    index += 1
                else:
                    state = "normal"
        elif state == "line_comment":
            result.append("\n" if char == "\n" else " ")
            if char == "\n":
                state = "normal"
        elif state == "block_comment":
            result.append("\n" if char == "\n" else " ")
            if char == "*" and nxt == "/":
                result.append(" ")
                index += 1
                state = "normal"
        index += 1
    if state in {"single", "double", "backtick", "block_comment"}:
        raise DbsError("QUERY_REJECTED", "SQL 包含未闭合的引号或注释")
    return "".join(result)


def validate_select_sql(sql: str) -> None:
    if not sql or not sql.strip():
        raise DbsError("QUERY_REJECTED", "SQL 不能为空")
    if len(sql) > MAX_SQL_CHARS:
        raise DbsError("QUERY_REJECTED", f"SQL 长度不能超过 {MAX_SQL_CHARS} 个字符")
    if re.search(r"/\s*\*!", sql):
        raise DbsError("QUERY_REJECTED", "不允许 MySQL 可执行版本注释")
    masked = mask_sql_literals_and_comments(sql)
    semicolons = [match.start() for match in re.finditer(";", masked)]
    if semicolons:
        last_content = len(masked.rstrip()) - 1
        if len(semicolons) != 1 or semicolons[0] != last_content:
            raise DbsError("QUERY_REJECTED", "只允许执行一条 SQL 语句")
    tokens = [token.lower() for token in re.findall(r"[A-Za-z_][A-Za-z0-9_]*", masked)]
    if not tokens or tokens[0] not in {"select", "with"}:
        raise DbsError("QUERY_REJECTED", "只允许执行 SELECT 或只读 CTE 查询")
    if tokens[0] == "with" and "select" not in tokens:
        raise DbsError("QUERY_REJECTED", "CTE 必须包含 SELECT")
    forbidden = sorted(set(tokens) & FORBIDDEN_SQL_TOKENS)
    if forbidden:
        raise DbsError("QUERY_REJECTED", f"SQL 包含禁止关键字: {', '.join(forbidden)}")
    forbidden_functions = sorted(set(tokens) & FORBIDDEN_SQL_FUNCTIONS)
    if forbidden_functions:
        raise DbsError(
            "QUERY_REJECTED", f"SQL 包含禁止函数: {', '.join(forbidden_functions)}"
        )
    for current, following in zip(tokens, tokens[1:]):
        if current == "for" and following in {"share", "update"}:
            raise DbsError("QUERY_REJECTED", "不允许 SELECT 锁行查询")


def build_select_sql(table: str, columns: str, where: Optional[str]) -> str:
    validate_identifier(table, "表名")
    if columns != "*":
        for column in columns.split(","):
            validate_identifier(column.strip(), "字段名")
    sql = f"SELECT {columns} FROM {table}"
    if where:
        sql += f" WHERE {where}"
    sql += ";"
    validate_select_sql(sql)
    return sql


def extract_table_name(sql: str) -> Optional[str]:
    masked = mask_sql_literals_and_comments(sql)
    match = re.search(r"\bfrom\s+([A-Za-z0-9_.]+)", masked, re.IGNORECASE)
    return match.group(1) if match else None


def is_success(response: Dict[str, Any]) -> bool:
    return response.get("status") in (0, "0", True, "success")


class ArcheryClient:
    def __init__(
        self,
        base_url: str,
        csrf_token: Optional[str] = None,
        sessionid: Optional[str] = None,
        timeout: int = 30,
    ):
        self.base_url = base_url.rstrip("/")
        self.csrf_token = csrf_token
        self.sessionid = sessionid
        self.timeout = timeout

    def headers(self, referer: str = "/sqlquery/") -> Dict[str, str]:
        headers = {
            "Accept": "application/json, text/javascript, */*; q=0.01",
            "Origin": self.base_url,
            "Referer": self.base_url + referer,
            "User-Agent": "Mozilla/5.0 dbs-query-skill/2.0",
            "X-Requested-With": "XMLHttpRequest",
        }
        if self.csrf_token:
            headers["X-CSRFToken"] = self.csrf_token
        cookie_parts = []
        if self.csrf_token:
            cookie_parts.append(f"csrftoken={self.csrf_token}")
        if self.sessionid:
            cookie_parts.append(f"sessionid={self.sessionid}")
        if cookie_parts:
            headers["Cookie"] = "; ".join(cookie_parts)
        return headers

    def request_json(
        self,
        path: str,
        query: Optional[Sequence[Tuple[str, str]]] = None,
        form: Optional[Dict[str, str]] = None,
    ) -> Tuple[Dict[str, Any], str]:
        url = self.base_url + path
        if query:
            url += "?" + urllib.parse.urlencode(query)
        data = None
        headers = self.headers()
        method = "GET"
        if form is not None:
            data = urllib.parse.urlencode(form).encode("utf-8")
            headers["Content-Type"] = "application/x-www-form-urlencoded; charset=UTF-8"
            method = "POST"
        request = urllib.request.Request(url, data=data, headers=headers, method=method)
        try:
            with urllib.request.urlopen(request, timeout=self.timeout) as response:
                text = response.read().decode("utf-8", errors="replace")
        except urllib.error.HTTPError as exc:
            body = exc.read().decode("utf-8", errors="replace")
            if exc.code in (401, 403):
                raise DbsError(
                    "AUTH_REQUIRED", "DBS 登录态已失效或无权访问该资源"
                ) from exc
            message = ""
            try:
                error_payload = json.loads(body)
                if isinstance(error_payload, dict):
                    message = str(error_payload.get("msg") or "")
            except json.JSONDecodeError:
                pass
            detail = f": {message}" if message else ""
            raise DbsError(
                "HTTP_ERROR", f"DBS 请求失败，HTTP {exc.code}{detail}"
            ) from exc
        except urllib.error.URLError as exc:
            raise DbsError("NETWORK_ERROR", f"无法访问 DBS: {exc.reason}") from exc
        stripped = text.lstrip().lower()
        if stripped.startswith("<!doctype html") or stripped.startswith("<html"):
            raise DbsError("AUTH_REQUIRED", "DBS 返回登录页面，登录态可能已失效")
        try:
            response_json = json.loads(text)
        except json.JSONDecodeError as exc:
            raise DbsError(
                "INVALID_RESPONSE", f"DBS 返回了非 JSON 响应: {text[:300]}"
            ) from exc
        if not isinstance(response_json, dict):
            raise DbsError("INVALID_RESPONSE", "DBS JSON 响应根节点不是对象")
        if not is_success(response_json):
            message = str(response_json.get("msg") or "DBS 请求失败")
            raise DbsError("ARCHERY_ERROR", message)
        return response_json, text

    @classmethod
    def login(
        cls,
        base_url: str,
        username: str,
        password: str,
        timeout: int = 30,
    ) -> Tuple[str, str]:
        base_url = base_url.rstrip("/")
        jar = http.cookiejar.CookieJar()
        opener = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(jar))
        login_request = urllib.request.Request(
            base_url + "/login/",
            headers={
                "Accept": "text/html,application/xhtml+xml",
                "Referer": base_url + "/login/",
                "User-Agent": "Mozilla/5.0 dbs-query-skill/2.0",
            },
            method="GET",
        )
        try:
            with opener.open(login_request, timeout=timeout):
                pass
        except (urllib.error.HTTPError, urllib.error.URLError) as exc:
            raise DbsError("LOGIN_FAILED", f"无法打开 DBS 登录页: {exc}") from exc
        csrf_token = cookie_value(jar, "csrftoken")
        if not csrf_token:
            raise DbsError("LOGIN_FAILED", "无法从 DBS 登录页获取 CSRF Token")
        body = urllib.parse.urlencode(
            {"username": username, "password": password}
        ).encode("utf-8")
        auth_request = urllib.request.Request(
            base_url + "/authenticate/",
            data=body,
            headers={
                "Accept": "application/json, text/javascript, */*; q=0.01",
                "Content-Type": "application/x-www-form-urlencoded; charset=UTF-8",
                "Origin": base_url,
                "Referer": base_url + "/login/",
                "User-Agent": "Mozilla/5.0 dbs-query-skill/2.0",
                "X-CSRFToken": csrf_token,
                "X-Requested-With": "XMLHttpRequest",
            },
            method="POST",
        )
        try:
            with opener.open(auth_request, timeout=timeout) as response:
                text = response.read().decode("utf-8", errors="replace")
        except (urllib.error.HTTPError, urllib.error.URLError) as exc:
            raise DbsError("LOGIN_FAILED", f"DBS 登录请求失败: {exc}") from exc
        try:
            response_json = json.loads(text)
        except json.JSONDecodeError as exc:
            raise DbsError("LOGIN_FAILED", "DBS 登录接口返回了非 JSON 响应") from exc
        if not isinstance(response_json, dict) or not is_success(response_json):
            message = (
                response_json.get("msg") if isinstance(response_json, dict) else None
            )
            raise DbsError("LOGIN_FAILED", str(message or "用户名或密码错误"))
        csrf_token = cookie_value(jar, "csrftoken") or csrf_token
        sessionid = cookie_value(jar, "sessionid")
        if not sessionid and response_json.get("data"):
            sessionid = str(response_json["data"])
        if not sessionid:
            raise DbsError("LOGIN_FAILED", "登录响应中没有 Session ID")
        return csrf_token, sessionid


def cookie_value(jar: http.cookiejar.CookieJar, name: str) -> Optional[str]:
    for cookie in jar:
        if cookie.name == name:
            return cookie.value
    return None


def client_for(
    store: Store, site: str, username: Optional[str], timeout: int
) -> Tuple[ArcheryClient, str]:
    site_config = store.get_site(site)
    session = store.ensure_session(site, username, timeout)
    return (
        ArcheryClient(
            site_config["base_url"],
            csrf_token=session["csrf_token"],
            sessionid=session["sessionid"],
            timeout=timeout,
        ),
        str(session["username"]),
    )


def normalize_instances(data: Any) -> List[Dict[str, Any]]:
    if not isinstance(data, list):
        raise DbsError("INVALID_RESPONSE", "实例接口 data 字段不是数组")
    result = []
    for item in data:
        if not isinstance(item, dict):
            continue
        if not all(key in item for key in ("id", "instance_name", "db_type")):
            continue
        result.append(
            {
                "id": int(item["id"]),
                "type": str(item.get("type") or ""),
                "db_type": str(item["db_type"]).lower(),
                "instance_name": str(item["instance_name"]),
            }
        )
    return sorted(result, key=lambda item: (item["instance_name"], item["id"]))


def get_instances(
    store: Store,
    client: ArcheryClient,
    site: str,
    username: str,
    refresh: bool = False,
) -> Tuple[List[Dict[str, Any]], bool]:
    cache = store.load_cache(site, username)
    cached = cache.get("instances")
    if (
        not refresh
        and isinstance(cached, dict)
        and isinstance(cached.get("items"), list)
    ):
        return cached["items"], True
    response, _ = client.request_json(
        "/group/user_all_instances/",
        query=(("tag_codes[]", "can_read"),),
    )
    instances = normalize_instances(response.get("data"))
    cache["instances"] = {"fetched_at": utc_now(), "items": instances}
    valid_ids = {str(item["id"]) for item in instances}
    cache["databases"] = {
        key: value
        for key, value in cache.get("databases", {}).items()
        if key in valid_ids
    }
    store.save_cache(site, username, cache)
    return instances, False


def resolve_instance(
    instances: Iterable[Dict[str, Any]],
    instance_id: Optional[int] = None,
    instance_name: Optional[str] = None,
) -> Dict[str, Any]:
    matches = []
    for item in instances:
        if instance_id is not None and int(item["id"]) != instance_id:
            continue
        if instance_name is not None and item["instance_name"] != instance_name:
            continue
        matches.append(item)
    if not matches:
        identifier = instance_id if instance_id is not None else instance_name
        raise DbsError(
            "INSTANCE_NOT_FOUND", f"当前用户的可读实例中不存在 {identifier!r}"
        )
    if len(matches) > 1:
        raise DbsError("INSTANCE_AMBIGUOUS", "实例匹配结果不唯一，请使用 instance-id")
    return matches[0]


def get_databases(
    store: Store,
    client: ArcheryClient,
    site: str,
    username: str,
    instance: Dict[str, Any],
    refresh: bool = False,
) -> Tuple[List[str], bool]:
    cache = store.load_cache(site, username)
    key = str(instance["id"])
    cached = cache.get("databases", {}).get(key)
    if (
        not refresh
        and isinstance(cached, dict)
        and cached.get("instance_name") == instance["instance_name"]
        and isinstance(cached.get("items"), list)
    ):
        return cached["items"], True
    response, _ = client.request_json(
        "/instance/instance_resource/",
        query=(
            ("instance_name", instance["instance_name"]),
            ("resource_type", "database"),
        ),
    )
    data = response.get("data")
    if not isinstance(data, list) or not all(isinstance(item, str) for item in data):
        raise DbsError("INVALID_RESPONSE", "数据库资源接口 data 字段不是字符串数组")
    databases = sorted(set(data))
    cache.setdefault("databases", {})[key] = {
        "instance_name": instance["instance_name"],
        "fetched_at": utc_now(),
        "items": databases,
    }
    store.save_cache(site, username, cache)
    return databases, False


def get_target(store: Store, name: str) -> Dict[str, Any]:
    config = store.load_config()
    target = config.get("targets", {}).get(name)
    if not isinstance(target, dict):
        raise DbsError("TARGET_NOT_FOUND", f"查询目标 {name!r} 不存在")
    required = ("site", "instance_id", "instance_name", "db_type", "database")
    if not all(key in target for key in required):
        raise DbsError("CONFIG_INVALID", f"查询目标 {name!r} 配置不完整")
    return {"name": name, **target}


def public_target(target: Dict[str, Any]) -> Dict[str, Any]:
    result = {
        "name": target["name"],
        "site": target["site"],
        "instance_id": target["instance_id"],
        "instance_name": target["instance_name"],
        "db_type": target["db_type"],
        "database": target["database"],
        "schema": target.get("schema", ""),
    }
    if target.get("description"):
        result["description"] = target["description"]
    if target.get("aliases"):
        result["aliases"] = target["aliases"]
    return result


def require_sql_target(target: Dict[str, Any]) -> None:
    if target["db_type"] not in SUPPORTED_SQL_TYPES:
        raise DbsError(
            "UNSUPPORTED_DB_TYPE",
            f"目标 {target['name']!r} 的类型为 {target['db_type']!r}，当前只支持 MySQL 和 PostgreSQL",
        )


def validate_limit(limit: int) -> None:
    if limit <= 0 or limit > MAX_LIMIT:
        raise DbsError("INVALID_LIMIT", f"limit 必须在 1 到 {MAX_LIMIT} 之间")


def emit(payload: Dict[str, Any], compact: bool = False, stream: Any = None) -> None:
    if stream is None:
        stream = sys.stdout
    payload = sanitize_payload(payload)
    if compact:
        print(
            json.dumps(payload, ensure_ascii=False, separators=(",", ":")), file=stream
        )
    else:
        print(json.dumps(payload, ensure_ascii=False, indent=2), file=stream)


_SECRET_KEY_RE = re.compile(r"(?:password|passwd|cookie|session(?:id)?|csrf(?:_token)?|token|authorization|secret)", re.I)
_SECRET_VALUE_RE = re.compile(
    r"(?i)(\b(?:password|passwd|session(?:id)?|csrf(?:_token)?|token)\s*[:=]\s*)([^,;\s}]+)"
    r"|(\bauthorization\s*:\s*bearer\s+)([^,;\s}]+)"
    r"|(\bcookie\s*:\s*)([^\r\n]+)"
)


def sanitize_text(value: str) -> str:
    """Redact credential-like key/value material before CLI output."""
    def replace(match: re.Match[str]) -> str:
        prefix = next((group for group in match.groups()[::2] if group), "")
        return f"{prefix}[REDACTED]"

    return _SECRET_VALUE_RE.sub(replace, value)


def sanitize_payload(value: Any) -> Any:
    if isinstance(value, dict):
        result = {}
        for key, child in value.items():
            if _SECRET_KEY_RE.search(str(key)):
                result[key] = "[REDACTED]"
            else:
                result[key] = sanitize_payload(child)
        return result
    if isinstance(value, list):
        return [sanitize_payload(item) for item in value]
    if isinstance(value, str):
        return sanitize_text(value)
    return value


def command_auth_login(args: argparse.Namespace, store: Store) -> Dict[str, Any]:
    site_config = store.ensure_site(args.site, args.base_url, args.username)
    username = args.username or site_config.get("username")
    if not username:
        raise DbsError(
            "USERNAME_REQUIRED",
            f"站点 {args.site!r} 未配置 username，请编辑 {store.config_path} 或传 -u",
        )
    password = (
        args.password
        or os.environ.get("DBS_PASSWORD")
        or store.resolve_password(args.site)
    )
    if password is None:
        password = getpass.getpass("Password: ")
    csrf_token, sessionid = ArcheryClient.login(
        site_config["base_url"], username, password, timeout=args.timeout
    )
    store.save_session(
        {
            "version": CONFIG_VERSION,
            "site": args.site,
            "username": username,
            "base_url": site_config["base_url"],
            "csrf_token": csrf_token,
            "sessionid": sessionid,
            "logged_in_at": utc_now(),
        }
    )
    return {
        "ok": True,
        "site": args.site,
        "username": username,
        "authenticated": True,
    }


def command_auth_status(args: argparse.Namespace, store: Store) -> Dict[str, Any]:
    username = store.resolve_username(args.site, args.username)
    session = store.load_session(args.site, username)
    return {
        "ok": True,
        "site": args.site,
        "username": username,
        "authenticated": True,
        "logged_in_at": session.get("logged_in_at"),
    }


def command_auth_logout(args: argparse.Namespace, store: Store) -> Dict[str, Any]:
    username, removed = store.remove_session(args.site, args.username)
    return {
        "ok": True,
        "site": args.site,
        "username": username,
        "session_removed": removed,
    }


def command_instance_list(args: argparse.Namespace, store: Store) -> Dict[str, Any]:
    client, username = client_for(store, args.site, args.username, args.timeout)
    instances, from_cache = get_instances(
        store, client, args.site, username, args.refresh
    )
    if args.db_type:
        instances = [item for item in instances if item["db_type"] == args.db_type]
    return {
        "ok": True,
        "site": args.site,
        "username": username,
        "from_cache": from_cache,
        "count": len(instances),
        "instances": instances,
    }


def resolve_command_instance(
    args: argparse.Namespace,
    store: Store,
) -> Tuple[ArcheryClient, str, Dict[str, Any]]:
    client, username = client_for(store, args.site, args.username, args.timeout)
    instances, _ = get_instances(
        store, client, args.site, username, args.refresh_instances
    )
    instance = resolve_instance(instances, args.instance_id, args.instance_name)
    return client, username, instance


def command_database_list(args: argparse.Namespace, store: Store) -> Dict[str, Any]:
    client, username, instance = resolve_command_instance(args, store)
    databases, from_cache = get_databases(
        store, client, args.site, username, instance, args.refresh
    )
    return {
        "ok": True,
        "site": args.site,
        "username": username,
        "instance": instance,
        "from_cache": from_cache,
        "count": len(databases),
        "databases": databases,
    }


def command_target_add(args: argparse.Namespace, store: Store) -> Dict[str, Any]:
    validate_alias(args.name)
    client, username, instance = resolve_command_instance(args, store)
    if instance["db_type"] not in SUPPORTED_SQL_TYPES:
        raise DbsError(
            "UNSUPPORTED_DB_TYPE",
            f"实例类型 {instance['db_type']!r} 暂不支持 SQL Target",
        )
    databases, _ = get_databases(
        store, client, args.site, username, instance, args.refresh_databases
    )
    if args.database not in databases:
        raise DbsError(
            "DATABASE_NOT_FOUND",
            f"实例 {instance['instance_name']!r} 的可读数据库中不存在 {args.database!r}",
        )
    config = store.load_config()
    targets = config.setdefault("targets", {})
    if args.name in targets and not args.replace:
        raise DbsError(
            "TARGET_EXISTS", f"查询目标 {args.name!r} 已存在；使用 --replace 明确覆盖"
        )
    target = {
        "site": args.site,
        "instance_id": instance["id"],
        "instance_name": instance["instance_name"],
        "db_type": instance["db_type"],
        "database": args.database,
        "schema": args.schema or "",
        "description": args.description or "",
        "aliases": args.alias or [],
    }
    targets[args.name] = target
    store.save_config(config)
    return {"ok": True, "target": public_target({"name": args.name, **target})}


def command_target_list(args: argparse.Namespace, store: Store) -> Dict[str, Any]:
    targets = store.load_config().get("targets", {})
    items = []
    for name in sorted(targets):
        target = targets[name]
        if isinstance(target, dict):
            item = public_target({"name": name, **target})
            if args.search:
                searchable = " ".join(
                    str(value)
                    for value in (
                        item.get("name", ""),
                        item.get("description", ""),
                        item.get("site", ""),
                        item.get("instance_name", ""),
                        item.get("database", ""),
                        *(item.get("aliases") or []),
                    )
                ).lower()
                if args.search.lower() not in searchable:
                    continue
            items.append(item)
    return {"ok": True, "count": len(items), "targets": items}


def command_target_show(args: argparse.Namespace, store: Store) -> Dict[str, Any]:
    return {"ok": True, "target": public_target(get_target(store, args.name))}


def command_target_remove(args: argparse.Namespace, store: Store) -> Dict[str, Any]:
    config = store.load_config()
    targets = config.get("targets", {})
    if args.name not in targets:
        raise DbsError("TARGET_NOT_FOUND", f"查询目标 {args.name!r} 不存在")
    del targets[args.name]
    store.save_config(config)
    return {"ok": True, "target": args.name, "removed": True}


def target_client(
    args: argparse.Namespace, store: Store
) -> Tuple[ArcheryClient, Dict[str, Any], str]:
    target = get_target(store, args.target)
    require_sql_target(target)
    client, username = client_for(store, target["site"], args.username, args.timeout)
    return client, target, username


def command_query(args: argparse.Namespace, store: Store) -> Dict[str, Any]:
    validate_limit(args.limit)
    client, target, username = target_client(args, store)
    if args.sql:
        sql = args.sql.strip()
        validate_select_sql(sql)
        table = args.table or extract_table_name(sql)
        if not table:
            raise DbsError("TABLE_REQUIRED", "无法从 SQL 识别表名，请补充 --table")
    else:
        if not args.table:
            raise DbsError("TABLE_REQUIRED", "未传 --sql 时必须提供 --table")
        sql = build_select_sql(args.table, args.columns, args.where)
        table = args.table
    validate_identifier(table, "表名")
    response, raw = client.request_json(
        "/query/",
        form={
            "instance_name": target["instance_name"],
            "db_name": target["database"],
            "schema_name": target.get("schema", ""),
            "tb_name": table,
            "sql_content": sql,
            "limit_num": str(args.limit),
        },
    )
    if args.raw:
        return {"__raw__": raw}
    return {
        "ok": True,
        "target": public_target(target),
        "username": username,
        "sql": sql,
        "limit": args.limit,
        "result": response,
    }


def command_desc(args: argparse.Namespace, store: Store) -> Dict[str, Any]:
    validate_identifier(args.table, "表名")
    client, target, username = target_client(args, store)
    response, raw = client.request_json(
        "/instance/describetable/",
        form={
            "instance_name": target["instance_name"],
            "db_name": target["database"],
            "schema_name": target.get("schema", ""),
            "tb_name": args.table,
        },
    )
    if args.raw:
        return {"__raw__": raw}
    return {
        "ok": True,
        "target": public_target(target),
        "username": username,
        "table": args.table,
        "result": response,
    }


def add_identity_arguments(parser: argparse.ArgumentParser) -> None:
    parser.add_argument(
        "--site", help="Archery 站点别名，默认读取配置文件 default_site"
    )
    parser.add_argument(
        "--username", help="使用指定用户的本地 Session；默认读取站点配置 username"
    )


def add_instance_selector(parser: argparse.ArgumentParser) -> None:
    selector = parser.add_mutually_exclusive_group(required=True)
    selector.add_argument("--instance-id", type=int, help="实例 ID，推荐使用")
    selector.add_argument("--instance-name", help="完整实例名")
    parser.add_argument(
        "--refresh-instances", action="store_true", help="选择前刷新实例缓存"
    )


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="通过 DBS/Archery 执行远程只读数据库查询"
    )
    parser.add_argument(
        "--home",
        type=Path,
        default=Path(os.environ.get("DBS_HOME", "~/.dbs-cli")),
        help="Session 和缓存目录，默认 ~/.dbs-cli",
    )
    parser.add_argument(
        "--config",
        type=Path,
        default=Path(os.environ.get("DBS_CONFIG_FILE", str(DEFAULT_CONFIG_PATH))),
        help="站点和 Target JSON 配置文件",
    )
    parser.add_argument(
        "--secrets",
        type=Path,
        default=Path(os.environ.get("DBS_SECRET_FILE", str(DEFAULT_SECRET_PATH))),
        help="用户目录密码 JSON 文件，默认 ~/.dbs_config.json",
    )
    parser.add_argument(
        "--timeout", type=int, default=30, help="HTTP 超时秒数，默认 30"
    )
    parser.add_argument("--compact", action="store_true", help="输出单行 JSON")
    subparsers = parser.add_subparsers(dest="command", required=True)

    auth = subparsers.add_parser("auth", help="管理 DBS 登录态")
    auth_subparsers = auth.add_subparsers(dest="auth_command", required=True)
    login = auth_subparsers.add_parser("login", help="登录并保存 Session")
    login.add_argument("--site")
    login.add_argument("--base-url", help="临时覆盖或新增站点的 DBS URL")
    login.add_argument("-u", "--username", help="覆盖配置文件中的默认用户名")
    login.add_argument("-p", "--password", help=argparse.SUPPRESS)
    login.set_defaults(handler=command_auth_login)
    status_parser = auth_subparsers.add_parser("status", help="查看本地 Session 状态")
    add_identity_arguments(status_parser)
    status_parser.set_defaults(handler=command_auth_status)
    logout = auth_subparsers.add_parser("logout", help="删除本地 Session")
    add_identity_arguments(logout)
    logout.set_defaults(handler=command_auth_logout)

    instance = subparsers.add_parser("instance", help="发现有只读权限的实例")
    instance_subparsers = instance.add_subparsers(
        dest="instance_command", required=True
    )
    instance_list = instance_subparsers.add_parser(
        "list", help="列出实例，首次请求后使用缓存"
    )
    add_identity_arguments(instance_list)
    instance_list.add_argument("--db-type", choices=("mysql", "pgsql", "redis"))
    instance_list.add_argument("--refresh", action="store_true")
    instance_list.set_defaults(handler=command_instance_list)

    database = subparsers.add_parser("database", help="发现实例中的数据库")
    database_subparsers = database.add_subparsers(
        dest="database_command", required=True
    )
    database_list = database_subparsers.add_parser(
        "list", help="列出数据库，首次请求后使用缓存"
    )
    add_identity_arguments(database_list)
    add_instance_selector(database_list)
    database_list.add_argument(
        "--refresh", action="store_true", help="刷新该实例的数据库缓存"
    )
    database_list.set_defaults(handler=command_database_list)

    target = subparsers.add_parser("target", help="管理可复用查询目标")
    target_subparsers = target.add_subparsers(dest="target_command", required=True)
    target_add = target_subparsers.add_parser("add", help="从已授权资源创建查询目标")
    target_add.add_argument("name")
    add_identity_arguments(target_add)
    add_instance_selector(target_add)
    target_add.add_argument("--database", required=True)
    target_add.add_argument("--schema", default="")
    target_add.add_argument("--description", help="目标用途说明")
    target_add.add_argument("--alias", action="append", help="自然语言别名，可重复传递")
    target_add.add_argument("--refresh-databases", action="store_true")
    target_add.add_argument("--replace", action="store_true", help="明确覆盖同名目标")
    target_add.set_defaults(handler=command_target_add)
    target_list = target_subparsers.add_parser("list", help="列出查询目标")
    target_list.add_argument("--search", help="按名称、别名、实例或数据库搜索")
    target_list.set_defaults(handler=command_target_list)
    target_show = target_subparsers.add_parser("show", help="查看查询目标")
    target_show.add_argument("name")
    target_show.set_defaults(handler=command_target_show)
    target_remove = target_subparsers.add_parser("remove", help="删除查询目标")
    target_remove.add_argument("name")
    target_remove.set_defaults(handler=command_target_remove)

    query = subparsers.add_parser("query", help="执行只读 SELECT")
    query.add_argument("--target", required=True)
    query.add_argument("--username")
    query.add_argument("--sql")
    query.add_argument("--table")
    query.add_argument("--columns", default="*")
    query.add_argument("--where")
    query.add_argument("--limit", type=int, default=DEFAULT_LIMIT)
    query.add_argument("--raw", action="store_true")
    query.set_defaults(handler=command_query)

    desc = subparsers.add_parser("desc", help="查看远程表结构")
    desc.add_argument("--target", required=True)
    desc.add_argument("--username")
    desc.add_argument("table")
    desc.add_argument("--raw", action="store_true")
    desc.set_defaults(handler=command_desc)
    return parser


def main(argv: Optional[Sequence[str]] = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    if args.timeout <= 0:
        emit(
            {
                "ok": False,
                "error": {"code": "INVALID_TIMEOUT", "message": "timeout 必须大于 0"},
            },
            compact=args.compact,
            stream=sys.stderr,
        )
        return 2
    try:
        store = Store(args.home, args.config, args.secrets)
        if hasattr(args, "site") and args.site is None:
            args.site = store.default_site()
        payload = args.handler(args, store)
        if "__raw__" in payload:
            print(sanitize_text(str(payload["__raw__"])))
        else:
            emit(payload, compact=args.compact)
        return 0
    except DbsError as exc:
        emit(
            {"ok": False, "error": {"code": exc.code, "message": exc.message}},
            compact=args.compact,
            stream=sys.stderr,
        )
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
