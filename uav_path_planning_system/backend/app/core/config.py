import os
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class Settings:
    repository_root: Path = Path(os.getenv("UAV_SYSTEM_REPOSITORY_ROOT", "C:/Repositories/PlatEMO"))
    matlab_executable: str = os.getenv("UAV_SYSTEM_MATLAB_EXECUTABLE", "matlab")
    matlab_runner: str = os.getenv("UAV_SYSTEM_MATLAB_RUNNER", "cli")

    @property
    def project_root(self) -> Path:
        return self.repository_root / "uav_path_planning_system"

    @property
    def platemo_root(self) -> Path:
        return self.repository_root / "PlatEMO"

    @property
    def runtime_root(self) -> Path:
        return self.project_root / ".runtime"

    @property
    def artifact_root(self) -> Path:
        return self.runtime_root / "artifacts"

    @property
    def database_path(self) -> Path:
        return self.runtime_root / "uav_path_planning.sqlite3"
