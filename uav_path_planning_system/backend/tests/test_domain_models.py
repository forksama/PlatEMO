import unittest

from pydantic import ValidationError

from backend.app.domain.models import (
    AlgorithmConfig,
    JobStatus,
    PlanningConfig,
    ProblemConfig,
)


class DomainModelTests(unittest.TestCase):
    def test_planning_config_defaults_match_patent_experiment_baseline(self) -> None:
        config = PlanningConfig(problem=ProblemConfig(), algorithm=AlgorithmConfig())

        self.assertEqual(config.problem.bs_per_km2, 20)
        self.assertEqual(config.problem.velocity, 20)
        self.assertEqual(config.problem.ttt_seconds, 5)
        self.assertEqual(config.problem.switch_threshold_dbm, -101.5)
        self.assertEqual(config.problem.switch_method, 2)
        self.assertEqual(config.problem.lookahead_distance_m, 500)
        self.assertEqual(config.algorithm.num_segments, 5)
        self.assertEqual(config.algorithm.segment_overlap, 2)
        self.assertIs(config.algorithm.use_ek, True)

    def test_job_status_values_are_stable_for_frontend(self) -> None:
        self.assertEqual(
            [status.value for status in JobStatus],
            ["queued", "preparing", "running", "exporting", "succeeded", "failed", "cancelled"],
        )

    def test_rejects_invalid_switch_method(self) -> None:
        with self.assertRaises(ValidationError):
            ProblemConfig(switch_method=9)


if __name__ == "__main__":
    unittest.main()
