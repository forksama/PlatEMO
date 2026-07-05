import json
import sqlite3
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


def _utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


@dataclass(frozen=True)
class CityModelRecord:
    id: str
    name: str
    description: str | None
    source_type: str
    source_format: str | None
    source_file_path: str | None
    generation_algorithm_key: str | None
    generation_params_json: str | None
    normalized_file_path: str
    bounds_json: str
    metadata_json: str
    created_at: str
    updated_at: str


@dataclass(frozen=True)
class BaseStationSetRecord:
    id: str
    name: str
    city_model_id: str
    source_type: str
    source_format: str | None
    source_file_path: str | None
    generation_algorithm_key: str | None
    generation_params_json: str | None
    normalized_file_path: str
    station_count: int
    metadata_json: str
    created_at: str
    updated_at: str


@dataclass(frozen=True)
class PresetPathRecord:
    id: str
    name: str
    city_model_id: str
    source_type: str
    source_format: str | None
    source_file_path: str | None
    normalized_file_path: str
    point_count: int
    metadata_json: str
    created_at: str
    updated_at: str


@dataclass(frozen=True)
class ScenarioRecord:
    id: str
    name: str
    city_model_id: str
    base_station_set_id: str
    preset_path_id: str
    snapshot_file_path: str
    matlab_scenario_file_path: str
    metadata_json: str
    created_at: str
    updated_at: str


class ResourceStore:
    def __init__(self, database_path: Path) -> None:
        self.database_path = database_path
        self.database_path.parent.mkdir(parents=True, exist_ok=True)
        self._ensure_schema()

    def _connect(self) -> sqlite3.Connection:
        return sqlite3.connect(self.database_path)

    def _ensure_schema(self) -> None:
        with self._connect() as conn:
            conn.execute(
                """
                CREATE TABLE IF NOT EXISTS city_models (
                    id TEXT PRIMARY KEY,
                    name TEXT NOT NULL,
                    description TEXT,
                    source_type TEXT NOT NULL,
                    source_format TEXT,
                    source_file_path TEXT,
                    generation_algorithm_key TEXT,
                    generation_params_json TEXT,
                    normalized_file_path TEXT NOT NULL,
                    bounds_json TEXT NOT NULL,
                    metadata_json TEXT NOT NULL,
                    created_at TEXT NOT NULL,
                    updated_at TEXT NOT NULL
                )
                """
            )
            conn.execute(
                """
                CREATE TABLE IF NOT EXISTS base_station_sets (
                    id TEXT PRIMARY KEY,
                    name TEXT NOT NULL,
                    city_model_id TEXT NOT NULL,
                    source_type TEXT NOT NULL,
                    source_format TEXT,
                    source_file_path TEXT,
                    generation_algorithm_key TEXT,
                    generation_params_json TEXT,
                    normalized_file_path TEXT NOT NULL,
                    station_count INTEGER NOT NULL,
                    metadata_json TEXT NOT NULL,
                    created_at TEXT NOT NULL,
                    updated_at TEXT NOT NULL
                )
                """
            )
            conn.execute(
                """
                CREATE TABLE IF NOT EXISTS preset_paths (
                    id TEXT PRIMARY KEY,
                    name TEXT NOT NULL,
                    city_model_id TEXT NOT NULL,
                    source_type TEXT NOT NULL,
                    source_format TEXT,
                    source_file_path TEXT,
                    normalized_file_path TEXT NOT NULL,
                    point_count INTEGER NOT NULL,
                    metadata_json TEXT NOT NULL,
                    created_at TEXT NOT NULL,
                    updated_at TEXT NOT NULL
                )
                """
            )
            self._migrate_preset_paths_schema(conn)
            conn.execute(
                """
                CREATE TABLE IF NOT EXISTS scenarios (
                    id TEXT PRIMARY KEY,
                    name TEXT NOT NULL,
                    city_model_id TEXT NOT NULL,
                    base_station_set_id TEXT NOT NULL,
                    preset_path_id TEXT NOT NULL,
                    snapshot_file_path TEXT NOT NULL,
                    matlab_scenario_file_path TEXT NOT NULL,
                    metadata_json TEXT NOT NULL,
                    created_at TEXT NOT NULL,
                    updated_at TEXT NOT NULL
                )
                """
            )

    def _migrate_preset_paths_schema(self, conn: sqlite3.Connection) -> None:
        columns = [row[1] for row in conn.execute("PRAGMA table_info(preset_paths)").fetchall()]
        if "base_station_set_id" not in columns:
            return
        conn.execute("ALTER TABLE preset_paths RENAME TO preset_paths_old")
        conn.execute(
            """
            CREATE TABLE preset_paths (
                id TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                city_model_id TEXT NOT NULL,
                source_type TEXT NOT NULL,
                source_format TEXT,
                source_file_path TEXT,
                normalized_file_path TEXT NOT NULL,
                point_count INTEGER NOT NULL,
                metadata_json TEXT NOT NULL,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL
            )
            """
        )
        columns_sql = """
            id, name, city_model_id, source_type, source_format, source_file_path,
            normalized_file_path, point_count, metadata_json, created_at, updated_at
        """
        conn.execute(
            f"""
            INSERT INTO preset_paths({columns_sql})
            SELECT {columns_sql}
            FROM preset_paths_old
            """
        )
        conn.execute("DROP TABLE preset_paths_old")

    def create_city_model(
        self,
        *,
        id: str,
        name: str,
        description: str | None,
        source_type: str,
        source_format: str | None,
        source_file_path: str | None,
        generation_algorithm_key: str | None,
        generation_params: dict[str, Any] | None,
        normalized_file_path: str,
        bounds: dict[str, Any],
        metadata: dict[str, Any] | None = None,
    ) -> CityModelRecord:
        now = _utc_now()
        record = CityModelRecord(
            id=id,
            name=name,
            description=description,
            source_type=source_type,
            source_format=source_format,
            source_file_path=source_file_path,
            generation_algorithm_key=generation_algorithm_key,
            generation_params_json=json.dumps(generation_params, ensure_ascii=False)
            if generation_params is not None
            else None,
            normalized_file_path=normalized_file_path,
            bounds_json=json.dumps(bounds, ensure_ascii=False),
            metadata_json=json.dumps(metadata or {}, ensure_ascii=False),
            created_at=now,
            updated_at=now,
        )
        with self._connect() as conn:
            conn.execute(
                """
                INSERT INTO city_models(
                    id, name, description, source_type, source_format, source_file_path,
                    generation_algorithm_key, generation_params_json, normalized_file_path,
                    bounds_json, metadata_json, created_at, updated_at
                )
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    record.id,
                    record.name,
                    record.description,
                    record.source_type,
                    record.source_format,
                    record.source_file_path,
                    record.generation_algorithm_key,
                    record.generation_params_json,
                    record.normalized_file_path,
                    record.bounds_json,
                    record.metadata_json,
                    record.created_at,
                    record.updated_at,
                ),
            )
        return record

    def get_city_model(self, id: str) -> CityModelRecord | None:
        with self._connect() as conn:
            row = conn.execute(
                """
                SELECT id, name, description, source_type, source_format, source_file_path,
                       generation_algorithm_key, generation_params_json, normalized_file_path,
                       bounds_json, metadata_json, created_at, updated_at
                FROM city_models WHERE id = ?
                """,
                (id,),
            ).fetchone()
        return CityModelRecord(*row) if row else None

    def list_city_models(self) -> list[CityModelRecord]:
        with self._connect() as conn:
            rows = conn.execute(
                """
                SELECT id, name, description, source_type, source_format, source_file_path,
                       generation_algorithm_key, generation_params_json, normalized_file_path,
                       bounds_json, metadata_json, created_at, updated_at
                FROM city_models ORDER BY created_at DESC
                """
            ).fetchall()
        return [CityModelRecord(*row) for row in rows]

    def create_base_station_set(
        self,
        *,
        id: str,
        name: str,
        city_model_id: str,
        source_type: str,
        source_format: str | None,
        source_file_path: str | None,
        generation_algorithm_key: str | None,
        generation_params: dict[str, Any] | None,
        normalized_file_path: str,
        station_count: int,
        metadata: dict[str, Any] | None = None,
    ) -> BaseStationSetRecord:
        now = _utc_now()
        record = BaseStationSetRecord(
            id=id,
            name=name,
            city_model_id=city_model_id,
            source_type=source_type,
            source_format=source_format,
            source_file_path=source_file_path,
            generation_algorithm_key=generation_algorithm_key,
            generation_params_json=json.dumps(generation_params, ensure_ascii=False)
            if generation_params is not None
            else None,
            normalized_file_path=normalized_file_path,
            station_count=station_count,
            metadata_json=json.dumps(metadata or {}, ensure_ascii=False),
            created_at=now,
            updated_at=now,
        )
        with self._connect() as conn:
            conn.execute(
                """
                INSERT INTO base_station_sets(
                    id, name, city_model_id, source_type, source_format, source_file_path,
                    generation_algorithm_key, generation_params_json, normalized_file_path,
                    station_count, metadata_json, created_at, updated_at
                )
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    record.id,
                    record.name,
                    record.city_model_id,
                    record.source_type,
                    record.source_format,
                    record.source_file_path,
                    record.generation_algorithm_key,
                    record.generation_params_json,
                    record.normalized_file_path,
                    record.station_count,
                    record.metadata_json,
                    record.created_at,
                    record.updated_at,
                ),
            )
        return record

    def get_base_station_set(self, id: str) -> BaseStationSetRecord | None:
        with self._connect() as conn:
            row = conn.execute(
                """
                SELECT id, name, city_model_id, source_type, source_format, source_file_path,
                       generation_algorithm_key, generation_params_json, normalized_file_path,
                       station_count, metadata_json, created_at, updated_at
                FROM base_station_sets WHERE id = ?
                """,
                (id,),
            ).fetchone()
        return BaseStationSetRecord(*row) if row else None

    def list_base_station_sets(self, city_model_id: str | None = None) -> list[BaseStationSetRecord]:
        with self._connect() as conn:
            if city_model_id:
                rows = conn.execute(
                    """
                    SELECT id, name, city_model_id, source_type, source_format, source_file_path,
                           generation_algorithm_key, generation_params_json, normalized_file_path,
                           station_count, metadata_json, created_at, updated_at
                    FROM base_station_sets WHERE city_model_id = ? ORDER BY created_at DESC
                    """,
                    (city_model_id,),
                ).fetchall()
            else:
                rows = conn.execute(
                    """
                    SELECT id, name, city_model_id, source_type, source_format, source_file_path,
                           generation_algorithm_key, generation_params_json, normalized_file_path,
                           station_count, metadata_json, created_at, updated_at
                    FROM base_station_sets ORDER BY created_at DESC
                    """
                ).fetchall()
        return [BaseStationSetRecord(*row) for row in rows]

    def create_preset_path(
        self,
        *,
        id: str,
        name: str,
        city_model_id: str,
        source_type: str,
        source_format: str | None,
        source_file_path: str | None,
        normalized_file_path: str,
        point_count: int,
        metadata: dict[str, Any] | None = None,
    ) -> PresetPathRecord:
        now = _utc_now()
        record = PresetPathRecord(
            id=id,
            name=name,
            city_model_id=city_model_id,
            source_type=source_type,
            source_format=source_format,
            source_file_path=source_file_path,
            normalized_file_path=normalized_file_path,
            point_count=point_count,
            metadata_json=json.dumps(metadata or {}, ensure_ascii=False),
            created_at=now,
            updated_at=now,
        )
        with self._connect() as conn:
            conn.execute(
                """
                INSERT INTO preset_paths(
                    id, name, city_model_id, source_type, source_format, source_file_path,
                    normalized_file_path, point_count, metadata_json,
                    created_at, updated_at
                )
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    record.id,
                    record.name,
                    record.city_model_id,
                    record.source_type,
                    record.source_format,
                    record.source_file_path,
                    record.normalized_file_path,
                    record.point_count,
                    record.metadata_json,
                    record.created_at,
                    record.updated_at,
                ),
            )
        return record

    def get_preset_path(self, id: str) -> PresetPathRecord | None:
        with self._connect() as conn:
            row = conn.execute(
                """
                SELECT id, name, city_model_id, source_type, source_format, source_file_path,
                       normalized_file_path, point_count, metadata_json,
                       created_at, updated_at
                FROM preset_paths WHERE id = ?
                """,
                (id,),
            ).fetchone()
        return PresetPathRecord(*row) if row else None

    def list_preset_paths(self) -> list[PresetPathRecord]:
        with self._connect() as conn:
            rows = conn.execute(
                """
                SELECT id, name, city_model_id, source_type, source_format, source_file_path,
                       normalized_file_path, point_count, metadata_json,
                       created_at, updated_at
                FROM preset_paths ORDER BY created_at DESC
                """
            ).fetchall()
        return [PresetPathRecord(*row) for row in rows]

    def create_scenario(
        self,
        *,
        id: str,
        name: str,
        city_model_id: str,
        base_station_set_id: str,
        preset_path_id: str,
        snapshot_file_path: str,
        matlab_scenario_file_path: str,
        metadata: dict[str, Any] | None = None,
    ) -> ScenarioRecord:
        now = _utc_now()
        record = ScenarioRecord(
            id=id,
            name=name,
            city_model_id=city_model_id,
            base_station_set_id=base_station_set_id,
            preset_path_id=preset_path_id,
            snapshot_file_path=snapshot_file_path,
            matlab_scenario_file_path=matlab_scenario_file_path,
            metadata_json=json.dumps(metadata or {}, ensure_ascii=False),
            created_at=now,
            updated_at=now,
        )
        with self._connect() as conn:
            conn.execute(
                """
                INSERT INTO scenarios(
                    id, name, city_model_id, base_station_set_id, preset_path_id,
                    snapshot_file_path, matlab_scenario_file_path, metadata_json,
                    created_at, updated_at
                )
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    record.id,
                    record.name,
                    record.city_model_id,
                    record.base_station_set_id,
                    record.preset_path_id,
                    record.snapshot_file_path,
                    record.matlab_scenario_file_path,
                    record.metadata_json,
                    record.created_at,
                    record.updated_at,
                ),
            )
        return record

    def get_scenario(self, id: str) -> ScenarioRecord | None:
        with self._connect() as conn:
            row = conn.execute(
                """
                SELECT id, name, city_model_id, base_station_set_id, preset_path_id,
                       snapshot_file_path, matlab_scenario_file_path, metadata_json,
                       created_at, updated_at
                FROM scenarios WHERE id = ?
                """,
                (id,),
            ).fetchone()
        return ScenarioRecord(*row) if row else None

    def list_scenarios(self) -> list[ScenarioRecord]:
        with self._connect() as conn:
            rows = conn.execute(
                """
                SELECT id, name, city_model_id, base_station_set_id, preset_path_id,
                       snapshot_file_path, matlab_scenario_file_path, metadata_json,
                       created_at, updated_at
                FROM scenarios ORDER BY created_at DESC
                """
            ).fetchall()
        return [ScenarioRecord(*row) for row in rows]
