import os
import stat
import subprocess
import tempfile
import textwrap
import unittest
from pathlib import Path


class TestLargeV3Config(unittest.TestCase):
    def test_gpu_defaults_use_turbo_model_and_quantized_compute(self):
        repo_dir = Path(__file__).resolve().parent

        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            fake_bin = tmp_path / "bin"
            fake_home = tmp_path / "home"
            fake_bin.mkdir()
            fake_home.mkdir()

            self._write_executable(
                fake_bin / "ldconfig",
                "#!/bin/sh\nprintf 'libcudnn.so.9 (libc6,x86-64) => /usr/lib/libcudnn.so.9\\n'\n",
            )
            self._write_executable(
                fake_bin / "nvidia-smi",
                textwrap.dedent(
                    """\
                    #!/bin/sh
                    case "$*" in
                      *name,memory.total*) printf 'NVIDIA RTX 4070, 12282\\n' ;;
                      *memory.used,memory.total*) printf '100, 12282\\n' ;;
                      *) exit 0 ;;
                    esac
                    """
                ),
            )

            env = os.environ.copy()
            env["HOME"] = str(fake_home)
            env["PATH"] = f"{fake_bin}:{env['PATH']}"
            env.pop("STT_MODEL", None)
            env.pop("STT_DEVICE", None)
            env.pop("STT_COMPUTE_TYPE", None)

            result = subprocess.run(
                [
                    "bash",
                    "-lc",
                    (
                        "source ./large-v3-config.sh >/dev/null && "
                        "printf '%s\\n%s\\n' \"$STT_MODEL\" \"$STT_COMPUTE_TYPE\""
                    ),
                ],
                cwd=repo_dir,
                env=env,
                text=True,
                capture_output=True,
                check=True,
            )

        self.assertEqual(result.stdout.splitlines(), ["large-v3-turbo", "int8_float16"])

    def test_config_manager_defaults_use_turbo_model_and_quantized_compute(self):
        repo_dir = Path(__file__).resolve().parent

        with tempfile.TemporaryDirectory() as tmp:
            env = os.environ.copy()
            env["HOME"] = tmp
            env.pop("STT_MODEL", None)
            env.pop("STT_COMPUTE_TYPE", None)

            result = subprocess.run(
                [
                    "bash",
                    "-lc",
                    (
                        "./config-manager.sh init >/dev/null && "
                        "source \"$HOME/.config/speech-to-text/config.conf\" && "
                        "printf '%s\\n%s\\n' \"$STT_MODEL\" \"$STT_COMPUTE_TYPE\""
                    ),
                ],
                cwd=repo_dir,
                env=env,
                text=True,
                capture_output=True,
                check=True,
            )

        self.assertEqual(result.stdout.splitlines(), ["large-v3-turbo", "int8_float16"])

    def _write_executable(self, path, contents):
        path.write_text(contents)
        path.chmod(path.stat().st_mode | stat.S_IXUSR)


if __name__ == "__main__":
    unittest.main()
