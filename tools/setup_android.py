"""Provision project-local Android export tools; no global PATH changes."""
import concurrent.futures
import hashlib
import json
from pathlib import Path
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parents[1]
LOCAL = ROOT / ".tools"
SDK_URL = "https://dl.google.com/android/repository/commandlinetools-win-15859902_latest.zip"
SDK_SHA = "90ae805d20434428bffcb699c290860f19bb5f66a67e6b330067e3de801fb04a"

def download(url, name, expected):
    target = LOCAL / name
    if not target.exists():
        with urllib.request.urlopen(url, timeout=60) as response, target.open("wb") as out:
            while chunk := response.read(1024 * 1024):
                out.write(chunk)
    digest = hashlib.sha256(target.read_bytes()).hexdigest()
    if digest != expected:
        raise RuntimeError(f"Checksum mismatch: {name}; delete the incomplete local archive and retry")
    return target

def main():
    LOCAL.mkdir(exist_ok=True)
    # Fixed, checksum-pinned Temurin release; avoids a moving API response.
    package = {
        "link": "https://github.com/adoptium/temurin17-binaries/releases/download/jdk-17.0.20.1%2B1/OpenJDK17U-jdk_x64_windows_hotspot_17.0.20.1_1.zip",
        "checksum": "e53a79c3c3d86865bd7e787903884331068e71321714ffd44f145785affc7cb0",
    }
    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
        sdk = pool.submit(download, SDK_URL, "android-command-tools.zip", SDK_SHA)
        jdk = pool.submit(download, package["link"], "jdk17.zip", package["checksum"])
        sdk_path, jdk_path = sdk.result(), jdk.result()
    with zipfile.ZipFile(sdk_path) as archive:
        archive.extractall(LOCAL / "android-sdk" / "cmdline-tools-staging")
    source = LOCAL / "android-sdk" / "cmdline-tools-staging" / "cmdline-tools"
    dest = LOCAL / "android-sdk" / "cmdline-tools" / "latest"
    dest.parent.mkdir(exist_ok=True)
    if not dest.exists():
        source.rename(dest)
    with zipfile.ZipFile(jdk_path) as archive:
        archive.extractall(LOCAL / "java")
    java_home = next((LOCAL / "java").glob("jdk-*"))
    print(json.dumps({"java_home": str(java_home), "sdk_root": str(LOCAL / "android-sdk")}, ensure_ascii=False))

if __name__ == "__main__":
    main()
