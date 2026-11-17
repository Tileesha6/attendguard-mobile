"""Patch the Flutter-generated Android manifest for BLE foreground scanning."""
from pathlib import Path
import re
import xml.etree.ElementTree as ET

ANDROID_NS = "http://schemas.android.com/apk/res/android"
ET.register_namespace("android", ANDROID_NS)
A = lambda k: f"{{{ANDROID_NS}}}{k}"
manifest_path = Path("android/app/src/main/AndroidManifest.xml")
tree = ET.parse(manifest_path)
root = tree.getroot()

permissions = [
    ("android.permission.INTERNET", None, None),
    ("android.permission.BLUETOOTH_SCAN", None, "neverForLocation"),
    ("android.permission.BLUETOOTH_CONNECT", None, None),
    ("android.permission.BLUETOOTH", "30", None),
    ("android.permission.BLUETOOTH_ADMIN", "30", None),
    ("android.permission.ACCESS_FINE_LOCATION", "30", None),
    ("android.permission.ACCESS_COARSE_LOCATION", "28", None),
]
existing = {e.get(A("name")) for e in root.findall("uses-permission")}
for name, max_sdk, flags in permissions:
    if name in existing:
        continue
    attrs = {A("name"): name}
    if max_sdk:
        attrs[A("maxSdkVersion")] = max_sdk
    if flags:
        attrs[A("usesPermissionFlags")] = flags
    root.insert(0, ET.Element("uses-permission", attrs))

if not any(e.get(A("name")) == "android.hardware.bluetooth_le" for e in root.findall("uses-feature")):
    root.insert(0, ET.Element("uses-feature", {A("name"): "android.hardware.bluetooth_le", A("required"): "false"}))
application = root.find("application")
if application is not None:
    application.set(A("allowBackup"), "false")

tree.write(manifest_path, encoding="utf-8", xml_declaration=True)

gradle = Path("android/app/build.gradle.kts")
if gradle.exists():
    original = gradle.read_text()
    replaced, count = re.subn(r"minSdk\s*=\s*flutter\.minSdkVersion", "minSdk = 24", original)
    if count == 0:
        replaced, count = re.subn(r"minSdk\s*=\s*\d+", "minSdk = 24", original)
    if count == 0:
        raise SystemExit("Could not find minSdk setting in Gradle Kotlin file")
    gradle.write_text(replaced)
else:
    gradle = Path("android/app/build.gradle")
    original = gradle.read_text()
    replaced, count = re.subn(r"minSdkVersion\s+flutter\.minSdkVersion", "minSdkVersion 24", original)
    if count == 0:
        replaced, count = re.subn(r"minSdkVersion\s+\d+", "minSdkVersion 24", original)
    if count == 0:
        raise SystemExit("Could not find minSdkVersion in Gradle file")
    gradle.write_text(replaced)

print("Android BLE permissions and minSdk 24 configured.")
