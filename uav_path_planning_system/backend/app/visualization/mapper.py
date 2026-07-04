from typing import Any


def ensure_list(value: Any) -> list[Any]:
    if value is None:
        return []
    if isinstance(value, list):
        return value
    return [value]


def normalize_result_payload(result: dict[str, Any]) -> dict[str, Any]:
    normalized = dict(result)
    normalized["objectives"] = ensure_list(normalized.get("objectives"))
    normalized["solutions"] = [normalize_solution(solution) for solution in ensure_list(normalized.get("solutions"))]

    scenario = dict(normalized.get("scenario") or {})
    scenario["obstacles"] = ensure_list(scenario.get("obstacles"))
    normalized["scenario"] = scenario
    return normalized


def normalize_solution(solution: Any) -> dict[str, Any]:
    if not isinstance(solution, dict):
        return {}

    normalized = dict(solution)
    if "switchPoints" in normalized:
        normalized["switchPoints"] = ensure_list(normalized.get("switchPoints"))
    if "switch_points" in normalized:
        normalized["switch_points"] = ensure_list(normalized.get("switch_points"))
    return normalized


def build_plot_payload(result: dict[str, Any]) -> dict[str, Any]:
    result = normalize_result_payload(result)
    pareto = []
    for point in result.get("objectives", []):
        pareto.append(
            {
                "solutionIndex": point["solutionIndex"],
                "signalDbm": -point["negativeSignal"],
                "switchCount": point["switchCount"],
                "coverageRatio": -point["negativeCoverage"],
            }
        )

    paths = []
    for solution in result.get("solutions", []):
        waypoints = solution.get("waypoints", [])
        serving_base_stations = solution.get("servingBaseStations", [])
        segments = []
        for index in range(max(0, len(waypoints) - 1)):
            station = serving_base_stations[index] if index < len(serving_base_stations) else None
            segments.append(
                {
                    "from": waypoints[index],
                    "to": waypoints[index + 1],
                    "servingBaseStation": station,
                }
            )
        paths.append(
            {
                "solutionIndex": solution["solutionIndex"],
                "waypoints": waypoints,
                "segments": segments,
                "switchPoints": solution.get("switchPoints", []),
            }
        )

    return {
        "pareto": pareto,
        "paths": paths,
        "scenario": result.get("scenario", {}),
    }
