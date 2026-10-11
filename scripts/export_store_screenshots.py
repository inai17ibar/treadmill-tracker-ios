#!/usr/bin/env python3
"""Export named, unmodified screenshots from Xcode's UI test attachments."""
import argparse
import json
from pathlib import Path
import shutil
import subprocess
import tempfile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("result", type=Path)
parser.add_argument("output", type=Path)
args = parser.parse_args()
args.output.mkdir(parents=True, exist_ok=True)
with tempfile.TemporaryDirectory(prefix="treadmill-screenshots-") as temporary:
    export = Path(temporary)
    subprocess.run(["xcrun", "xcresulttool", "export", "attachments", "--path", str(args.result),
                    "--output-path", str(export)], check=True)
    count = 0
    for test in json.loads((export / "manifest.json").read_text()):
        for attachment in test["attachments"]:
            name = attachment["suggestedHumanReadableName"].split("_0_")[0]
            if not name[:2].isdigit() or attachment["isAssociatedWithFailure"]:
                continue
            source = export / attachment["exportedFileName"]
            destination = args.output / (name + ".png")
            shutil.copy2(source, destination)
            info = subprocess.check_output(["sips", "-g", "pixelWidth", "-g", "pixelHeight", "-g", "hasAlpha", str(destination)], text=True)
            if "hasAlpha: no" not in info:
                raise ValueError("App Store screenshots must be opaque: " + str(destination))
            print(info.strip())
            count += 1
    if count != 7:
        raise ValueError(f"Expected 7 screenshots, exported {count}")
