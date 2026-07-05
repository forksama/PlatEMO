import type { ObjectivePoint } from "./api/client";

export interface SelectedObjectiveMetrics {
  solutionIndex: number | null;
  signalDbm: number | null;
  switchCount: number | null;
  coverageRatio: number | null;
}

export function getSelectedObjectiveMetrics(
  objectives: ObjectivePoint[],
  selectedSolution: number
): SelectedObjectiveMetrics {
  const selected = objectives.find((objective) => objective.solutionIndex === selectedSolution) ?? null;
  if (!selected) {
    return {
      solutionIndex: null,
      signalDbm: null,
      switchCount: null,
      coverageRatio: null
    };
  }

  return {
    solutionIndex: selected.solutionIndex,
    signalDbm: -selected.negativeSignal,
    switchCount: selected.switchCount,
    coverageRatio: -selected.negativeCoverage
  };
}
