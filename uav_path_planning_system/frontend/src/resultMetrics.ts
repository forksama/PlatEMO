import type { ObjectivePoint } from "./api/client";

export interface SelectedObjectiveMetrics {
  solutionIndex: number | null;
  signalDbm: number | null;
  switchCount: number | null;
  coverageRatio: number | null;
  hypervolume: number | null;
  totalHypervolume: number | null;
}

type ObjectiveVector = [number, number, number];

const HV_REFERENCE: ObjectiveVector = [1.1, 1.1, 1.1];

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
      coverageRatio: null,
      hypervolume: null,
      totalHypervolume: objectives.length ? calculateHypervolume(normalizeObjectives(objectives), HV_REFERENCE) : null
    };
  }

  const normalized = normalizeObjectives(objectives);
  const selectedIndex = objectives.findIndex((objective) => objective.solutionIndex === selected.solutionIndex);
  const totalHypervolume = calculateHypervolume(normalized, HV_REFERENCE);
  const withoutSelected = normalized.filter((_, index) => index !== selectedIndex);
  const selectedContribution = Math.max(0, totalHypervolume - calculateHypervolume(withoutSelected, HV_REFERENCE));

  return {
    solutionIndex: selected.solutionIndex,
    signalDbm: -selected.negativeSignal,
    switchCount: selected.switchCount,
    coverageRatio: -selected.negativeCoverage,
    hypervolume: selectedContribution,
    totalHypervolume
  };
}

export function calculateHypervolume(points: ObjectiveVector[], reference: ObjectiveVector = HV_REFERENCE): number {
  const validPoints = points
    .map((point) => point.map((value, index) => Math.min(Math.max(value, 0), reference[index])) as ObjectiveVector)
    .filter((point) => point.every((value, index) => value < reference[index]));
  return hypervolumeRecursive(validPoints, reference);
}

function normalizeObjectives(objectives: ObjectivePoint[]): ObjectiveVector[] {
  const vectors = objectives.map(toObjectiveVector);
  const mins = minByDimension(vectors);
  const maxes = maxByDimension(vectors);
  return vectors.map((vector) =>
    vector.map((value, index) => {
      const range = maxes[index] - mins[index];
      return range === 0 ? 0 : (value - mins[index]) / range;
    }) as ObjectiveVector
  );
}

function toObjectiveVector(objective: ObjectivePoint): ObjectiveVector {
  return [objective.negativeSignal, objective.switchCount, objective.negativeCoverage];
}

function minByDimension(vectors: ObjectiveVector[]): ObjectiveVector {
  return [0, 1, 2].map((index) => Math.min(...vectors.map((vector) => vector[index]))) as ObjectiveVector;
}

function maxByDimension(vectors: ObjectiveVector[]): ObjectiveVector {
  return [0, 1, 2].map((index) => Math.max(...vectors.map((vector) => vector[index]))) as ObjectiveVector;
}

function hypervolumeRecursive(points: number[][], reference: number[]): number {
  if (!points.length) {
    return 0;
  }
  if (reference.length === 1) {
    return Math.max(0, reference[0] - Math.min(...points.map((point) => point[0])));
  }

  const coordinates = Array.from(new Set(points.map((point) => point[0]).filter((value) => value < reference[0]))).sort(
    (left, right) => left - right
  );
  const limits = [...coordinates, reference[0]];
  let volume = 0;
  for (let index = 0; index < coordinates.length; index += 1) {
    const start = limits[index];
    const end = limits[index + 1];
    const width = end - start;
    if (width <= 0) {
      continue;
    }
    const active = points.filter((point) => point[0] <= start).map((point) => point.slice(1));
    volume += width * hypervolumeRecursive(active, reference.slice(1));
  }
  return volume;
}
