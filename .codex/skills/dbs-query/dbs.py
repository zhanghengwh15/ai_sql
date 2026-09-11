#!/usr/bin/env python3
"""Entry point for the DBS/Archery CLI without local bytecode files."""

import importlib
import sys

sys.dont_write_bytecode = True
main = importlib.import_module("scripts.dbs").main


if __name__ == "__main__":
    raise SystemExit(main())
