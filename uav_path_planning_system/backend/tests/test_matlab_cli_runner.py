from pathlib import Path
import unittest

from backend.app.core.config import Settings
from backend.app.domain.models import PlanningConfig
from backend.app.matlab.cli_runner import MatlabCliRunner


class FakeCompletedProcess:
    returncode = 0
    stdout = "ok"
    stderr = ""


class MatlabCliRunnerTests(unittest.TestCase):
    def test_cli_runner_writes_input_and_invokes_matlab(self) -> None:
        calls: list[list[str]] = []
        artifact_dir = Path("test-runtime/matlab-cli/job-1").resolve()

        def fake_run(command, cwd, capture_output, text, check):
            calls.append(command)
            result_path = artifact_dir / "result.json"
            result_path.parent.mkdir(parents=True, exist_ok=True)
            result_path.write_text(
                '{"metrics":{"solutionCount":0},"objectives":[],"solutions":[],"scenario":{}}',
                encoding="utf-8",
            )
            return FakeCompletedProcess()

        import backend.app.matlab.cli_runner as cli_runner

        original_run = cli_runner.subprocess.run
        cli_runner.subprocess.run = fake_run
        try:
            settings = Settings(repository_root=Path("C:/Repositories/PlatEMO"))
            runner = MatlabCliRunner(settings=settings)

            result = runner.run("job-1", PlanningConfig(), artifact_dir)
        finally:
            cli_runner.subprocess.run = original_run

        self.assertEqual(result.name, "result.json")
        self.assertTrue(calls)
        self.assertEqual(calls[0][0], "matlab")
        self.assertIn("-batch", calls[0])
        self.assertIn("run_planning_job", calls[0][-1])
        self.assertIn(artifact_dir.as_posix(), calls[0][-1])
        self.assertTrue((artifact_dir / "input.json").exists())
        self.assertEqual((artifact_dir / "stdout.log").read_text(encoding="utf-8"), "ok")


if __name__ == "__main__":
    unittest.main()
