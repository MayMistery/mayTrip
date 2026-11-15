#!/usr/bin/env python3
import os
import pathlib
import sys

team = os.environ.get("IOS_TEAM_ID", "").strip()
if not team:
    sys.exit("IOS_TEAM_ID is missing")

dest = pathlib.Path(os.environ["RUNNER_TEMP"]) / "ExportOptions.plist"
dest.write_text(
    """<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key>
  <string>app-store-connect</string>
  <key>teamID</key>
  <string>%s</string>
  <key>signingStyle</key>
  <string>automatic</string>
  <key>destination</key>
  <string>export</string>
  <key>generateAppStoreInformation</key>
  <true/>
  <key>uploadSymbols</key>
  <true/>
</dict>
</plist>
"""
    % team
)
print(f"Wrote {dest}")
