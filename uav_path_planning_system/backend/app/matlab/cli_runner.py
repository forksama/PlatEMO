import subprocess
import threading
from pathlib import Path
from typing import TextIO

from backend.app.core.config import Settings
from backend.app.domain.models import PlanningConfig


class MatlabCliRunner:
    def __init__(self, settings: Settings) -> None:
        self.settings = settings

    def run(self, job_id: str, config: PlanningConfig, artifact_dir: Path) -> Path:
        artifact_dir = artifact_dir.resolve()
        artifact_dir.mkdir(parents=True, exist_ok=True)
        input_path = artifact_dir / "input.json"
        result_path = artifact_dir / "result.json"
        stdout_path = artifact_dir / "stdout.log"
        stderr_path = artifact_dir / "stderr.log"
        input_path.write_text(config.model_dump_json(indent=2, by_alias=True), encoding="utf-8")

        script_dir = (
            self.settings.project_root / "backend" / "app" / "matlab" / "scripts"
        ).resolve()
        platemo_root = self.settings.platemo_root.resolve()
        command_expr = (
            f"addpath('{script_dir.as_posix()}'); "
            f"run_planning_job('{platemo_root.as_posix()}', "
            f"'{input_path.as_posix()}', '{artifact_dir.as_posix()}')"
        )
        process = subprocess.Popen(
            [self.settings.matlab_executable, "-batch", command_expr],
            cwd=self.settings.repository_root,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            bufsize=1,
        )
        stdout_thread = threading.Thread(
            target=self._stream_to_file,
            args=(process.stdout, stdout_path),
            daemon=True,
        )
        stderr_thread = threading.Thread(
            target=self._stream_to_file,
            args=(process.stderr, stderr_path),
            daemon=True,
        )
        stdout_thread.start()
        stderr_thread.start()
        return_code = process.wait()
        stdout_thread.join()
        stderr_thread.join()
        if return_code != 0:
            raise RuntimeError(f"Matlab failed with exit code {return_code}")
        if not result_path.exists():
            raise FileNotFoundError(f"Matlab did not create {result_path}")
        return result_path

    def _stream_to_file(self, stream: TextIO | None, path: Path) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        with path.open("w", encoding="utf-8") as handle:
            if stream is None:
                return
            while True:
                line = stream.readline()
                if line == "":
                    break
                handle.write(line)
                handle.flush()
