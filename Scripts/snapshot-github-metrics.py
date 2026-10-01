#!/usr/bin/env python3
"""Save a read-only GitHub snapshot locally. Requires an authenticated gh CLI."""
import datetime
import json
from pathlib import Path
import subprocess

repo = "Ayang0097/codex-quota-grove"

def api(path, paginated=False):
    command = ["gh", "api"]
    if paginated:
        command += ["--paginate", "--slurp"]
    command += [path]
    return json.loads(subprocess.check_output(command, text=True))

metadata = api(f"repos/{repo}")
releases = [release for page in api(f"repos/{repo}/releases?per_page=100", True) for release in page if not release["draft"]]
assets = [{"tag": release["tag_name"], "name": asset["name"], "downloads": asset["download_count"]} for release in releases for asset in release["assets"]]
now = datetime.datetime.now(datetime.timezone.utc)
result = {
    "captured_at": now.isoformat(), "repository": repo,
    "stars": metadata["stargazers_count"], "forks": metadata["forks_count"],
    "software_package_downloads": sum(a["downloads"] for a in assets if a["name"].endswith(("-macos-arm64.zip", "-windows-x64.zip"))),
    "release_assets": assets,
    "notes": "Downloads are requests, not unique installs; validation downloads count. Traffic uses a rolling 14-day window.",
}
for endpoint in ["views", "clones", "popular/referrers"]:
    try:
        result[endpoint] = api(f"repos/{repo}/traffic/{endpoint}")
    except subprocess.CalledProcessError:
        result[endpoint] = {"unavailable": True}
out = Path(__file__).resolve().parents[1] / "dist/metrics"
out.mkdir(parents=True, exist_ok=True)
path = out / f"{now.strftime('%Y%m%dT%H%M%SZ')}.json"
path.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n")
print(path)
