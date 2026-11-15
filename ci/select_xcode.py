#!/usr/bin/env python3
"""Select the newest Xcode that ships the iOS 27.1 SDK or later.

iPhone Duo letterboxes apps built with the iOS 26 SDK or earlier. Builds with
the iOS 27 SDK resize, and full adaptation needs the iOS 27.1 SDK. GitHub's
xcode-27 image currently installs Xcode 27.1 (default, iOS 27.1) and 27.2
(iOS 27.2). Xcode 27.0 only has the iOS 27.0 SDK, so it is not eligible.
"""

import pathlib
import plistlib
import subprocess
import sys

MINIMUM = (27, 1, 0)


def parse_version(value: str) -> tuple[int, int, int]:
    parts: list[int] = []
    for piece in value.split("."):
        digits = "".join(character for character in piece if character.isdigit())
        if digits:
            parts.append(int(digits))
    while len(parts) < 3:
        parts.append(0)
    return (parts[0], parts[1], parts[2])


def rank(path: pathlib.Path, version: str) -> tuple:
    name = path.name.lower()
    preview = 1 if ("beta" in name or "rc" in name or "release_candidate" in name) else 0
    return (parse_version(version), -preview, str(path))


def main() -> None:
    found: dict[pathlib.Path, str] = {}
    applications = pathlib.Path("/Applications")
    print("Installed Xcode apps:")
    for path in sorted(applications.glob("Xcode*.app")):
        resolved = path.resolve()
        info_path = resolved / "Contents" / "Info.plist"
        if not info_path.is_file():
            print(f"  (no Info.plist) {path}")
            continue
        with info_path.open("rb") as handle:
            version = str(plistlib.load(handle).get("CFBundleShortVersionString", ""))
        print(f"  {version or '?':<12} {path}")
        if version:
            found[resolved] = version

    eligible = [(path, version) for path, version in found.items() if parse_version(version) >= MINIMUM]
    if not eligible:
        sys.exit(
            "No Xcode 27.1 or later found. iPhone Duo needs an iOS 27.1 SDK or newer. "
            "Use the GitHub-hosted xcode-27 runner."
        )

    chosen, version = max(eligible, key=lambda item: rank(item[0], item[1]))
    print(f"Using {chosen} ({version})")
    subprocess.check_call(["sudo", "xcode-select", "-s", str(chosen)])
    subprocess.check_call(["xcodebuild", "-version"])

    show = subprocess.check_output(["xcodebuild", "-showsdks"], text=True)
    ios_sdks: list[str] = []
    for line in show.splitlines():
        if "iphoneos" not in line:
            continue
        token = line.split()[-1]
        if token.startswith("iphoneos"):
            ios_sdks.append(token.removeprefix("iphoneos"))
    print("iOS SDKs:", ", ".join(ios_sdks) or "(none)")
    if not any(parse_version(sdk) >= MINIMUM for sdk in ios_sdks):
        sys.exit(f"{chosen} does not include the iOS 27.1 SDK or later.")


if __name__ == "__main__":
    main()
