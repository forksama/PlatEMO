import subprocess
from pathlib import Path

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
        input_path.write_text(config.model_dump_json(indent=2), encoding="utf-8")

        script_dir = (
            self.settings.project_root / "backend" / "app" / "matlab" / "scripts"
        ).resolve()
        platemo_root = self.settings.platemo_root.resolve()
        command_expr = (
            f"addpath('{script_dir.as_posix()}'); "
            f"run_planning_job('{platemo_root.as_posix()}', "
            f"'{input_path.as_posix()}', '{artifact_dir.as_posix()}')"
        )
        completed = subprocess.run(
            [self.settings.matlab_executable, "-batch", command_expr],
            cwd=self.settings.repository_root,
            capture_output=True,
            text=True,
            check=False,
        )
        stdout_path.write_text(completed.stdout, encoding="utf-8")
        stderr_path.write_text(completed.stderr, encoding="utf-8")
        if completed.returncode != 0:
            raise RuntimeError(f"Matlab failed with exit code {completed.returncode}")
        if not result_path.exists():
            raise FileNotFoundError(f"Matlab did not create {result_path}")
        return result_path
