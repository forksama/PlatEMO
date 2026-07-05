import { useEffect, useRef } from "react";
import * as THREE from "three";
import { OrbitControls } from "three/examples/jsm/controls/OrbitControls.js";

import type {
  BaseStationPayload,
  CityGeometry,
  PlanningResult,
  PresetPathPayload,
  Waypoint
} from "../api/client";

type SceneControlMode = "rotate" | "pan";

interface ThreeSceneProps {
  city: CityGeometry | null;
  baseStations: BaseStationPayload | null;
  presetPath: PresetPathPayload | null;
  result: PlanningResult | null;
  selectedSolution: number;
  controlMode?: SceneControlMode;
}

interface SceneViewState {
  cityId: string;
  position: [number, number, number];
  target: [number, number, number];
  zoom: number;
}

function applyControlMode(controls: OrbitControls, mode: SceneControlMode) {
  controls.mouseButtons = {
    LEFT: mode === "pan" ? THREE.MOUSE.PAN : THREE.MOUSE.ROTATE,
    MIDDLE: THREE.MOUSE.DOLLY,
    RIGHT: mode === "pan" ? THREE.MOUSE.ROTATE : THREE.MOUSE.PAN
  };
  controls.touches = {
    ONE: mode === "pan" ? THREE.TOUCH.PAN : THREE.TOUCH.ROTATE,
    TWO: THREE.TOUCH.DOLLY_PAN
  };
}

function toScenePoint(point: Waypoint | { x: number; y: number; z: number }): THREE.Vector3 {
  if (Array.isArray(point)) {
    return new THREE.Vector3(point[0], point[2], point[1]);
  }
  return new THREE.Vector3(point.x, point.z, point.y);
}

function makeLine(points: THREE.Vector3[], color: number, dashed = false): THREE.Line {
  const geometry = new THREE.BufferGeometry().setFromPoints(points);
  const material = dashed
    ? new THREE.LineDashedMaterial({ color, dashSize: 45, gapSize: 25, linewidth: 2 })
    : new THREE.LineBasicMaterial({ color, linewidth: 3 });
  const line = new THREE.Line(geometry, material);
  if (dashed) {
    line.computeLineDistances();
  }
  return line;
}

export function ThreeScene({
  city,
  baseStations,
  presetPath,
  result,
  selectedSolution,
  controlMode = "rotate"
}: ThreeSceneProps) {
  const hostRef = useRef<HTMLDivElement | null>(null);
  const controlsRef = useRef<OrbitControls | null>(null);
  const viewStateRef = useRef<SceneViewState | null>(null);
  const controlModeRef = useRef(controlMode);
  controlModeRef.current = controlMode;

  useEffect(() => {
    if (controlsRef.current) {
      applyControlMode(controlsRef.current, controlMode);
    }
  }, [controlMode]);

  useEffect(() => {
    const host = hostRef.current;
    if (!host) {
      return;
    }

    const width = Math.max(480, host.clientWidth);
    const height = Math.max(360, host.clientHeight);
    const scene = new THREE.Scene();
    scene.background = new THREE.Color(0xf2f5f6);

    const camera = new THREE.PerspectiveCamera(50, width / height, 1, 20000);
    const renderer = new THREE.WebGLRenderer({ antialias: true });
    renderer.setSize(width, height);
    renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
    renderer.shadowMap.enabled = true;
    host.replaceChildren(renderer.domElement);

    const controls = new OrbitControls(camera, renderer.domElement);
    controls.enableDamping = true;
    controls.screenSpacePanning = true;
    applyControlMode(controls, controlModeRef.current);
    controlsRef.current = controls;

    const bounds = city?.bounds ?? { minX: 0, minY: 0, maxX: 1000, maxY: 1000 };
    const centerX = (bounds.minX + bounds.maxX) / 2;
    const centerY = (bounds.minY + bounds.maxY) / 2;
    const span = Math.max(bounds.maxX - bounds.minX, bounds.maxY - bounds.minY, 400);
    const viewCityId = city?.id ?? "empty-scene";
    const savedView = viewStateRef.current?.cityId === viewCityId ? viewStateRef.current : null;
    if (savedView) {
      camera.position.set(...savedView.position);
      camera.zoom = savedView.zoom;
      controls.target.set(...savedView.target);
      camera.updateProjectionMatrix();
    } else {
      camera.position.set(centerX + span * 0.8, span * 0.75, centerY + span * 0.85);
      controls.target.set(centerX, 0, centerY);
    }
    const rememberView = () => {
      viewStateRef.current = {
        cityId: viewCityId,
        position: [camera.position.x, camera.position.y, camera.position.z],
        target: [controls.target.x, controls.target.y, controls.target.z],
        zoom: camera.zoom
      };
    };
    controls.addEventListener("change", rememberView);
    rememberView();

    const hemi = new THREE.HemisphereLight(0xffffff, 0x8a9398, 1.6);
    scene.add(hemi);
    const sun = new THREE.DirectionalLight(0xffffff, 1.8);
    sun.position.set(centerX - span, span * 1.5, centerY + span);
    sun.castShadow = true;
    scene.add(sun);

    const groundGeometry = new THREE.PlaneGeometry(span * 1.25, span * 1.25);
    const groundMaterial = new THREE.MeshStandardMaterial({ color: 0xdde5e6, roughness: 0.92 });
    const ground = new THREE.Mesh(groundGeometry, groundMaterial);
    ground.rotation.x = -Math.PI / 2;
    ground.position.set(centerX, -0.5, centerY);
    ground.name = "ground";
    scene.add(ground);

    const grid = new THREE.GridHelper(span * 1.25, 24, 0xa8b4b8, 0xc7d0d2);
    grid.position.set(centerX, 0, centerY);
    scene.add(grid);

    const buildingMaterial = new THREE.MeshStandardMaterial({
      color: 0x9fb0b7,
      roughness: 0.78,
      metalness: 0.05
    });
    city?.buildings.slice(0, 1400).forEach((building) => {
      const widthX = Math.max(1, building.xMax - building.xMin);
      const depthY = Math.max(1, building.yMax - building.yMin);
      const geometry = new THREE.BoxGeometry(widthX, building.height, depthY);
      const mesh = new THREE.Mesh(geometry, buildingMaterial);
      mesh.position.set(
        (building.xMin + building.xMax) / 2,
        building.height / 2,
        (building.yMin + building.yMax) / 2
      );
      mesh.castShadow = true;
      mesh.receiveShadow = true;
      scene.add(mesh);
    });

    const stationMaterial = new THREE.MeshStandardMaterial({ color: 0x1976a3, emissive: 0x05212e });
    baseStations?.baseStations.forEach((station) => {
      const cap = new THREE.Mesh(new THREE.SphereGeometry(10, 18, 18), stationMaterial);
      cap.position.set(station.x, station.z, station.y);
      scene.add(cap);
    });

    const presetPoints = presetPath?.points.map(toScenePoint) ?? result?.scenario.presetPath.map(toScenePoint) ?? [];
    if (presetPoints.length >= 2) {
      scene.add(makeLine(presetPoints, 0x596a72, true));
    }
    const pointMaterial = new THREE.MeshStandardMaterial({ color: 0xffffff, emissive: 0x112f25 });
    presetPoints.forEach((point) => {
      const marker = new THREE.Mesh(new THREE.SphereGeometry(7, 16, 16), pointMaterial);
      marker.position.copy(point);
      scene.add(marker);
    });

    const selected = result?.solutions.find((item) => item.solutionIndex === selectedSolution) ?? result?.solutions[0];
    if (selected && selected.waypoints.length >= 2) {
      scene.add(makeLine(selected.waypoints.map(toScenePoint), 0x1f7a55, false));
      const switchMaterial = new THREE.MeshStandardMaterial({ color: 0xd24f45, emissive: 0x3a0c08 });
      selected.switchPoints.forEach((switchPoint) => {
        const waypoint = selected.waypoints[switchPoint.waypointIndex];
        if (!waypoint) {
          return;
        }
        const marker = new THREE.Mesh(new THREE.SphereGeometry(12, 18, 18), switchMaterial);
        marker.position.copy(toScenePoint(waypoint));
        scene.add(marker);
      });
    }

    const contextMenuHandler = (event: MouseEvent) => {
      event.preventDefault();
    };
    renderer.domElement.addEventListener("contextmenu", contextMenuHandler);

    let frame = 0;
    const animate = () => {
      frame = window.requestAnimationFrame(animate);
      controls.update();
      renderer.render(scene, camera);
    };
    animate();

    const resize = () => {
      const nextWidth = Math.max(360, host.clientWidth);
      const nextHeight = Math.max(320, host.clientHeight);
      camera.aspect = nextWidth / nextHeight;
      camera.updateProjectionMatrix();
      renderer.setSize(nextWidth, nextHeight);
    };
    window.addEventListener("resize", resize);

    return () => {
      window.cancelAnimationFrame(frame);
      window.removeEventListener("resize", resize);
      renderer.domElement.removeEventListener("contextmenu", contextMenuHandler);
      controls.removeEventListener("change", rememberView);
      if (controlsRef.current === controls) {
        controlsRef.current = null;
      }
      controls.dispose();
      renderer.dispose();
      scene.traverse((object) => {
        if (object instanceof THREE.Mesh || object instanceof THREE.Line) {
          object.geometry.dispose();
          const materials = Array.isArray(object.material) ? object.material : [object.material];
          materials.forEach((material) => material.dispose());
        }
      });
    };
  }, [baseStations, city, presetPath, result, selectedSolution]);

  return <div className="three-scene" ref={hostRef} />;
}
