import csv
import io
import json
import math
import random
from dataclasses import asdict
from pathlib import Path
from typing import Any
from uuid import uuid4

from backend.app.resources.store import (
    BaseStationSetRecord,
    CityModelRecord,
    PresetPathRecord,
    ResourceStore,
    ScenarioRecord,
)


CITY_ALGORITHM_KEY = "MatlabAlphaBetaGammaUniformBuildings"
BASE_STATION_ALGORITHM_KEY = "MatlabDensityKMeansBaseStations"


class ResourceValidationError(ValueError):
    pass


class ResourceNotFoundError(KeyError):
    pass


def _new_id(prefix: str) -> str:
    return f"{prefix}_{uuid4().hex}"


def _read_json(path: str | Path) -> dict[str, Any]:
    return json.loads(Path(path).read_text(encoding="utf-8"))


def _write_json(path: Path, payload: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")


def _bounds_from_buildings(buildings: list[dict[str, Any]]) -> dict[str, float]:
    if not buildings:
        return {"minX": 0, "minY": 0, "maxX": 0, "maxY": 0}
    xs: list[float] = []
    ys: list[float] = []
    for building in buildings:
        for x, y in building["footprint"]:
            xs.append(float(x))
            ys.append(float(y))
    return {"minX": min(xs), "minY": min(ys), "maxX": max(xs), "maxY": max(ys)}


def _rect_footprint(x_min: float, y_min: float, x_max: float, y_max: float) -> list[list[float]]:
    return [[x_min, y_min], [x_max, y_min], [x_max, y_max], [x_min, y_max]]


def _rect_from_footprint(footprint: list[list[float]]) -> dict[str, float]:
    xs = [float(point[0]) for point in footprint]
    ys = [float(point[1]) for point in footprint]
    return {"xMin": min(xs), "yMin": min(ys), "xMax": max(xs), "yMax": max(ys)}


class ResourceService:
    def __init__(self, store: ResourceStore, resource_root: Path) -> None:
        self.store = store
        self.resource_root = resource_root
        self.resource_root.mkdir(parents=True, exist_ok=True)

    def get_generation_algorithms(self, target_type: str | None = None) -> list[dict[str, Any]]:
        algorithms = [
            {
                "key": CITY_ALGORITHM_KEY,
                "targetType": "city_model",
                "name": "Matlab 三参数均匀建筑群生成",
                "description": "按 UAVPathPlanning 中 alpha/beta/gamma 城市建模公式生成均匀网格建筑群。",
                "parameters": [
                    {"key": "alpha", "type": "number", "required": True, "default": 0.3265},
                    {"key": "beta", "type": "number", "required": True, "default": 204.08},
                    {"key": "gamma", "type": "number", "required": True, "default": 40},
                    {"key": "seed", "type": "integer", "required": False, "default": 1},
                ],
            },
            {
                "key": BASE_STATION_ALGORITHM_KEY,
                "targetType": "base_station_set",
                "name": "Matlab 基站密度 K-means 分布生成",
                "description": "基于城市建筑物中心进行 K-means 聚类，按基站密度选择建筑物并生成基站。",
                "requires": ["cityModel"],
                "parameters": [
                    {"key": "bs_per_km2", "type": "number", "required": True, "default": 20},
                    {"key": "roof_offset_m", "type": "number", "required": False, "default": 5},
                    {"key": "seed", "type": "integer", "required": False, "default": 1},
                ],
            },
        ]
        if target_type is None:
            return algorithms
        return [algorithm for algorithm in algorithms if algorithm["targetType"] == target_type]

    def get_import_specs(self, target_type: str) -> list[dict[str, Any]]:
        specs = {
            "city_model": [
                {
                    "format": "json",
                    "title": "城市模型 JSON",
                    "requiredFields": ["bounds", "buildings[].footprint", "buildings[].height"],
                    "optionalFields": ["buildings[].id", "grid"],
                    "exampleText": json.dumps(
                        {
                            "bounds": {"minX": 0, "minY": 0, "maxX": 1000, "maxY": 1000},
                            "buildings": [
                                {
                                    "id": "b1",
                                    "footprint": [[0, 0], [20, 0], [20, 30], [0, 30]],
                                    "height": 80,
                                }
                            ],
                        },
                        ensure_ascii=False,
                    ),
                },
                {
                    "format": "csv",
                    "title": "城市模型 CSV",
                    "requiredFields": ["id", "x_min", "y_min", "x_max", "y_max", "height"],
                    "optionalFields": [],
                    "exampleText": "id,x_min,y_min,x_max,y_max,height\nb1,0,0,20,30,80\n",
                },
            ],
            "base_station_set": [
                {
                    "format": "json",
                    "title": "基站集合 JSON",
                    "requiredFields": ["baseStations[].id", "baseStations[].x", "baseStations[].y", "baseStations[].z"],
                    "optionalFields": ["powerDbm", "frequency", "coverageRadius"],
                    "exampleText": json.dumps(
                        {"baseStations": [{"id": "bs1", "x": 100, "y": 100, "z": 45, "powerDbm": 30}]},
                        ensure_ascii=False,
                    ),
                },
                {
                    "format": "csv",
                    "title": "基站集合 CSV",
                    "requiredFields": ["id", "x", "y", "z"],
                    "optionalFields": ["power_dbm", "frequency", "coverage_radius"],
                    "exampleText": "id,x,y,z,power_dbm\nbs1,100,100,45,30\n",
                },
            ],
            "preset_path": [
                {
                    "format": "json",
                    "title": "预设路径 JSON",
                    "requiredFields": ["points[].x", "points[].y", "points[].z"],
                    "optionalFields": ["points[].index"],
                    "exampleText": json.dumps({"points": [{"x": 0, "y": 0, "z": 50}, {"x": 100, "y": 0, "z": 50}]}, ensure_ascii=False),
                },
                {
                    "format": "csv",
                    "title": "预设路径 CSV",
                    "requiredFields": ["index", "x", "y", "z"],
                    "optionalFields": [],
                    "exampleText": "index,x,y,z\n0,0,0,50\n1,100,0,50\n",
                },
            ],
        }
        return specs.get(target_type, [])

    def import_city_model(
        self, *, name: str, description: str | None, source_format: str, content: str
    ) -> CityModelRecord:
        city_id = _new_id("city")
        payload = self._parse_city_content(city_id, name, source_format, content)
        return self._save_city_model(
            city_id=city_id,
            name=name,
            description=description,
            payload=payload,
            source_type="imported",
            source_format=source_format,
            source_content=content,
            generation_algorithm_key=None,
            generation_params=None,
        )

    def generate_city_model(
        self,
        *,
        name: str,
        algorithm_key: str,
        parameters: dict[str, Any],
        description: str | None = None,
    ) -> CityModelRecord:
        if algorithm_key != CITY_ALGORITHM_KEY:
            raise ResourceValidationError(f"Unsupported city generation algorithm: {algorithm_key}")
        city_id = _new_id("city")
        payload = self._generate_city_payload(city_id, name, parameters)
        return self._save_city_model(
            city_id=city_id,
            name=name,
            description=description,
            payload=payload,
            source_type="generated",
            source_format=None,
            source_content=None,
            generation_algorithm_key=algorithm_key,
            generation_params=parameters,
        )

    def _save_city_model(
        self,
        *,
        city_id: str,
        name: str,
        description: str | None,
        payload: dict[str, Any],
        source_type: str,
        source_format: str | None,
        source_content: str | None,
        generation_algorithm_key: str | None,
        generation_params: dict[str, Any] | None,
    ) -> CityModelRecord:
        model_dir = self.resource_root / "city_models" / city_id
        normalized_path = model_dir / "normalized.json"
        source_path: Path | None = None
        if source_content is not None and source_format is not None:
            source_path = model_dir / f"source.{source_format.lower()}"
            source_path.parent.mkdir(parents=True, exist_ok=True)
            source_path.write_text(source_content, encoding="utf-8")
        _write_json(normalized_path, payload)
        return self.store.create_city_model(
            id=city_id,
            name=name,
            description=description,
            source_type=source_type,
            source_format=source_format,
            source_file_path=str(source_path) if source_path else None,
            generation_algorithm_key=generation_algorithm_key,
            generation_params=generation_params,
            normalized_file_path=str(normalized_path),
            bounds=payload["bounds"],
            metadata={"buildingCount": len(payload["buildings"])},
        )

    def get_city_geometry(self, city_model_id: str) -> dict[str, Any]:
        record = self._require_city(city_model_id)
        return _read_json(record.normalized_file_path)

    def import_base_station_set(
        self,
        *,
        city_model_id: str,
        name: str,
        source_format: str,
        content: str,
    ) -> BaseStationSetRecord:
        self._require_city(city_model_id)
        set_id = _new_id("bs_set")
        payload = self._parse_base_station_content(set_id, city_model_id, name, source_format, content)
        return self._save_base_station_set(
            set_id=set_id,
            city_model_id=city_model_id,
            name=name,
            payload=payload,
            source_type="imported",
            source_format=source_format,
            source_content=content,
            generation_algorithm_key=None,
            generation_params=None,
        )

    def generate_base_station_set(
        self,
        *,
        city_model_id: str,
        name: str,
        algorithm_key: str,
        parameters: dict[str, Any],
    ) -> BaseStationSetRecord:
        if algorithm_key != BASE_STATION_ALGORITHM_KEY:
            raise ResourceValidationError(f"Unsupported base station generation algorithm: {algorithm_key}")
        city = self.get_city_geometry(city_model_id)
        set_id = _new_id("bs_set")
        payload = self._generate_base_station_payload(set_id, city_model_id, name, city, parameters)
        return self._save_base_station_set(
            set_id=set_id,
            city_model_id=city_model_id,
            name=name,
            payload=payload,
            source_type="generated",
            source_format=None,
            source_content=None,
            generation_algorithm_key=algorithm_key,
            generation_params=parameters,
        )

    def _save_base_station_set(
        self,
        *,
        set_id: str,
        city_model_id: str,
        name: str,
        payload: dict[str, Any],
        source_type: str,
        source_format: str | None,
        source_content: str | None,
        generation_algorithm_key: str | None,
        generation_params: dict[str, Any] | None,
    ) -> BaseStationSetRecord:
        set_dir = self.resource_root / "base_station_sets" / set_id
        normalized_path = set_dir / "normalized.json"
        source_path: Path | None = None
        if source_content is not None and source_format is not None:
            source_path = set_dir / f"source.{source_format.lower()}"
            source_path.parent.mkdir(parents=True, exist_ok=True)
            source_path.write_text(source_content, encoding="utf-8")
        _write_json(normalized_path, payload)
        return self.store.create_base_station_set(
            id=set_id,
            name=name,
            city_model_id=city_model_id,
            source_type=source_type,
            source_format=source_format,
            source_file_path=str(source_path) if source_path else None,
            generation_algorithm_key=generation_algorithm_key,
            generation_params=generation_params,
            normalized_file_path=str(normalized_path),
            station_count=len(payload["baseStations"]),
            metadata={"stationCount": len(payload["baseStations"])},
        )

    def get_base_station_payload(self, set_id: str) -> dict[str, Any]:
        record = self._require_base_station_set(set_id)
        return _read_json(record.normalized_file_path)

    def create_preset_path(
        self,
        *,
        city_model_id: str,
        name: str,
        points: list[dict[str, Any]],
    ) -> PresetPathRecord:
        path_id = _new_id("path")
        payload = self._make_preset_path_payload(path_id, city_model_id, name, points)
        return self._save_preset_path(
            path_id=path_id,
            city_model_id=city_model_id,
            name=name,
            payload=payload,
            source_type="manual",
            source_format=None,
            source_content=None,
        )

    def import_preset_path(
        self,
        *,
        city_model_id: str,
        name: str,
        source_format: str,
        content: str,
    ) -> PresetPathRecord:
        path_id = _new_id("path")
        points = self._parse_path_content(source_format, content)
        payload = self._make_preset_path_payload(path_id, city_model_id, name, points)
        return self._save_preset_path(
            path_id=path_id,
            city_model_id=city_model_id,
            name=name,
            payload=payload,
            source_type="imported",
            source_format=source_format,
            source_content=content,
        )

    def _save_preset_path(
        self,
        *,
        path_id: str,
        city_model_id: str,
        name: str,
        payload: dict[str, Any],
        source_type: str,
        source_format: str | None,
        source_content: str | None,
    ) -> PresetPathRecord:
        self._require_city(city_model_id)
        path_dir = self.resource_root / "preset_paths" / path_id
        normalized_path = path_dir / "normalized.json"
        source_path: Path | None = None
        if source_content is not None and source_format is not None:
            source_path = path_dir / f"source.{source_format.lower()}"
            source_path.parent.mkdir(parents=True, exist_ok=True)
            source_path.write_text(source_content, encoding="utf-8")
        _write_json(normalized_path, payload)
        return self.store.create_preset_path(
            id=path_id,
            name=name,
            city_model_id=city_model_id,
            source_type=source_type,
            source_format=source_format,
            source_file_path=str(source_path) if source_path else None,
            normalized_file_path=str(normalized_path),
            point_count=len(payload["points"]),
            metadata={"pointCount": len(payload["points"])},
        )

    def get_preset_path_payload(self, path_id: str) -> dict[str, Any]:
        record = self._require_preset_path(path_id)
        return _read_json(record.normalized_file_path)

    def create_scenario(
        self,
        *,
        name: str,
        city_model_id: str,
        base_station_set_id: str,
        preset_path_id: str,
    ) -> ScenarioRecord:
        self._validate_base_station_city(city_model_id, base_station_set_id)
        path = self._require_preset_path(preset_path_id)
        if path.city_model_id != city_model_id:
            raise ResourceValidationError("Preset path must belong to the selected city model")

        scenario_id = _new_id("scenario")
        scenario_dir = self.resource_root / "scenarios" / scenario_id
        snapshot_path = scenario_dir / "snapshot.json"
        matlab_scenario_path = scenario_dir / "matlab_scenario.json"
        snapshot = self._build_scenario_snapshot(scenario_id, name, city_model_id, base_station_set_id, preset_path_id)
        matlab_scenario = self._build_matlab_scenario(snapshot)
        _write_json(snapshot_path, snapshot)
        _write_json(matlab_scenario_path, matlab_scenario)
        return self.store.create_scenario(
            id=scenario_id,
            name=name,
            city_model_id=city_model_id,
            base_station_set_id=base_station_set_id,
            preset_path_id=preset_path_id,
            snapshot_file_path=str(snapshot_path),
            matlab_scenario_file_path=str(matlab_scenario_path),
            metadata={"cityModelName": snapshot["cityModel"]["name"]},
        )

    def get_scenario_snapshot(self, scenario_id: str) -> dict[str, Any]:
        record = self._require_scenario(scenario_id)
        return _read_json(record.snapshot_file_path)

    def _parse_city_content(
        self, city_id: str, name: str, source_format: str, content: str
    ) -> dict[str, Any]:
        fmt = source_format.lower()
        if fmt == "json":
            data = json.loads(content)
            buildings = []
            for index, item in enumerate(data.get("buildings", [])):
                footprint = item.get("footprint")
                if not footprint:
                    footprint = _rect_footprint(item["xMin"], item["yMin"], item["xMax"], item["yMax"])
                rect = _rect_from_footprint(footprint)
                buildings.append(
                    {
                        "id": str(item.get("id", f"b{index + 1}")),
                        "footprint": [[float(x), float(y)] for x, y in footprint],
                        "height": float(item["height"]),
                        **rect,
                    }
                )
            bounds = data.get("bounds") or _bounds_from_buildings(buildings)
            grid = data.get("grid") or self._infer_grid(bounds, buildings)
            return {"id": city_id, "name": name, "bounds": bounds, "grid": grid, "buildings": buildings}
        if fmt == "csv":
            rows = csv.DictReader(io.StringIO(content))
            buildings = []
            for index, row in enumerate(rows):
                x_min = float(row["x_min"])
                y_min = float(row["y_min"])
                x_max = float(row["x_max"])
                y_max = float(row["y_max"])
                buildings.append(
                    {
                        "id": row.get("id") or f"b{index + 1}",
                        "footprint": _rect_footprint(x_min, y_min, x_max, y_max),
                        "height": float(row["height"]),
                        "xMin": x_min,
                        "yMin": y_min,
                        "xMax": x_max,
                        "yMax": y_max,
                    }
                )
            bounds = _bounds_from_buildings(buildings)
            return {
                "id": city_id,
                "name": name,
                "bounds": bounds,
                "grid": self._infer_grid(bounds, buildings),
                "buildings": buildings,
            }
        raise ResourceValidationError(f"Unsupported city import format: {source_format}")

    def _generate_city_payload(self, city_id: str, name: str, parameters: dict[str, Any]) -> dict[str, Any]:
        alpha = float(parameters.get("alpha", 0.3265))
        beta = float(parameters.get("beta", 204.08))
        gamma = float(parameters.get("gamma", 40))
        seed = int(parameters.get("seed", 1))
        bounds = parameters.get("bounds") or {"minX": 0, "minY": 0, "maxX": 2000, "maxY": 2000}
        min_x = float(bounds.get("minX", 0))
        min_y = float(bounds.get("minY", 0))
        max_x = float(bounds.get("maxX", 2000))
        max_y = float(bounds.get("maxY", 2000))
        width = max_x - min_x
        height = max_y - min_y
        area_km2 = (width * height) / 1_000_000
        building_width = 1000 * math.sqrt(alpha / beta)
        street_width = max(0.0, 1000 / math.sqrt(beta) - building_width)
        spacing = building_width + street_width
        grid_x = max(1, math.ceil(width / spacing))
        grid_y = max(1, math.ceil(height / spacing))
        target_count = max(1, round(beta * area_km2))
        rng = random.Random(seed)
        buildings: list[dict[str, Any]] = []
        for x_idx in range(1, grid_x + 1):
            for y_idx in range(1, grid_y + 1):
                center_x = min_x + (x_idx - 0.5) * spacing
                center_y = min_y + (y_idx - 0.5) * spacing
                if center_x < min_x or center_x > max_x or center_y < min_y or center_y > max_y:
                    continue
                x_min = max(min_x, center_x - building_width / 2)
                y_min = max(min_y, center_y - building_width / 2)
                x_max = min(max_x, center_x + building_width / 2)
                y_max = min(max_y, center_y + building_width / 2)
                u = min(0.999999, max(0.000001, rng.random()))
                building_height = max(1.0, min(200.0, gamma * math.sqrt(-2 * math.log(1 - u))))
                buildings.append(
                    {
                        "id": f"b{len(buildings) + 1}",
                        "footprint": _rect_footprint(x_min, y_min, x_max, y_max),
                        "height": building_height,
                        "xMin": x_min,
                        "yMin": y_min,
                        "xMax": x_max,
                        "yMax": y_max,
                        "gridX": x_idx,
                        "gridY": y_idx,
                    }
                )
                if len(buildings) >= target_count:
                    break
            if len(buildings) >= target_count:
                break
        return {
            "id": city_id,
            "name": name,
            "bounds": {"minX": min_x, "minY": min_y, "maxX": max_x, "maxY": max_y},
            "grid": {
                "gridX": grid_x,
                "gridY": grid_y,
                "buildingSpacing": spacing,
                "mapOrigin": [min_x, min_y],
                "alpha": alpha,
                "beta": beta,
                "gamma": gamma,
            },
            "buildings": buildings,
        }

    def _parse_base_station_content(
        self, set_id: str, city_model_id: str, name: str, source_format: str, content: str
    ) -> dict[str, Any]:
        fmt = source_format.lower()
        if fmt == "json":
            data = json.loads(content)
            stations = data.get("baseStations", data.get("stations", []))
        elif fmt == "csv":
            stations = []
            for row in csv.DictReader(io.StringIO(content)):
                stations.append(
                    {
                        "id": row.get("id"),
                        "x": row["x"],
                        "y": row["y"],
                        "z": row.get("z", 0),
                        "powerDbm": row.get("power_dbm", row.get("powerDbm", 30)),
                    }
                )
        else:
            raise ResourceValidationError(f"Unsupported base station import format: {source_format}")
        normalized = []
        for index, station in enumerate(stations):
            normalized.append(
                {
                    "id": str(station.get("id", f"bs{index + 1}")),
                    "x": float(station["x"]),
                    "y": float(station["y"]),
                    "z": float(station.get("z", 0)),
                    "powerDbm": float(station.get("powerDbm", station.get("power_dbm", 30))),
                    "frequency": station.get("frequency"),
                    "coverageRadius": station.get("coverageRadius"),
                }
            )
        return {"id": set_id, "name": name, "cityModelId": city_model_id, "baseStations": normalized}

    def _generate_base_station_payload(
        self,
        set_id: str,
        city_model_id: str,
        name: str,
        city: dict[str, Any],
        parameters: dict[str, Any],
    ) -> dict[str, Any]:
        bs_per_km2 = float(parameters.get("bs_per_km2", parameters.get("bsPerKm2", 20)))
        seed = int(parameters.get("seed", 1))
        bounds = city["bounds"]
        area_km2 = ((bounds["maxX"] - bounds["minX"]) * (bounds["maxY"] - bounds["minY"])) / 1_000_000
        total_stations = max(1, round(bs_per_km2 * area_km2))
        building_count = max(1, min(len(city["buildings"]), math.ceil(total_stations / 2)))
        selected = self._select_buildings(city["buildings"], building_count, seed)
        roof_offset_m = float(parameters.get("roof_offset_m", parameters.get("roofOffsetM", 5)))
        stations = []
        for building in selected:
            z_value = float(building["height"]) + roof_offset_m
            for x_key, y_key in (("xMin", "yMin"), ("xMax", "yMax")):
                stations.append(
                    {
                        "id": f"bs{len(stations) + 1}",
                        "x": float(building[x_key]),
                        "y": float(building[y_key]),
                        "z": z_value,
                        "buildingId": building["id"],
                    }
                )
                if len(stations) >= total_stations:
                    break
            if len(stations) >= total_stations:
                break
        return {"id": set_id, "name": name, "cityModelId": city_model_id, "baseStations": stations}

    def _select_buildings(
        self, buildings: list[dict[str, Any]], cluster_count: int, seed: int
    ) -> list[dict[str, Any]]:
        if cluster_count >= len(buildings):
            return buildings[:]
        rng = random.Random(seed)
        centers = [
            (
                (building["xMin"] + building["xMax"]) / 2,
                (building["yMin"] + building["yMax"]) / 2,
            )
            for building in rng.sample(buildings, cluster_count)
        ]
        positions = [
            ((building["xMin"] + building["xMax"]) / 2, (building["yMin"] + building["yMax"]) / 2)
            for building in buildings
        ]
        for _ in range(30):
            groups: list[list[tuple[float, float]]] = [[] for _ in centers]
            for position in positions:
                idx = min(
                    range(len(centers)),
                    key=lambda i: (position[0] - centers[i][0]) ** 2 + (position[1] - centers[i][1]) ** 2,
                )
                groups[idx].append(position)
            next_centers = []
            for index, group in enumerate(groups):
                if group:
                    next_centers.append(
                        (sum(point[0] for point in group) / len(group), sum(point[1] for point in group) / len(group))
                    )
                else:
                    next_centers.append(centers[index])
            if next_centers == centers:
                break
            centers = next_centers
        selected: list[dict[str, Any]] = []
        used: set[int] = set()
        for center in centers:
            best_index = min(
                (idx for idx in range(len(buildings)) if idx not in used),
                key=lambda idx: (
                    (positions[idx][0] - center[0]) ** 2
                    + (positions[idx][1] - center[1]) ** 2
                    - float(buildings[idx]["height"]) * 0.01
                ),
            )
            used.add(best_index)
            selected.append(buildings[best_index])
        return selected

    def _make_preset_path_payload(
        self,
        path_id: str,
        city_model_id: str,
        name: str,
        points: list[dict[str, Any]],
    ) -> dict[str, Any]:
        self._require_city(city_model_id)
        if len(points) < 2:
            raise ResourceValidationError("Preset path requires at least two points")
        normalized_points = [
            {"index": index, "x": float(point["x"]), "y": float(point["y"]), "z": float(point.get("z", 50))}
            for index, point in enumerate(points)
        ]
        return {
            "id": path_id,
            "name": name,
            "cityModelId": city_model_id,
            "points": normalized_points,
        }

    def _parse_path_content(self, source_format: str, content: str) -> list[dict[str, Any]]:
        fmt = source_format.lower()
        if fmt == "json":
            data = json.loads(content)
            return data.get("points", data)
        if fmt == "csv":
            rows = list(csv.DictReader(io.StringIO(content)))
            rows.sort(key=lambda row: int(row.get("index", len(rows))))
            return [{"x": row["x"], "y": row["y"], "z": row.get("z", 50)} for row in rows]
        raise ResourceValidationError(f"Unsupported preset path import format: {source_format}")

    def _build_scenario_snapshot(
        self,
        scenario_id: str,
        name: str,
        city_model_id: str,
        base_station_set_id: str,
        preset_path_id: str,
    ) -> dict[str, Any]:
        city_record = self._require_city(city_model_id)
        station_record = self._require_base_station_set(base_station_set_id)
        path_record = self._require_preset_path(preset_path_id)
        return {
            "id": scenario_id,
            "name": name,
            "cityModel": {
                **self.get_city_geometry(city_model_id),
                "record": asdict(city_record),
            },
            "baseStationSet": {
                **self.get_base_station_payload(base_station_set_id),
                "record": asdict(station_record),
            },
            "presetPath": {
                **self.get_preset_path_payload(preset_path_id),
                "record": asdict(path_record),
            },
        }

    def _build_matlab_scenario(self, snapshot: dict[str, Any]) -> dict[str, Any]:
        city = snapshot["cityModel"]
        stations = snapshot["baseStationSet"]["baseStations"]
        path = snapshot["presetPath"]["points"]
        obstacles = []
        for building in city["buildings"]:
            rect = _rect_from_footprint(building["footprint"])
            obstacles.append(
                {
                    "id": building["id"],
                    **rect,
                    "height": float(building["height"]),
                    "gridX": building.get("gridX"),
                    "gridY": building.get("gridY"),
                }
            )
        return {
            "presetPath": [[point["x"], point["y"], point["z"]] for point in path],
            "baseStations": [[station["x"], station["y"], station["z"]] for station in stations],
            "obstacles": obstacles,
            "bounds": city["bounds"],
            "grid": city.get("grid", {}),
        }

    def _infer_grid(self, bounds: dict[str, Any], buildings: list[dict[str, Any]]) -> dict[str, Any]:
        count = max(1, len(buildings))
        grid_x = max(1, math.ceil(math.sqrt(count)))
        grid_y = max(1, math.ceil(count / grid_x))
        width = float(bounds["maxX"]) - float(bounds["minX"])
        height = float(bounds["maxY"]) - float(bounds["minY"])
        spacing = max(width / grid_x if grid_x else width, height / grid_y if grid_y else height, 1.0)
        for index, building in enumerate(buildings):
            building.setdefault("gridX", index // grid_y + 1)
            building.setdefault("gridY", index % grid_y + 1)
        return {
            "gridX": grid_x,
            "gridY": grid_y,
            "buildingSpacing": spacing,
            "mapOrigin": [float(bounds["minX"]), float(bounds["minY"])],
        }

    def _require_city(self, city_model_id: str) -> CityModelRecord:
        record = self.store.get_city_model(city_model_id)
        if record is None:
            raise ResourceNotFoundError(f"Unknown city model: {city_model_id}")
        return record

    def _require_base_station_set(self, set_id: str) -> BaseStationSetRecord:
        record = self.store.get_base_station_set(set_id)
        if record is None:
            raise ResourceNotFoundError(f"Unknown base station set: {set_id}")
        return record

    def _require_preset_path(self, path_id: str) -> PresetPathRecord:
        record = self.store.get_preset_path(path_id)
        if record is None:
            raise ResourceNotFoundError(f"Unknown preset path: {path_id}")
        return record

    def _require_scenario(self, scenario_id: str) -> ScenarioRecord:
        record = self.store.get_scenario(scenario_id)
        if record is None:
            raise ResourceNotFoundError(f"Unknown scenario: {scenario_id}")
        return record

    def _validate_base_station_city(self, city_model_id: str, base_station_set_id: str) -> None:
        self._require_city(city_model_id)
        stations = self._require_base_station_set(base_station_set_id)
        if stations.city_model_id != city_model_id:
            raise ResourceValidationError("Base station set must belong to the selected city model")
