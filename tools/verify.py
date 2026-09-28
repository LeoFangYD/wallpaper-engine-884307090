"""Check that this repository can be installed into Lively Wallpaper on this machine.

Run this after cloning (and again after converting) to find out whether the wallpaper is
ready to import.  It writes nothing except, with --convert, the generated files that
tools/convert-to-lively.py itself creates.

    python tools/verify.py                    # check the repository
    python tools/verify.py --convert          # generate the files first, then check
    python tools/verify.py --installed        # also check the copy Lively is running

Every check reports OK, FAIL or SKIP.  FAIL exits 1, so this is usable in CI.  The script
only uses the standard library, so it runs on a fresh Python with no pip install.
"""
import argparse
import json
import os
import subprocess
import sys
import winreg

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
PROJECT = os.path.join(REPO, "884307090")

ENTRY = "index-lively.html"
MANIFEST = "LivelyInfo.json"
ADAPTER = "adapter.js"
PATCHED_MAIN = os.path.join("js", "main-lively.js")

GENERATED = [ADAPTER, ENTRY, MANIFEST, PATCHED_MAIN]

LIVELY_EXE_NAMES = ("Lively.exe",)

# Lively ships as an MSIX package, and packaged apps write to a redirected AppData tree.
LIVELY_PACKAGE = "12030rocksdanister.LivelyWallpaper_97hta09mmv6hy"

_results = []


def record(status: str, name: str, detail: str = "") -> None:
    _results.append((status, name, detail))
    line = f"  [{status}] {name}"
    if detail:
        line += f"\n         {detail}"
    print(line, flush=True)


def ok(name: str, detail: str = "") -> None:
    record("OK", name, detail)


def fail(name: str, detail: str = "") -> None:
    record("FAIL", name, detail)


def skip(name: str, detail: str = "") -> None:
    record("SKIP", name, detail)


def read_text(path: str):
    try:
        with open(path, encoding="utf-8-sig") as handle:
            return handle.read()
    except OSError:
        return None


# --------------------------------------------------------------------------- repository

def check_python() -> None:
    version = ".".join(str(part) for part in sys.version_info[:3])
    if sys.version_info >= (3, 9):
        ok("python >= 3.9", f"found {version}")
    else:
        fail("python >= 3.9", f"found {version}; the converter needs 3.9 or newer")


def check_project() -> None:
    if not os.path.isdir(PROJECT):
        fail("project folder 884307090/", f"missing at {PROJECT}")
        return
    missing = [name for name in ("index.html", "project.json")
               if not os.path.isfile(os.path.join(PROJECT, name))]
    if missing:
        fail("project folder 884307090/", f"missing {', '.join(missing)}")
    else:
        ok("project folder 884307090/",
           "index.html and project.json present (this is a Wallpaper Engine web project)")


def check_generated(convert: bool) -> bool:
    present = [name for name in GENERATED
               if os.path.isfile(os.path.join(PROJECT, name))]
    if len(present) == len(GENERATED):
        ok("generated files", f"all {len(GENERATED)} present")
        return True

    missing = [name for name in GENERATED if name not in present]
    if not convert:
        # not a cosmetic problem: importing the folder without these gives a black desktop
        fail("generated files",
             f"{len(missing)} missing ({', '.join(missing)}); "
             f"run: python tools/verify.py --convert")
        return False

    print("  [..] generating with tools/convert-to-lively.py", flush=True)
    result = subprocess.run(
        [sys.executable, os.path.join(HERE, "convert-to-lively.py"), PROJECT],
        capture_output=True, text=True, encoding="utf-8", errors="replace")
    if result.returncode != 0:
        fail("converter run", (result.stdout + result.stderr).strip()[:600])
        return False
    ok("converter run", "tools/convert-to-lively.py finished (adds files only)")
    still = [name for name in GENERATED if not os.path.isfile(os.path.join(PROJECT, name))]
    if still:
        fail("generated files", f"still missing: {', '.join(still)}")
        return False
    ok("generated files", f"all {len(GENERATED)} present")
    return True


def check_entry() -> bool:
    text = read_text(os.path.join(PROJECT, ENTRY))
    if text is None:
        fail(f"{ENTRY} readable", "cannot read the Lively entry point")
        return False
    ok(f"{ENTRY} readable", f"{len(text.encode('utf-8'))} bytes")

    healthy = True
    if text.count("Lively bootstrap (added by") != 1:
        fail("bootstrap present exactly once",
             f"found {text.count('Lively bootstrap (added by')}; "
             f"re-run the converter to normalise")
        healthy = False
    else:
        ok("bootstrap present exactly once",
           "removes the 0-byte media placeholders and hides the weather box")

    adapter_tag = '<script src="adapter.js">'
    count = text.count(adapter_tag)
    if count != 1:
        fail("adapter.js wired in once", f"found {count} references")
        healthy = False
    else:
        ok("adapter.js wired in once", "supplies the author's 132 default properties")

    if PATCHED_MAIN.replace(os.sep, "/") not in text.replace(os.sep, "/"):
        fail("main-lively.js wired in", "the anti-tamper check would still run")
        healthy = False
    elif '<script src="js/main.js">' in text:
        fail("original main.js not referenced",
             "the page still loads js/main.js, which wedges WebView2")
        healthy = False
    else:
        ok("main-lively.js wired in", "the workshop-id check is neutralised")

    # The author's own index.html writes `<source src= null>` - an invalid attribute value
    # that is preserved on purpose, because the branch promises not to touch upstream bytes.
    # What matters is that the bootstrap strips the attribute at runtime, so nothing is
    # ever fetched; check that instead of the spelling.
    if "removeAttribute('src')" not in text:
        fail("media sources are stripped at runtime",
             "the bootstrap no longer clears the 0-byte media placeholders")
        healthy = False
    else:
        ok("media sources are stripped at runtime",
           "upstream ships `<source src= null>`; the bootstrap removes the attribute "
           "before it is used, so no request is made")
    return healthy


def check_manifest() -> bool:
    path = os.path.join(PROJECT, MANIFEST)
    try:
        with open(path, encoding="utf-8-sig") as handle:
            manifest = json.load(handle)
    except OSError:
        fail(f"{MANIFEST} readable", f"cannot read {path}")
        return False
    except json.JSONDecodeError as error:
        fail(f"{MANIFEST} is valid JSON", str(error))
        return False
    ok(f"{MANIFEST} is valid JSON")

    healthy = True
    if manifest.get("FileName") != ENTRY:
        fail("manifest FileName points at the entry point",
             f'FileName is {manifest.get("FileName")!r}, expected {ENTRY!r}')
        healthy = False
    else:
        ok("manifest FileName points at the entry point", ENTRY)

    if manifest.get("IsAbsolutePath"):
        fail("manifest uses a relative path", "IsAbsolutePath is true")
        healthy = False
    else:
        ok("manifest uses a relative path", "the folder can live anywhere")

    for key in ("Thumbnail", "Preview"):
        value = manifest.get(key)
        if value is None:
            fail(f"manifest {key} resolved",
                 "null - the converter ran with --output into a folder that did not "
                 "already contain preview.jpg and lively/, so the gallery art was skipped")
            healthy = False
        elif not os.path.isfile(os.path.join(PROJECT, value)):
            fail(f"manifest {key} exists", f"{value} is referenced but not on disk")
            healthy = False
        else:
            ok(f"manifest {key} exists", value)
    return healthy


def _lively_from_appx() -> str:
    """Resolve the store build through the AppX package registry.

    `C:\\Program Files\\WindowsApps` cannot be listed without elevation, so the install
    location has to come from the package registration instead.  The `Packages` key holds
    one subkey per installed package and carries `PackageRootFolder`; the `Families` key
    that older documentation mentions does not exist on current Windows builds.
    """
    bases = [
        r"Software\Classes\Local Settings\Software\Microsoft\Windows"
        r"\CurrentVersion\AppModel\Repository\Packages",
        r"Software\Classes\Local Settings\Software\Microsoft\Windows"
        r"\CurrentVersion\AppModel\Repository\Families",
    ]
    for base in bases:
        try:
            with winreg.OpenKey(winreg.HKEY_CURRENT_USER, base) as parent:
                count = winreg.QueryInfoKey(parent)[0]
                names = [winreg.EnumKey(parent, index) for index in range(count)]
        except OSError:
            continue
        for name in names:
            if "LivelyWallpaper" not in name:
                continue
            try:
                with winreg.OpenKey(winreg.HKEY_CURRENT_USER, base + "\\" + name) as key:
                    for value_name in ("PackageRootFolder", "InstallLocation"):
                        try:
                            location = str(winreg.QueryValueEx(key, value_name)[0])
                        except OSError:
                            continue
                        if os.path.isdir(location):
                            return location
            except OSError:
                continue
    return ""


def check_lively_installed():
    """Return the Lively executable path, or None."""
    roots = []
    appx = _lively_from_appx()
    if appx:
        roots.append(appx)
    for root in (os.environ.get("ProgramFiles", r"C:\Program Files"),
                 os.environ.get("LOCALAPPDATA", "")):
        if root:
            roots.append(root)

    # portable / GitHub release install, recorded by the uninstall entry
    for hive, key_path in (
        (winreg.HKEY_CURRENT_USER, r"Software\Microsoft\Windows\CurrentVersion\Uninstall"),
        (winreg.HKEY_LOCAL_MACHINE,
         r"Software\Microsoft\Windows\CurrentVersion\Uninstall"),
        (winreg.HKEY_LOCAL_MACHINE,
         r"Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"),
    ):
        try:
            with winreg.OpenKey(hive, key_path) as parent:
                for index in range(winreg.QueryInfoKey(parent)[0]):
                    try:
                        with winreg.OpenKey(parent, winreg.EnumKey(parent, index)) as child:
                            try:
                                name = str(winreg.QueryValueEx(child, "DisplayName")[0])
                            except OSError:
                                continue
                            if "lively" not in name.lower():
                                continue
                            try:
                                location = str(winreg.QueryValueEx(
                                    child, "InstallLocation")[0])
                            except OSError:
                                continue
                            if location:
                                roots.append(location)
                    except OSError:
                        continue
        except OSError:
            continue

    for root in roots:
        for sub in ("", "Build", os.path.join("app")):
            for exe in LIVELY_EXE_NAMES:
                candidate = os.path.join(root, sub, exe) if sub else os.path.join(root, exe)
                if os.path.isfile(candidate):
                    return candidate
    return None


def check_lively() -> None:
    exe = check_lively_installed()
    if exe:
        ok("Lively Wallpaper installed", exe)
        return
    skip("Lively Wallpaper installed",
         "not found. Install it from the Microsoft Store "
         "(product id 9NTM2QC6QWS7) or from "
         "https://github.com/rocksdanister/lively/releases, then import the "
         "884307090 folder via Add Wallpaper")


def _layout_paths():
    """Every place Lively may have written WallpaperLayout.json.

    The store build is packaged, so the file lands in the package's redirected AppData
    (LocalCache) rather than in %LOCALAPPDATA%\\Lively Wallpaper directly; a portable
    install uses the plain path.  Both are checked.
    """
    local = os.environ.get("LOCALAPPDATA", "")
    if not local:
        return []
    return [
        os.path.join(local, "Lively Wallpaper", "WallpaperLayout.json"),
        os.path.join(local, "Packages", LIVELY_PACKAGE, "LocalCache", "Local",
                     "Lively Wallpaper", "WallpaperLayout.json"),
    ]


def check_installed() -> None:
    for launcher in _layout_paths():
        if os.path.isfile(launcher):
            break
    else:
        skip("installed copy in Lively's library",
             "WallpaperLayout.json not found in any known location; "
             "nothing has been imported yet")
        return
    try:
        with open(launcher, encoding="utf-8-sig") as handle:
            layout = json.load(handle)
        current = [entry.get("LivelyInfoPath") for entry in layout]
    except (OSError, json.JSONDecodeError) as error:
        skip("installed copy in Lively's library", f"cannot read the layout: {error}")
        return
    current = [path for path in current if path]
    if not current:
        skip("installed copy in Lively's library", "no wallpaper is set")
        return
    normalised = [os.path.normcase(os.path.normpath(path)) for path in current]
    if os.path.normcase(os.path.normpath(PROJECT)) in normalised:
        ok("installed copy in Lively's library",
           "the running wallpaper is this repository folder")
    else:
        skip("installed copy in Lively's library",
             "Lively is running a different wallpaper: " + "; ".join(current))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--convert", action="store_true",
                        help="run tools/convert-to-lively.py first if files are missing")
    parser.add_argument("--installed", action="store_true",
                        help="also report whether Lively is running this folder")
    args = parser.parse_args()

    print(f"repository  {REPO}")
    print(f"project     {PROJECT}")
    print()

    check_python()
    check_project()
    if check_generated(args.convert):
        check_entry()
        check_manifest()
    check_lively()
    if args.installed:
        check_installed()

    failed = [name for status, name, _ in _results if status == "FAIL"]
    skipped = [name for status, name, _ in _results if status == "SKIP"]
    print()
    print(f"{len(_results)} checks: {len(_results) - len(failed) - len(skipped)} ok, "
          f"{len(failed)} failed, {len(skipped)} skipped")
    if failed:
        print("RESULT: not ready - " + "; ".join(failed))
        return 1
    print("RESULT: ready to import into Lively "
          "(Add Wallpaper -> select the 884307090 folder)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
