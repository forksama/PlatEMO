function run_planning_job(platemoRoot, inputJsonPath, artifactDir)
%RUN_PLANNING_JOB Execute DCMOCPSO + UAVPathPlanning and export artifacts.
%
% This bridge intentionally lives outside the PlatEMO source tree. It keeps
% the Matlab algorithms unchanged while giving the Python backend a stable
% file-based integration point.

    if exist(artifactDir, 'dir') ~= 7
        mkdir(artifactDir);
    end

    addpath(genpath(platemoRoot));
    configText = fileread(inputJsonPath);
    config = jsondecode(configText);
    writeProgress(artifactDir, 'loading_scenario', 8, 'Loaded task input.');

    presetAltitude = NaN;
    if isfield(config.problem, 'preset_altitude_m') && ~isempty(config.problem.preset_altitude_m)
        presetAltitude = config.problem.preset_altitude_m;
    end
    altitudeBounds = [];
    if isfield(config.problem, 'altitude_bounds_m') && ~isempty(config.problem.altitude_bounds_m)
        altitudeBounds = config.problem.altitude_bounds_m;
    end
    scenarioDataPath = '';
    if isfield(config, 'scenario') && isfield(config.scenario, 'matlabScenarioFile') && ...
            ~isempty(config.scenario.matlabScenarioFile)
        scenarioDataPath = char(config.scenario.matlabScenarioFile);
    end

    problemParameter = {
        config.problem.bs_per_km2, ...
        config.problem.velocity, ...
        config.problem.ttt_seconds, ...
        config.problem.switch_threshold_dbm, ...
        config.problem.obstacle_method, ...
        config.problem.transmit_power_dbm, ...
        config.problem.switch_method, ...
        config.problem.lookahead_distance_m, ...
        config.problem.lookahead_hysteresis_range_db, ...
        config.problem.lookahead_safety_margin_db, ...
        presetAltitude, ...
        altitudeBounds, ...
        scenarioDataPath
    };

    algorithmParameter = {
        config.algorithm.num_segments, ...
        config.algorithm.segment_overlap, ...
        config.algorithm.lambda_weight, ...
        config.algorithm.c_guide, ...
        config.algorithm.use_dynamic_grouping, ...
        config.algorithm.use_dynamic_mutation, ...
        config.algorithm.use_ek, ...
        config.algorithm.uniform_point_multiplier
    };

    writeProgress(artifactDir, 'initializing_problem', 12, 'Initializing UAVPathPlanning.');
    Problem = UAVPathPlanning( ...
        'N', config.algorithm.population_size, ...
        'maxFE', config.algorithm.max_fe, ...
        'parameter', problemParameter);
    writeProgress(artifactDir, 'initializing_algorithm', 18, 'Initializing DCMOCPSO.');
    Algorithm = DCMOCPSO('parameter', algorithmParameter, 'outputFcn', @(~,~)[]);

    writeProgress(artifactDir, 'running_algorithm', 25, 'Running DCMOCPSO.');
    tic;
    Algorithm.Solve(Problem);
    runtimeSeconds = toc;

    if isempty(Algorithm.result)
        error('run_planning_job:NoResult', 'Algorithm.result is empty.');
    end

    finalPopulation = Algorithm.result{end, 2};
    decs = finalPopulation.decs;
    objs = finalPopulation.objs;
    cons = finalPopulation.cons;

    result = struct();
    result.metrics = summarizePopulation(runtimeSeconds, Problem.FE, decs, objs, finalPopulation, Problem.optimum);
    result.objectives = exportObjectives(objs);
    result.solutions = exportSolutions(Problem, decs);
    result.scenario = exportScenario(Problem, config);

    writeProgress(artifactDir, 'exporting_result', 92, 'Writing result artifacts.');
    resultPath = fullfile(artifactDir, 'result.json');
    fid = fopen(resultPath, 'w');
    fwrite(fid, jsonencode(result), 'char');
    fclose(fid);

    matPath = fullfile(artifactDir, 'result.mat');
    save(matPath, 'config', 'decs', 'objs', 'cons', 'result');
    writeProgress(artifactDir, 'finished', 100, 'Planning job finished.');
end

function metrics = summarizePopulation(runtimeSeconds, actualFE, decs, objs, population, optimum)
    metrics = struct();
    metrics.runtimeSeconds = runtimeSeconds;
    metrics.actualFE = actualFE;
    metrics.solutionCount = size(decs, 1);
    metrics.hypervolume = calculateHypervolumeMetric(population, optimum);
    if isempty(objs)
        metrics.meanSignalDbm = NaN;
        metrics.meanSwitchCount = NaN;
        metrics.meanCoverageRatio = NaN;
        return;
    end
    metrics.meanSignalDbm = mean(-objs(:, 1), 'omitnan');
    metrics.meanSwitchCount = mean(objs(:, 2), 'omitnan');
    if size(objs, 2) >= 3
        metrics.meanCoverageRatio = mean(-objs(:, 3), 'omitnan');
    else
        metrics.meanCoverageRatio = NaN;
    end
end

function value = calculateHypervolumeMetric(population, optimum)
    try
        value = HV(population, optimum);
    catch err
        warning('run_planning_job:HypervolumeFailed', 'Failed to calculate HV: %s', err.message);
        value = NaN;
    end
end

function objectives = exportObjectives(objs)
    objectives = struct([]);
    for i = 1:size(objs, 1)
        objectives(i).solutionIndex = i - 1;
        objectives(i).negativeSignal = objs(i, 1);
        objectives(i).switchCount = objs(i, 2);
        objectives(i).negativeCoverage = objs(i, 3);
    end
end

function solutions = exportSolutions(Problem, decs)
    solutions = struct([]);
    for i = 1:size(decs, 1)
        waypoints = reshape(decs(i, :), 3, [])';
        details = Problem.calculateSwitchDetails(waypoints);
        solutions(i).solutionIndex = i - 1;
        solutions(i).waypoints = waypoints;
        solutions(i).servingBaseStations = details.connectedBS;
        solutions(i).switchPoints = exportSwitchPoints(details);
    end
end

function switchPoints = exportSwitchPoints(details)
    switchPoints = struct([]);
    if ~isfield(details, 'switchPoints') || isempty(details.switchPoints)
        return;
    end
    for i = 1:size(details.switchPoints, 1)
        switchPoints(i).waypointIndex = details.switchPoints(i, 1);
        switchPoints(i).fromBaseStation = details.switchPoints(i, 2);
        switchPoints(i).toBaseStation = details.switchPoints(i, 3);
    end
end

function scenario = exportScenario(Problem, config)
    scenario = struct();
    scenario.presetPath = Problem.getPresetPath();
    scenario.baseStations = [];
    scenario.obstacles = [];

    scenarioDataPath = '';
    if isfield(config, 'scenario') && isfield(config.scenario, 'matlabScenarioFile') && ...
            ~isempty(config.scenario.matlabScenarioFile)
        scenarioDataPath = char(config.scenario.matlabScenarioFile);
    end
    if ~isempty(scenarioDataPath) && exist(scenarioDataPath, 'file') == 2
        external = jsondecode(fileread(scenarioDataPath));
        if isfield(external, 'baseStations')
            scenario.baseStations = external.baseStations;
        end
        if isfield(external, 'obstacles')
            scenario.obstacles = external.obstacles;
        end
        return;
    end

    scenarioFile = fullfile( ...
        fileparts(which('UAVPathPlanning')), ...
        sprintf('UAVPathPlanning-%d-%d.mat', ...
            config.problem.obstacle_method, config.problem.bs_per_km2));
    if exist(scenarioFile, 'file') == 2
        loaded = load(scenarioFile, 'baseStations', 'obstacles');
        if isfield(loaded, 'baseStations')
            scenario.baseStations = loaded.baseStations;
        end
        if isfield(loaded, 'obstacles')
            scenario.obstacles = flattenObstacles(loaded.obstacles);
        end
    end
end

function writeProgress(artifactDir, stage, percent, message)
    progress = struct();
    progress.stage = stage;
    progress.percent = percent;
    progress.message = message;
    beijingNow = datetime('now', 'TimeZone', 'Asia/Shanghai', 'Format', 'yyyy-MM-dd''T''HH:mm:ss.SSS');
    progress.updatedAt = [char(beijingNow), '+08:00'];
    progressPath = fullfile(artifactDir, 'progress.json');
    fid = fopen(progressPath, 'w');
    if fid < 0
        return;
    end
    fwrite(fid, jsonencode(progress), 'char');
    fclose(fid);
end

function flattened = flattenObstacles(obstacles)
    flattened = struct([]);
    if isempty(obstacles)
        return;
    end
    count = 0;
    for x = 1:size(obstacles, 1)
        for y = 1:size(obstacles, 2)
            obs = squeeze(obstacles(x, y, :))';
            if numel(obs) >= 5
                count = count + 1;
                flattened(count).xMin = obs(1);
                flattened(count).yMin = obs(2);
                flattened(count).xMax = obs(3);
                flattened(count).yMax = obs(4);
                flattened(count).height = obs(5);
            end
        end
    end
end
