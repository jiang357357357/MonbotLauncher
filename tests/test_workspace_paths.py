"""Run path-resolution entry points in isolated layouts with fake MonPM files."""
from __future__ import annotations

import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


SOURCE = Path(__file__).resolve().parents[1]
POWERSHELL = shutil.which("powershell.exe") or shutil.which("pwsh")
BASH = shutil.which("bash")
if os.name == "nt" and not BASH:
    candidate = Path("C:/Program Files/Git/bin/bash.exe")
    BASH = str(candidate) if candidate.is_file() else None


def ps_quote(value: Path) -> str:
    return "'" + str(value).replace("'", "''") + "'"


class WorkspacePathTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix="eden-bot-workspace-")
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name) / "Mon workspace"
        self.root.mkdir()
        self.env = {key: value for key, value in os.environ.items()
                    if not key.startswith(("MON_", "NAPCAT_"))}

    def write(self, path: Path, text=""):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding="utf-8", newline="\n")
        return path

    def project(self, relative="DLC/BotLauncher"):
        project = self.root / relative
        project.mkdir(parents=True, exist_ok=True)
        self.write(self.root / ".monworkspace", "{}")
        self.write(project / ".monconfig", "[napcat_process]\nMODE=custom\n")
        for relative in (
            "Script/Process/linux/workspace_root.sh", "Script/Process/linux/common.sh",
            "Script/Process/linux/napcat_common.sh", "Script/Process/linux/log_paths.sh",
            "Script/Cmd/linux/start.sh", "Script/Process/linux/status_process.sh",
            "Script/Runtime/linux/build_napcat_offline_bundle.sh",
            "Script/Process/win/portable_context.ps1", "Script/Process/win/napcat_common.ps1",
        ):
            self.write(project / relative, (SOURCE / relative).read_text(encoding="utf-8"))
        return project

    def powershell(self, command):
        if not POWERSHELL:
            self.skipTest("PowerShell is unavailable")
        result = subprocess.run([POWERSHELL, "-NoProfile", "-NonInteractive", "-Command", command],
                                cwd=self.root, env=self.env, capture_output=True, text=True, encoding="utf-8", timeout=20)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        return result.stdout.strip()

    def bash(self, *arguments, expect=0):
        if not BASH:
            self.skipTest("Bash is unavailable")
        result = subprocess.run([BASH, "--noprofile", "--norc", *map(str, arguments)],
                                cwd=self.root, env=self.env, capture_output=True, text=True, encoding="utf-8", timeout=20)
        self.assertEqual(result.returncode, expect, result.stdout + result.stderr)
        return (result.stdout + result.stderr if expect else result.stdout).strip()

    def shell_root(self, project):
        return Path(self.bash("-c", 'source "$1"; value="$(resolve_mon_workspace_root "$2")"; '
                             'if command -v cygpath >/dev/null; then cygpath -m "$value"; else printf "%s" "$value"; fi',
                             "test", (project / "Script/Process/linux/workspace_root.sh").as_posix(), project.as_posix()))

    def test_linux_old_and_relocated_source_find_same_workspace(self):
        for relative in ("BotLauncher", "DLC/BotLauncher"):
            with self.subTest(relative=relative):
                self.assertEqual(self.shell_root(self.project(relative)), self.root)

    def test_linux_nearest_qqbot_workspace_and_explicit_override(self):
        project = self.project("DLC/QQBot/BotLauncher")
        self.write(project.parent / ".monworkspace", "{}")
        self.assertEqual(self.shell_root(project), project.parent)
        self.env["MON_WORKSPACE_ROOT"] = self.root.as_posix()
        self.assertEqual(self.shell_root(project), self.root)

    def test_linux_standalone_falls_back_to_parent(self):
        project = self.project()
        (self.root / ".monworkspace").unlink()
        self.assertEqual(self.shell_root(project), project.parent)

    def test_linux_start_and_status_use_workspace_monpm_after_move(self):
        project = self.project()
        trace = self.root / "calls.txt"
        self.env["TRACE"] = trace.as_posix()
        launcher = self.write(self.root / "Script/launch/linux/monpm-module.sh",
                              '#!/usr/bin/env bash\nprintf "%s\\n" "$*" >> "$TRACE"\n')
        launcher.chmod(0o755)
        self.bash((project / "Script/Cmd/linux/start.sh").as_posix(), "--skip-napcat")
        self.bash((project / "Script/Process/linux/status_process.sh").as_posix())
        self.assertEqual(trace.read_text().splitlines(),
                         ["bot start --skip-napcat", "bot status", "napcat status", "bot status"])
        self.assertFalse((project.parent / "Script/launch").exists())

    def test_linux_napcat_keeps_sibling_portable_monpm_control(self):
        project = self.project("QQBot/BotLauncher")
        self.write(project.parent / ".monworkspace", "{}")
        portable = self.root / "LINUX"
        executable = self.write(portable / "bin/monpm", "#!/usr/bin/env bash\nexit 0\n")
        executable.chmod(0o755)
        self.write(portable / ".run/monpm/monpm.dlc.json", "{}")
        actual = self.bash("-c", 'source "$1"; if command -v cygpath >/dev/null; '
                           'then cygpath -m "$MON_ROOT"; else printf "%s" "$MON_ROOT"; fi',
                           "test", (project / "Script/Process/linux/napcat_common.sh").as_posix())
        self.assertEqual(Path(actual), portable)

    def test_linux_offline_builder_help_does_not_build_or_download(self):
        project = self.project()
        output = self.bash((project / "Script/Runtime/linux/build_napcat_offline_bundle.sh").as_posix(), "--help")
        self.assertIn("DLC/BotLauncher/Script/Runtime/linux/build_napcat_offline_bundle.sh", output)
        self.assertFalse((self.root / ".release").exists())

    def test_generated_offline_installer_discovers_relocated_source(self):
        project = self.project()
        source = (project / "Script/Runtime/linux/build_napcat_offline_bundle.sh").read_text(encoding="utf-8")
        # Execute the actual embedded installer, stopping at its required-file
        # check before package installation can begin. Only fixture dirs change.
        template = source.split('cat > "$output" <<\'EOF\'\n', 1)[1].split("\nEOF", 1)[0]
        installer = self.write(self.root / "offline-test/install-offline.sh", template)
        output = self.bash(installer.as_posix(), expect=1)
        self.assertIn("DLC/BotLauncher", output)
        self.assertTrue((project / "napcat").is_dir())
        self.assertIn("install.sh", output)

    def test_windows_old_and_relocated_source_find_same_workspace(self):
        for relative in ("BotLauncher", "DLC/BotLauncher"):
            with self.subTest(relative=relative):
                project = self.project(relative)
                output = self.powershell(f". {ps_quote(project / 'Script/Process/win/portable_context.ps1')}; "
                                         f"Find-NapCatWorkspaceRoot -ProjectRoot {ps_quote(project)}")
                self.assertEqual(Path(output), self.root)

    def test_windows_source_process_status_uses_workspace_monpm(self):
        project = self.project()
        self.write(self.root / ".run/monpm/monpm.json", json.dumps({"apps": [{"name": "napcat"}]}))
        self.write(self.root / "Script/launch/win/monpm.ps1",
                   "param($Action, $Name, [switch]$Json)\n"
                   "if ($Action -ne 'list') { throw 'Unexpected operation' }\n"
                   "'[ {\"name\":\"napcat\",\"lifecycle_state\":\"running\"} ]'\n")
        output = self.powershell(f". {ps_quote(project / 'Script/Process/win/napcat_common.ps1')}; "
                                "@{Root=$NapCatMonRoot;Status=(Get-NapCatMonPmStatus)} | ConvertTo-Json -Compress")
        data = json.loads(output)
        self.assertEqual(Path(data["Root"]), self.root)
        self.assertEqual(data["Status"], "running")

    def test_windows_sibling_portable_keeps_merged_monpm_context(self):
        project = self.project("QQBot/BotLauncher")
        self.write(project.parent / ".monworkspace", "{}")
        portable = self.root / "EDEN_win"
        for relative in ("bin/monpm.exe", ".monworkspace", "monpm.json", ".run/monpm/monpm.dlc.json"):
            self.write(portable / relative, "fixture")
        output = self.powershell(f". {ps_quote(project / 'Script/Process/win/portable_context.ps1')}; "
                                f"Find-NapCatMonPmContext -ProjectRoot {ps_quote(project)} | ConvertTo-Json -Compress")
        data = json.loads(output)
        self.assertEqual(Path(data["Root"]), portable)
        self.assertEqual(Path(data["Config"]), portable / ".run/monpm/monpm.dlc.json")

    def test_windows_nearest_workspace_override_and_legacy_fallback(self):
        project = self.project("DLC/QQBot/BotLauncher")
        self.write(project.parent / ".monworkspace", "{}")
        command = (f". {ps_quote(project / 'Script/Process/win/portable_context.ps1')}; "
                   f"Find-NapCatWorkspaceRoot -ProjectRoot {ps_quote(project)}")
        self.assertEqual(Path(self.powershell(command)), project.parent)
        self.env["MON_WORKSPACE_ROOT"] = str(self.root)
        self.assertEqual(Path(self.powershell(command)), self.root)
        del self.env["MON_WORKSPACE_ROOT"]
        (project.parent / ".monworkspace").unlink()
        (self.root / ".monworkspace").unlink()
        self.assertEqual(Path(self.powershell(command)), project.parent)


if __name__ == "__main__":
    unittest.main()
