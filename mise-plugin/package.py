#!/usr/bin/python3
"""Install the official Linux desktop payload through Mise."""

import hashlib
import os
from pathlib import Path
import platform
import re
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parent
BASE = "https://persistent.oaistatic.com/codex-app-prod/linux/deb"


def fetch(url, destination):
    subprocess.run(
        ["curl", "--fail", "--silent", "--show-error", "--location",
         "--retry", "2", "--proto", "=https", "--proto-redir", "=https",
         "--output", str(destination), url], check=True,
    )


def verify(path, expected):
    with path.open("rb") as stream:
        actual = hashlib.file_digest(stream, "sha256").hexdigest()
    if actual != expected:
        raise RuntimeError(f"Checksum mismatch: {path.name}")


def metadata(directory):
    arch = {"x86_64": "amd64", "aarch64": "arm64"}.get(platform.machine())
    if platform.system() != "Linux" or not arch:
        raise RuntimeError("Official desktop requires Linux x64 or ARM64")
    release = directory / "InRelease"
    packages = directory / "Packages"
    fetch(f"{BASE}/dists/stable/InRelease", release)
    subprocess.run(
        ["gpgv", "--keyring", str(ROOT / "openai-repository.gpg"), str(release)],
        check=True, stdout=sys.stderr,
    )
    name = f"main/binary-{arch}/Packages"
    section = release.read_text().split("SHA256:\n", 1)[1].split("SHA512:", 1)[0]
    expected = next(line.split()[0] for line in section.splitlines()
                    if line.split()[-1:] == [name])
    fetch(f"{BASE}/dists/stable/{name}", packages)
    verify(packages, expected)
    result = []
    for paragraph in packages.read_text().strip().split("\n\n"):
        entry = dict(line.split(": ", 1) for line in paragraph.splitlines()
                     if not line.startswith(" ") and ": " in line)
        if entry.get("Package") == "chatgpt" and entry.get("Architecture") == arch:
            result.append(entry)
    if not result:
        raise RuntimeError("Official repository contains no matching package")
    return result


def install(directory, entries):
    version = os.environ["ASDF_INSTALL_VERSION"]
    entry = next((item for item in entries if item["Version"] == version), None)
    if not entry:
        raise RuntimeError(f"Version {version} is absent from the signed repository")
    filename = entry["Filename"]
    if not re.fullmatch(r"pool/[a-zA-Z0-9_./+~-]+\.deb", filename) or ".." in filename:
        raise RuntimeError("Invalid package path")
    package = directory / "chatgpt.deb"
    fetch(f"{BASE}/{filename}", package)
    verify(package, entry["SHA256"])
    members = subprocess.check_output(["bsdtar", "-tf", str(package)], text=True).splitlines()
    payload = next(item for item in members if item.startswith("data.tar."))
    archive = directory / payload
    with archive.open("wb") as stream:
        subprocess.run(["bsdtar", "-xOf", str(package), payload], stdout=stream, check=True)
    destination = Path(os.environ["ASDF_INSTALL_PATH"])
    destination.mkdir(parents=True, exist_ok=True)
    subprocess.run(["bsdtar", "-xf", str(archive), "-C", str(destination), "./usr"], check=True)
    binary = destination / "usr/lib/chatgpt/ChatGPT"
    dependencies = subprocess.run(["ldd", str(binary)], capture_output=True, text=True, check=True)
    if "not found" in dependencies.stdout:
        raise RuntimeError(dependencies.stdout)
    (destination / "bin").mkdir(exist_ok=True)
    (destination / "bin/chatgpt").symlink_to("../usr/lib/chatgpt/codex-launcher")
    (destination / "official-package.txt").write_text(
        f"Version: {version}\nSHA256: {entry['SHA256']}\nURL: {BASE}/{filename}\n"
    )


def main():
    with tempfile.TemporaryDirectory(prefix="codex-desktop-mise-") as temporary:
        directory = Path(temporary)
        entries = metadata(directory)
        if sys.argv[1] == "list-all":
            print(" ".join(item["Version"] for item in entries))
        elif sys.argv[1] == "install":
            install(directory, entries)
        else:
            raise RuntimeError("Unknown operation")


if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, subprocess.CalledProcessError) as error:
        print(f"[error] {error}", file=sys.stderr)
        sys.exit(1)
