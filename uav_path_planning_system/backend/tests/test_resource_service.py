from pathlib import Path
import json
import tempfile
import unittest

from backend.app.resources.service import ResourceService
from backend.app.resources.store import ResourceStore


class ResourceServiceTests(unittest.TestCase):
    def make_service(self, tmp_dir: str) -> ResourceService:
        runtime_root = Path(tmp_dir)
        return ResourceService(
            store=ResourceStore(runtime_root / "uav.sqlite3"),
            resource_root=runtime_root / "resources",
        )

    def test_import_city_model_normalizes_geometry_and_records_format(self) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            service = self.make_service(tmp_dir)

            city = service.import_city_model(
                name="demo city",
                description="rectangular blocks",
                source_format="json",
                content=json.dumps(
                    {
                        "bounds": {"minX": 0, "minY": 0, "maxX": 100, "maxY": 100},
                        "buildings": [
                            {
                                "id": "b1",
                                "footprint": [[0, 0], [10, 0], [10, 20], [0, 20]],
                                "height": 30,
                            }
                        ],
                    }
                ),
            )

            geometry = service.get_city_geometry(city.id)
            self.assertEqual(city.source_type, "imported")
            self.assertEqual(city.source_format, "json")
            self.assertEqual(geometry["buildings"][0]["id"], "b1")
            self.assertEqual(geometry["buildings"][0]["height"], 30)
            self.assertTrue(Path(city.normalized_file_path).exists())

    def test_generate_city_model_uses_registered_three_parameter_algorithm(self) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            service = self.make_service(tmp_dir)

            city = service.generate_city_model(
                name="generated",
                algorithm_key="MatlabAlphaBetaGammaUniformBuildings",
                parameters={
                    "alpha": 0.25,
                    "beta": 8,
                    "gamma": 30,
                    "bounds": {"minX": 0, "minY": 0, "maxX": 1000, "maxY": 1000},
                    "seed": 3,
                },
            )

            geometry = service.get_city_geometry(city.id)
            self.assertEqual(city.source_type, "generated")
            self.assertEqual(city.generation_algorithm_key, "MatlabAlphaBetaGammaUniformBuildings")
            self.assertGreater(len(geometry["buildings"]), 0)
            self.assertEqual(geometry["bounds"]["maxX"], 1000)

    def test_base_station_generation_places_stations_on_building_roofs(self) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            service = self.make_service(tmp_dir)
            city = service.import_city_model(
                name="city",
                description=None,
                source_format="json",
                content=json.dumps(
                    {
                        "bounds": {"minX": 0, "minY": 0, "maxX": 1000, "maxY": 1000},
                        "buildings": [
                            {
                                "id": "b1",
                                "footprint": [[10, 20], [40, 20], [40, 60], [10, 60]],
                                "height": 80,
                            }
                        ],
                    }
                ),
            )

            stations = service.generate_base_station_set(
                city_model_id=city.id,
                name="stations",
                algorithm_key="MatlabDensityKMeansBaseStations",
                parameters={"bs_per_km2": 2, "height": 45, "roof_offset_m": 7, "seed": 2},
            )

            payload = service.get_base_station_payload(stations.id)
            self.assertEqual(stations.city_model_id, city.id)
            self.assertEqual(stations.generation_algorithm_key, "MatlabDensityKMeansBaseStations")
            self.assertEqual(len(payload["baseStations"]), 2)
            self.assertEqual({station["z"] for station in payload["baseStations"]}, {87.0})
            self.assertEqual(
                {(station["x"], station["y"]) for station in payload["baseStations"]},
                {(10.0, 20.0), (40.0, 60.0)},
            )
            self.assertNotIn("powerDbm", payload["baseStations"][0])

    def test_base_station_generation_algorithm_exposes_roof_offset_not_absolute_height(self) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            service = self.make_service(tmp_dir)

            algorithm = service.get_generation_algorithms("base_station_set")[0]

            parameter_keys = {parameter["key"] for parameter in algorithm["parameters"]}
            self.assertIn("roof_offset_m", parameter_keys)
            self.assertNotIn("height", parameter_keys)
            self.assertNotIn("powerDbm", parameter_keys)

    def test_preset_path_and_scenario_snapshot_keep_resource_dependencies(self) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            service = self.make_service(tmp_dir)
            city = service.generate_city_model(
                name="city",
                algorithm_key="MatlabAlphaBetaGammaUniformBuildings",
                parameters={"alpha": 0.25, "beta": 8, "gamma": 30, "seed": 1},
            )
            stations = service.generate_base_station_set(
                city_model_id=city.id,
                name="stations",
                algorithm_key="MatlabDensityKMeansBaseStations",
                parameters={"bs_per_km2": 4, "seed": 2},
            )

            path = service.create_preset_path(
                city_model_id=city.id,
                name="route",
                points=[{"x": 0, "y": 0, "z": 50}, {"x": 100, "y": 100, "z": 50}],
            )
            scenario = service.create_scenario(
                name="scenario",
                city_model_id=city.id,
                base_station_set_id=stations.id,
                preset_path_id=path.id,
            )

            snapshot = service.get_scenario_snapshot(scenario.id)
            matlab = json.loads(Path(scenario.matlab_scenario_file_path).read_text(encoding="utf-8"))
            self.assertEqual(snapshot["cityModel"]["id"], city.id)
            self.assertEqual(snapshot["baseStationSet"]["cityModelId"], city.id)
            self.assertEqual(snapshot["presetPath"]["cityModelId"], city.id)
            self.assertNotIn("baseStationSetId", snapshot["presetPath"])
            self.assertEqual(matlab["presetPath"][0], [0, 0, 50])
            self.assertIn("baseStations", matlab)
            self.assertIn("obstacles", matlab)

    def test_scenario_requires_path_and_base_stations_to_belong_to_selected_city(self) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            service = self.make_service(tmp_dir)
            city_a = service.generate_city_model(
                name="city a",
                algorithm_key="MatlabAlphaBetaGammaUniformBuildings",
                parameters={"alpha": 0.25, "beta": 8, "gamma": 30, "seed": 1},
            )
            city_b = service.generate_city_model(
                name="city b",
                algorithm_key="MatlabAlphaBetaGammaUniformBuildings",
                parameters={"alpha": 0.25, "beta": 8, "gamma": 30, "seed": 2},
            )
            stations = service.generate_base_station_set(
                city_model_id=city_a.id,
                name="stations",
                algorithm_key="MatlabDensityKMeansBaseStations",
                parameters={"bs_per_km2": 4, "seed": 2},
            )
            path = service.create_preset_path(
                city_model_id=city_b.id,
                name="route",
                points=[{"x": 0, "y": 0, "z": 50}, {"x": 100, "y": 100, "z": 50}],
            )

            with self.assertRaisesRegex(ValueError, "Preset path must belong to the selected city model"):
                service.create_scenario(
                    name="invalid scenario",
                    city_model_id=city_a.id,
                    base_station_set_id=stations.id,
                    preset_path_id=path.id,
                )

    def test_import_specs_explain_supported_file_formats(self) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            service = self.make_service(tmp_dir)

            specs = service.get_import_specs("preset_path")

            formats = {spec["format"] for spec in specs}
            self.assertIn("json", formats)
            self.assertIn("csv", formats)
            self.assertTrue(all(spec["exampleText"] for spec in specs))


if __name__ == "__main__":
    unittest.main()
