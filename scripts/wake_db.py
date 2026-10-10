#!/usr/bin/env python3
"""Keep the Supabase project awake by running one tiny query against it.

Free-tier projects are paused after a week of inactivity; a daily REST read of
`certifications` (public-readable per supabase/app_access.sql) counts as
activity. Standard library only, so it runs anywhere with Python 3.

Usage:
    python3 scripts/wake_db.py                  # uses env/prod.json
    python3 scripts/wake_db.py env/dev.json     # another config

Exit code is 0 on success and 1 on failure, so cron / launchd can alert on it.
"""

import json
import ssl
import sys
import urllib.error
import urllib.request
from datetime import datetime
from pathlib import Path
from urllib.parse import urlsplit

DEFAULT_CONFIG = Path(__file__).resolve().parent.parent / "env" / "prod.json"
TIMEOUT_SECONDS = 30

try:
    # python.org builds on macOS ship without CA certs; certifi has them.
    import certifi

    SSL_CONTEXT = ssl.create_default_context(cafile=certifi.where())
except ImportError:
    SSL_CONTEXT = ssl.create_default_context()


def main() -> int:
    config_path = Path(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT_CONFIG
    try:
        config = json.loads(config_path.read_text())
        parts = urlsplit(config["SUPABASE_URL"])
        key = config["SUPABASE_ANON_KEY"]
    except (OSError, ValueError, KeyError) as e:
        return fail(f"cannot read SUPABASE_URL / SUPABASE_ANON_KEY from {config_path}: {e!r}")

    # Reduce to the origin, like AppConfig.supabaseUrl (a pasted /rest/v1/ suffix is common).
    origin = f"{parts.scheme}://{parts.netloc}"
    request = urllib.request.Request(
        f"{origin}/rest/v1/certifications?select=id&limit=1",
        headers={"apikey": key, "Authorization": f"Bearer {key}"},
    )
    try:
        with urllib.request.urlopen(request, timeout=TIMEOUT_SECONDS, context=SSL_CONTEXT) as response:
            rows = json.load(response)
    except urllib.error.HTTPError as e:
        return fail(f"HTTP {e.code} {e.reason}: {e.read().decode(errors='replace')[:300]}")
    except (urllib.error.URLError, TimeoutError, ValueError) as e:
        return fail(repr(e))

    print(f"{datetime.now().isoformat(timespec='seconds')} OK {parts.netloc} ({len(rows)} row)")
    return 0


def fail(message: str) -> int:
    print(f"{datetime.now().isoformat(timespec='seconds')} FAILED {message}", file=sys.stderr)
    return 1


if __name__ == "__main__":
    sys.exit(main())
