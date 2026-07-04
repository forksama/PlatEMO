from pathlib import Path
from typing import Protocol

from backend.app.domain.models import PlanningConfig


class MatlabRunner(Protocol):
    def run(self, job_id: str, config: PlanningConfig, artifact_dir: Path) -> Path:
        ...
