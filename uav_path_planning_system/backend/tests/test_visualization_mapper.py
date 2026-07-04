import unittest

from backend.app.visualization.mapper import build_plot_payload, normalize_result_payload


class VisualizationMapperTests(unittest.TestCase):
    def test_build_plot_payload_converts_objective_signs(self) -> None:
        result = {
            "objectives": [
                {
                    "solutionIndex": 0,
                    "negativeSignal": 80.0,
                    "switchCount": 4,
                    "negativeCoverage": -0.9,
                }
            ],
            "solutions": [
                {
                    "solutionIndex": 0,
                    "waypoints": [[0, 0, 50], [10, 0, 50]],
                    "switchPoints": [],
                    "servingBaseStations": [1, 1],
                }
            ],
            "scenario": {"presetPath": [], "baseStations": [], "obstacles": []},
        }

        payload = build_plot_payload(result)

        self.assertEqual(payload["pareto"][0]["signalDbm"], -80.0)
        self.assertEqual(payload["pareto"][0]["coverageRatio"], 0.9)
        self.assertEqual(payload["paths"][0]["segments"][0]["from"], [0, 0, 50])
        self.assertEqual(payload["paths"][0]["segments"][0]["servingBaseStation"], 1)

    def test_normalize_result_payload_keeps_single_matlab_solution_as_list(self) -> None:
        result = {
            "objectives": {
                "solutionIndex": 0,
                "negativeSignal": 80.0,
                "switchCount": 4,
                "negativeCoverage": -0.9,
            },
            "solutions": {
                "solutionIndex": 0,
                "waypoints": [[0, 0, 50]],
                "switchPoints": {"waypointIndex": 0},
            },
            "scenario": {"obstacles": {"xMin": 0, "yMin": 0, "xMax": 1, "yMax": 1, "height": 10}},
        }

        normalized = normalize_result_payload(result)

        self.assertIsInstance(normalized["objectives"], list)
        self.assertIsInstance(normalized["solutions"], list)
        self.assertIsInstance(normalized["solutions"][0]["switchPoints"], list)
        self.assertIsInstance(normalized["scenario"]["obstacles"], list)


if __name__ == "__main__":
    unittest.main()
