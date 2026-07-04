from pathlib import Path

from backend.app.core.config import Settings
from backend.app.domain.models import PlanningConfig


class MatlabEngineRunner:
    def __init__(self, settings: Settings) -> None:
        self.settings = settings

    def run(self, job_id: str, config: PlanningConfig, artifact_dir: Path) -> Path:
        try:
            import matlab.engine  # type: ignore[import-not-found]
        except ModuleNotFoundError as exc:
            raise RuntimeError(
                "matlab.engine is not installed for this Python interpreter; use CLI runner."
            ) from exc

        raise RuntimeError("Engine runner is reserved for the second integration pass.")
