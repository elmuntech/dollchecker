#!/usr/bin/env python3
"""Applies DollChecker's platform configuration to a freshly generated project.

`android/` and `ios/` are not committed — `flutter create` regenerates them —
so everything the app needs from them would otherwise be a manual checklist
that silently rots. This script is that checklist, executable: CI runs it
before building, and so should anyone setting up a release project.

Nothing here is a preference. Each edit is something the app stops working
without:

  * `POST_NOTIFICATIONS`      — daily reminders on Android 13+
  * `<queries>` for https     — opening the privacy policy on Android 11+
  * `dollchecker://` scheme   — password-reset and checkout return links
  * core library desugaring   — required by flutter_local_notifications
  * camera / photo usage text — iOS crashes on first scan without them
  * application id + display name — `flutter create` leaves `com.example.…`,
    which the stores reject, and which cannot be changed after the first upload

Release builds additionally need a signing config, which is opt-in
(`--release-signing`) so that a debug build without a keystore is unaffected.

Usage:  python3 tool/configure_platform.py app [--app-id com.dollchecker.app]
                                               [--release-signing]
"""

from __future__ import annotations

import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

ANDROID_NS = "http://schemas.android.com/apk/res/android"
DEEP_LINK_SCHEME = "dollchecker"
DESUGAR_VERSION = "2.1.4"

# The store identity. Both stores treat this as permanent: it cannot be changed
# after the first upload, on either platform. Decide before publishing.
DEFAULT_APP_ID = "com.dollchecker.app"
DISPLAY_NAME = "DollChecker"

ET.register_namespace("android", ANDROID_NS)


def _android(attr: str) -> str:
    return f"{{{ANDROID_NS}}}{attr}"


def patch_manifest(path: Path) -> list[str]:
    """Adds the permission, the https query and the deep-link intent filter."""
    tree = ET.parse(path)
    manifest = tree.getroot()
    changes: list[str] = []

    permissions = {
        el.get(_android("name")) for el in manifest.findall("uses-permission")
    }
    if "android.permission.POST_NOTIFICATIONS" not in permissions:
        el = ET.Element("uses-permission")
        el.set(_android("name"), "android.permission.POST_NOTIFICATIONS")
        manifest.insert(0, el)
        changes.append("POST_NOTIFICATIONS")

    # Android 11+ hides other apps unless the manifest declares what it needs
    # to reach; without this, opening a link silently does nothing.
    if manifest.find("queries") is None:
        queries = ET.Element("queries")
        intent = ET.SubElement(queries, "intent")
        action = ET.SubElement(intent, "action")
        action.set(_android("name"), "android.intent.action.VIEW")
        data = ET.SubElement(intent, "data")
        data.set(_android("scheme"), "https")
        manifest.append(queries)
        changes.append("<queries> for https")

    application = manifest.find("application")
    if application is not None and application.get(_android("label")) != DISPLAY_NAME:
        application.set(_android("label"), DISPLAY_NAME)
        changes.append(f'label "{DISPLAY_NAME}"')

    activity = manifest.find("./application/activity")
    if activity is None:
        raise SystemExit(f"no <activity> in {path}")

    has_deep_link = any(
        data.get(_android("scheme")) == DEEP_LINK_SCHEME
        for data in activity.findall("./intent-filter/data")
    )
    if not has_deep_link:
        intent_filter = ET.SubElement(activity, "intent-filter")
        action = ET.SubElement(intent_filter, "action")
        action.set(_android("name"), "android.intent.action.VIEW")
        for category in ("DEFAULT", "BROWSABLE"):
            el = ET.SubElement(intent_filter, "category")
            el.set(_android("name"), f"android.intent.category.{category}")
        data = ET.SubElement(intent_filter, "data")
        data.set(_android("scheme"), DEEP_LINK_SCHEME)
        changes.append(f"{DEEP_LINK_SCHEME}:// deep link")

    if changes:
        tree.write(path, encoding="utf-8", xml_declaration=True)
    return changes


def patch_gradle(app_dir: Path) -> list[str]:
    """Enables core library desugaring, which the notifications plugin needs.

    The blocks are appended rather than edited into place: Gradle allows an
    extension to be configured more than once, so adding a second `android { }`
    is both valid and immune to however the generated file happens to be laid
    out — which changes between Flutter versions.
    """
    kts = app_dir / "build.gradle.kts"
    groovy = app_dir / "build.gradle"
    path = kts if kts.exists() else groovy
    if not path.exists():
        raise SystemExit(f"no app build file under {app_dir}")

    body = path.read_text()
    if "coreLibraryDesugaring" in body:
        return []

    if path.suffix == ".kts":
        addition = f"""

// Added by tool/configure_platform.py — required by flutter_local_notifications.
android {{
    compileOptions {{
        isCoreLibraryDesugaringEnabled = true
    }}
}}

dependencies {{
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:{DESUGAR_VERSION}")
}}
"""
    else:
        addition = f"""

// Added by tool/configure_platform.py — required by flutter_local_notifications.
android {{
    compileOptions {{
        coreLibraryDesugaringEnabled true
    }}
}}

dependencies {{
    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:{DESUGAR_VERSION}'
}}
"""

    path.write_text(body + addition)
    return [f"core library desugaring ({path.name})"]


def patch_application_id(app_dir: Path, app_id: str) -> list[str]:
    """Replaces the `com.example.…` application id `flutter create` generates.

    Only `applicationId` is touched, never `namespace`: the namespace has to
    match the package the generated Kotlin source lives in, and renaming one
    without moving the other stops the build.
    """
    kts = app_dir / "build.gradle.kts"
    groovy = app_dir / "build.gradle"
    path = kts if kts.exists() else groovy
    body = path.read_text()

    patched = re.sub(
        r'(applicationId\s*=?\s*)"[^"]*"',
        lambda m: f'{m.group(1)}"{app_id}"',
        body,
    )
    if patched == body:
        return []
    path.write_text(patched)
    return [f"applicationId {app_id}"]


def patch_ios_bundle_id(project_file: Path, app_id: str) -> list[str]:
    """Same for iOS, where the id lives in the Xcode project file."""
    body = project_file.read_text()
    patched = re.sub(
        r"(PRODUCT_BUNDLE_IDENTIFIER = )[^;]*;",
        lambda m: f"{m.group(1)}{app_id};",
        body,
    )
    # The Runner tests target appends `.RunnerTests`, which the blanket replace
    # above would have flattened onto the app id.
    patched = patched.replace(
        f"PRODUCT_BUNDLE_IDENTIFIER = {app_id};\n\t\t\t\tPRODUCT_NAME = \"$(TARGET_NAME)\";\n\t\t\t\tTEST_HOST",
        f"PRODUCT_BUNDLE_IDENTIFIER = {app_id}.RunnerTests;\n\t\t\t\tPRODUCT_NAME = \"$(TARGET_NAME)\";\n\t\t\t\tTEST_HOST",
    )
    if patched == body:
        return []
    project_file.write_text(patched)
    return [f"iOS bundle id {app_id}"]


SIGNING_KTS = """

// Added by tool/configure_platform.py — release signing from key.properties.
// Absent keystore = untouched debug behaviour, so a local build still works.
val dollcheckerKeystore = rootProject.file("key.properties")
val dollcheckerKeyProps = java.util.Properties().apply {
    if (dollcheckerKeystore.exists()) {
        java.io.FileInputStream(dollcheckerKeystore).use { load(it) }
    }
}

android {
    signingConfigs {
        create("release") {
            if (dollcheckerKeystore.exists()) {
                keyAlias = dollcheckerKeyProps["keyAlias"] as String
                keyPassword = dollcheckerKeyProps["keyPassword"] as String
                storeFile = file(dollcheckerKeyProps["storeFile"] as String)
                storePassword = dollcheckerKeyProps["storePassword"] as String
            }
        }
    }
    buildTypes {
        getByName("release") {
            if (dollcheckerKeystore.exists()) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }
}
"""

SIGNING_GROOVY = """

// Added by tool/configure_platform.py — release signing from key.properties.
def dollcheckerKeystore = rootProject.file("key.properties")
def dollcheckerKeyProps = new Properties()
if (dollcheckerKeystore.exists()) {
    dollcheckerKeystore.withInputStream { dollcheckerKeyProps.load(it) }
}

android {
    signingConfigs {
        release {
            if (dollcheckerKeystore.exists()) {
                keyAlias dollcheckerKeyProps['keyAlias']
                keyPassword dollcheckerKeyProps['keyPassword']
                storeFile file(dollcheckerKeyProps['storeFile'])
                storePassword dollcheckerKeyProps['storePassword']
            }
        }
    }
    buildTypes {
        release {
            if (dollcheckerKeystore.exists()) {
                signingConfig signingConfigs.release
            }
        }
    }
}
"""


def patch_release_signing(app_dir: Path) -> list[str]:
    """Signs release builds with the keystore named in `key.properties`."""
    kts = app_dir / "build.gradle.kts"
    groovy = app_dir / "build.gradle"
    path = kts if kts.exists() else groovy
    body = path.read_text()
    if "dollcheckerKeystore" in body:
        return []
    path.write_text(body + (SIGNING_KTS if path.suffix == ".kts" else SIGNING_GROOVY))
    return ["release signing config"]


IOS_KEYS = {
    "NSCameraUsageDescription":
        "DollChecker uses the camera to photograph a toy for analysis.",
    "NSPhotoLibraryUsageDescription":
        "DollChecker reads a photo of a toy so it can be analyzed.",
}


def patch_info_plist(path: Path) -> list[str]:
    """Adds the usage strings iOS kills the app for missing, and the URL scheme."""
    body = path.read_text()
    changes: list[str] = []

    additions = ""
    for key, description in IOS_KEYS.items():
        if f"<key>{key}</key>" in body:
            continue
        additions += f"\t<key>{key}</key>\n\t<string>{description}</string>\n"
        changes.append(key)

    if "CFBundleDisplayName" not in body:
        additions += (
            f"\t<key>CFBundleDisplayName</key>\n\t<string>{DISPLAY_NAME}</string>\n"
        )
        changes.append("CFBundleDisplayName")

    if "CFBundleURLTypes" not in body:
        additions += (
            "\t<key>CFBundleURLTypes</key>\n"
            "\t<array>\n"
            "\t\t<dict>\n"
            "\t\t\t<key>CFBundleURLSchemes</key>\n"
            "\t\t\t<array>\n"
            f"\t\t\t\t<string>{DEEP_LINK_SCHEME}</string>\n"
            "\t\t\t</array>\n"
            "\t\t</dict>\n"
            "\t</array>\n"
        )
        changes.append(f"{DEEP_LINK_SCHEME}:// URL type")

    if additions:
        # Insert before the final </dict>, which closes the root dictionary.
        marker = "</dict>\n</plist>"
        if marker not in body:
            raise SystemExit(f"unexpected plist layout in {path}")
        body = body.replace(marker, additions + marker)
        path.write_text(body)
    return changes


def main(argv: list[str]) -> int:
    args = [a for a in argv[1:] if not a.startswith("--")]
    flags = {a.split("=")[0]: a.partition("=")[2] for a in argv[1:] if a.startswith("--")}
    root = Path(args[0] if args else "app")
    app_id = flags.get("--app-id") or DEFAULT_APP_ID
    applied: list[str] = []

    manifest = root / "android/app/src/main/AndroidManifest.xml"
    if manifest.exists():
        applied += patch_manifest(manifest)
        applied += patch_gradle(root / "android/app")
        applied += patch_application_id(root / "android/app", app_id)
        if "--release-signing" in flags:
            applied += patch_release_signing(root / "android/app")
    else:
        print(f"skipping Android: {manifest} not generated")

    plist = root / "ios/Runner/Info.plist"
    if plist.exists():
        applied += patch_info_plist(plist)
        project = root / "ios/Runner.xcodeproj/project.pbxproj"
        if project.exists():
            applied += patch_ios_bundle_id(project, app_id)
    else:
        print(f"skipping iOS: {plist} not generated")

    if applied:
        print("applied: " + ", ".join(applied))
    else:
        print("nothing to apply — already configured")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
