% example_ablation_UAVPathPlanning_TTT_bsDensity_FullParam.m
%
% One-factor ablations for UAVPathPlanning TTT interval and base-station
% density. The two sweeps are independent and do not form a Cartesian
% product.
%
% Algorithm settings are fixed to Full_Lookahead/full_param:
%   {5, 2, 0.5, 0.3, true, true, true} + switchMethod=2

clear; clc; close all;

%% Settings
n = 20;

enableParallelPool = true;
parallelPoolProfile = 'Processes';
parallelPoolNumWorkers = [];
prepareParallelPool(enableParallelPool, parallelPoolProfile, parallelPoolNumWorkers);

N = 20;
baseProblemParameter = {20, 20, 5, -101.5, 0, 30, 2, 500, 10, 4};

TTTList = [1, 3, 5, 7, 9];
bsPerKm2List = [5, 10, 20, 30, 40];

maxFE_Full = 100;
param_Full = {5, 2, 0.5, 0.3, true, true, true};

cacheDir = fullfile(fileparts(mfilename('fullpath')), 'results', 'ttt_bs_density_full_param');
if exist(cacheDir, 'dir') ~= 7
    mkdir(cacheDir);
end

commonConfig = struct( ...
    'N', N, ...
    'maxFE', maxFE_Full, ...
    'baseProblemParameter', {baseProblemParameter}, ...
    'param_Full', {param_Full});

%% Experiment 1: TTT sweep
tttGroupNames = arrayfun(@(v) sprintf('ttt_%ss', valueTag(v)), TTTList, 'UniformOutput', false);
tttProblemParams = cell(1, numel(TTTList));
for i = 1:numel(TTTList)
    tttProblemParams{i} = makeTTTProblemParameter(baseProblemParameter, TTTList(i));
end

tttResults = runExperimentSet( ...
    'TTT_Full', tttGroupNames, tttProblemParams, TTTList, 'TTT', 's', ...
    @(value) fullfile(cacheDir, sprintf('TTT_Full_ttt_%ss_HV_objMetrics_runs.mat', valueTag(value))), ...
    cacheDir, n, commonConfig);

%% Experiment 2: base-station-density sweep
bsDensityGroupNames = arrayfun(@(v) sprintf('bs_%s', valueTag(v)), bsPerKm2List, 'UniformOutput', false);
bsDensityProblemParams = cell(1, numel(bsPerKm2List));
for i = 1:numel(bsPerKm2List)
    bsDensityProblemParams{i} = makeBsDensityProblemParameter(baseProblemParameter, bsPerKm2List(i));
end

bsDensityResults = runExperimentSet( ...
    'BSDensity_Full', bsDensityGroupNames, bsDensityProblemParams, bsPerKm2List, 'bsPerKm2', 'stations/km^2', ...
    @(value) fullfile(cacheDir, sprintf('BSDensity_Full_bs_%s_HV_objMetrics_runs.mat', valueTag(value))), ...
    cacheDir, n, commonConfig);

%% Save combined summary
combinedSummaryFile = fullfile(cacheDir, 'TTT_BSDensity_Full_oneFactor_summary.mat');
save(combinedSummaryFile, 'tttResults', 'bsDensityResults', ...
    'TTTList', 'bsPerKm2List', 'n', 'commonConfig');
fprintf('\nCombined summary saved to: %s\n', combinedSummaryFile);

%% Plot comparisons
plotMetricSet(tttResults, 'Full_Lookahead TTT sweep', [200, 200], true);
plotMetricSet(bsDensityResults, 'Full_Lookahead base-station-density sweep', [1120, 200], true);


%% ===================== local functions =====================
function problemParameter = makeTTTProblemParameter(baseProblemParameter, TTT)
    problemParameter = baseProblemParameter;
    problemParameter{3} = TTT;
    problemParameter{7} = 2;
end

function problemParameter = makeBsDensityProblemParameter(baseProblemParameter, bsPerKm2)
    problemParameter = baseProblemParameter;
    problemParameter{1} = bsPerKm2;
    problemParameter{7} = 2;
end

function results = runExperimentSet(experimentName, groupNames, groupProblemParams, sweptValues, sweptParamName, sweptUnit, cacheFileFn, cacheDir, n, commonConfig)
    numGroups = numel(groupNames);
    hvLastAll = cell(1, numGroups);
    hvSeriesAll = cell(1, numGroups);
    actualFEAll = cell(1, numGroups);
    runtimeAll = cell(1, numGroups);
    meanSignalAll = cell(1, numGroups);
    meanSwitchCountAll = cell(1, numGroups);
    meanCoverageRatioAll = cell(1, numGroups);
    objMetricSummaryAll = cell(1, numGroups);

    fprintf('\n=== %s ablation (n=%d) ===\n', experimentName, n);
    fprintf('Common settings: N=%d, maxFE=%d, param_Full={5,2,0.5,0.3,true,true,true}\n', ...
        commonConfig.N, commonConfig.maxFE);

    for i = 1:numGroups
        cacheFile = cacheFileFn(sweptValues(i));
        [hvLastAll{i}, hvSeriesAll{i}, actualFEAll{i}, runtimeAll{i}, meanSignalAll{i}, meanSwitchCountAll{i}, meanCoverageRatioAll{i}, objMetricSummaryAll{i}] = runOrLoad( ...
            sprintf('%s/%s', experimentName, groupNames{i}), cacheFile, n, ...
            @() runOne_DCMOCPSO(commonConfig.N, commonConfig.maxFE, groupProblemParams{i}, commonConfig.param_Full), ...
            true);
    end

    meanHV = nan(1, numGroups);
    stdHV = nan(1, numGroups);
    meanRuntime = nan(1, numGroups);
    stdRuntime = nan(1, numGroups);
    meanActualFE = nan(1, numGroups);
    meanSignal = nan(1, numGroups);
    stdSignal = nan(1, numGroups);
    meanSwitchCount = nan(1, numGroups);
    stdSwitchCount = nan(1, numGroups);
    meanCoverageRatio = nan(1, numGroups);
    stdCoverageRatio = nan(1, numGroups);
    validCount = zeros(1, numGroups);

    fprintf('\n--- %s summary ---\n', experimentName);
    for i = 1:numGroups
        validIdx = ~isnan(hvLastAll{i});
        validCount(i) = sum(validIdx);
        meanHV(i) = meanValid(hvLastAll{i}(validIdx));
        stdHV(i) = stdValid(hvLastAll{i}(validIdx));
        meanRuntime(i) = meanValid(runtimeAll{i}(validIdx));
        stdRuntime(i) = stdValid(runtimeAll{i}(validIdx));
        meanActualFE(i) = meanValid(actualFEAll{i}(validIdx));
        meanSignal(i) = meanValid(meanSignalAll{i}(validIdx));
        stdSignal(i) = stdValid(meanSignalAll{i}(validIdx));
        meanSwitchCount(i) = meanValid(meanSwitchCountAll{i}(validIdx));
        stdSwitchCount(i) = stdValid(meanSwitchCountAll{i}(validIdx));
        meanCoverageRatio(i) = meanValid(meanCoverageRatioAll{i}(validIdx));
        stdCoverageRatio(i) = stdValid(meanCoverageRatioAll{i}(validIdx));

        fprintf('%-12s : %s=%g %s, mean(last HV)=%.6e, std=%.6e (valid=%d/%d, actualFE mean=%.1f, runtime mean=%.2fs, signal mean=%.4f, switch mean=%.4f, coverage mean=%.4f)\n', ...
            groupNames{i}, sweptParamName, sweptValues(i), sweptUnit, ...
            meanHV(i), stdHV(i), validCount(i), n, meanActualFE(i), meanRuntime(i), meanSignal(i), meanSwitchCount(i), meanCoverageRatio(i));
    end

    results = struct();
    results.experimentName = experimentName;
    results.groupNames = groupNames;
    results.groupProblemParams = groupProblemParams;
    results.sweptParamName = sweptParamName;
    results.sweptUnit = sweptUnit;
    results.sweptValues = sweptValues;
    results.commonConfig = commonConfig;
    results.hvLastAll = hvLastAll;
    results.hvSeriesAll = hvSeriesAll;
    results.actualFEAll = actualFEAll;
    results.runtimeAll = runtimeAll;
    results.meanSignalAll = meanSignalAll;
    results.meanSwitchCountAll = meanSwitchCountAll;
    results.meanCoverageRatioAll = meanCoverageRatioAll;
    results.objMetricSummaryAll = objMetricSummaryAll;
    results.meanHV = meanHV;
    results.stdHV = stdHV;
    results.meanRuntime = meanRuntime;
    results.stdRuntime = stdRuntime;
    results.meanActualFE = meanActualFE;
    results.meanSignal = meanSignal;
    results.stdSignal = stdSignal;
    results.meanSwitchCount = meanSwitchCount;
    results.stdSwitchCount = stdSwitchCount;
    results.meanCoverageRatio = meanCoverageRatio;
    results.stdCoverageRatio = stdCoverageRatio;
    results.validCount = validCount;

    summaryFile = fullfile(cacheDir, sprintf('%s_summary.mat', experimentName));
    save(summaryFile, 'results');
    fprintf('%s summary saved to: %s\n', experimentName, summaryFile);
end

function plotMetricSet(results, titlePrefix, basePosition, smartHVYLim)
    colors = lines(numel(results.groupNames));
    x0 = basePosition(1);
    y0 = basePosition(2);

    figure('Name', sprintf('%s metrics', results.experimentName), ...
        'Color', 'w', 'Position', [x0, y0, 1500, 900]);
    layout = tiledlayout(2, 3, 'TileSpacing', 'compact', 'Padding', 'compact');
    title(layout, titlePrefix, 'FontSize', 14, 'FontWeight', 'bold');

    plotBarComparison(nexttile(layout), 'Mean of last HV', ...
        'HV', results.groupNames, results.meanHV, results.stdHV, colors, smartHVYLim);

    plotBarComparison(nexttile(layout), 'Mean runtime (seconds)', ...
        'Runtime', results.groupNames, results.meanRuntime, results.stdRuntime, colors, false);

    plotBarComparison(nexttile(layout), 'Mean signal strength (dBm)', ...
        'Signal', results.groupNames, results.meanSignal, results.stdSignal, colors, true);

    plotBarComparison(nexttile(layout), 'Mean switch count', ...
        'Switch Count', results.groupNames, results.meanSwitchCount, results.stdSwitchCount, colors, true);

    plotBarComparison(nexttile(layout), 'Mean coverage ratio', ...
        'Coverage', results.groupNames, results.meanCoverageRatio, results.stdCoverageRatio, colors, true);

    axis(nexttile(layout), 'off');
end

function tag = valueTag(value)
    tag = strrep(sprintf('%g', value), '.', 'p');
end

function [hvLast, hvSeries, actualFE, runtime, meanSignal, meanSwitchCount, meanCoverageRatio, objMetricSummary, lastAlgorithm, lastProblem] = runOrLoad(algName, cacheFile, n, runOneFn, allowRun)
    hvLast = nan(1,n);
    hvSeries = cell(1,n);
    actualFE = nan(1,n);
    runtime = nan(1,n);
    meanSignal = nan(1,n);
    meanSwitchCount = nan(1,n);
    meanCoverageRatio = nan(1,n);
    objMetricSummary = cell(1,n);
    lastAlgorithm = [];
    lastProblem = [];

    runs = struct('hv', {}, 'actualFE', {}, 'runtime', {}, 'meanSignal', {}, 'meanSwitchCount', {}, 'meanCoverageRatio', {}, 'objMetricSummary', {});
    loadCount = 0;
    if exist(cacheFile, 'file') == 2
        S = load(cacheFile);
        if isfield(S, 'runs')
            runs = S.runs;
            loadCount = min(numel(runs), n);
            fprintf('[%s] load %d/%d run(s) from cache: %s\n', algName, loadCount, n, cacheFile);
            for i = 1:loadCount
                if isfield(runs, 'hv') && ~isempty(runs(i).hv)
                    hvSeries{i} = runs(i).hv;
                    hvLast(i) = runs(i).hv(end);
                end
                if isfield(runs, 'actualFE')
                    actualFE(i) = runs(i).actualFE;
                end
                if isfield(runs, 'runtime')
                    runtime(i) = runs(i).runtime;
                end
                if isfield(runs, 'meanSignal') && ~isempty(runs(i).meanSignal)
                    meanSignal(i) = runs(i).meanSignal;
                end
                if isfield(runs, 'meanSwitchCount') && ~isempty(runs(i).meanSwitchCount)
                    meanSwitchCount(i) = runs(i).meanSwitchCount;
                end
                if isfield(runs, 'meanCoverageRatio') && ~isempty(runs(i).meanCoverageRatio)
                    meanCoverageRatio(i) = runs(i).meanCoverageRatio;
                end
                if isfield(runs, 'objMetricSummary') && ~isempty(runs(i).objMetricSummary)
                    objMetricSummary{i} = runs(i).objMetricSummary;
                end
            end
            if loadCount >= n
                return;
            end
        end
    end

    if ~allowRun
        fprintf('[%s] cache is missing or incomplete, and recomputation is disabled. Missing runs remain NaN.\n', algName);
        return;
    end

    startRun = loadCount + 1;

    fprintf('[%s] cache miss/incomplete -> run %d time(s)\n', algName, n - startRun + 1);

    for i = startRun:n
        fprintf('\n>>> Current algorithm: %s\n', algName);
        fprintf('  Run %d/%d...\n', i, n);
        try
            [hvSeries{i}, actualFE(i), runtime(i), objMetricSummary{i}, lastAlgorithm, lastProblem] = runOneFn();
            hvLast(i) = hvSeries{i}(end);
            meanSignal(i) = objMetricSummary{i}.meanSignal;
            meanSwitchCount(i) = objMetricSummary{i}.meanSwitchCount;
            meanCoverageRatio(i) = objMetricSummary{i}.meanCoverageRatio;
            runs(i).hv = hvSeries{i};
            runs(i).actualFE = actualFE(i);
            runs(i).runtime = runtime(i);
            runs(i).meanSignal = meanSignal(i);
            runs(i).meanSwitchCount = meanSwitchCount(i);
            runs(i).meanCoverageRatio = meanCoverageRatio(i);
            runs(i).objMetricSummary = objMetricSummary{i};
            save(cacheFile, 'runs');
            fprintf('  Run %d/%d saved to: %s\n', i, n, cacheFile);
        catch ME
            fprintf('  Run %d/%d FAILED: %s\n', i, n, ME.message);
        end
    end
end

function prepareParallelPool(enableParallelPool, poolProfile, numWorkers)
    if ~enableParallelPool
        return;
    end

    if isempty(ver('parallel'))
        fprintf('[Parallel] Parallel Computing Toolbox is unavailable; parfor will run serially.\n');
        return;
    end

    pool = gcp('nocreate');
    if isempty(pool)
        fprintf('[Parallel] Starting parallel pool before algorithm timing...\n');
        if isempty(numWorkers)
            pool = parpool(poolProfile);
        else
            pool = parpool(poolProfile, numWorkers);
        end
    else
        fprintf('[Parallel] Reusing existing parallel pool with %d worker(s).\n', pool.NumWorkers);
    end

    warmupFuture = parfeval(pool, @() 1, 1);
    fetchOutputs(warmupFuture);
    fprintf('[Parallel] Pool ready with %d worker(s).\n', pool.NumWorkers);
end

function [hv, actualFE, runtime, objMetricSummary, Algorithm, Problem] = runOne_DCMOCPSO(N, maxFE, problemParameter, algorithmParameter)
    Algorithm = DCMOCPSO('parameter', algorithmParameter, 'outputFcn', @(~,~)[]);
    Problem = UAVPathPlanning('N', N, 'maxFE', maxFE, 'parameter', problemParameter);
    tStart = tic;
    Algorithm.Solve(Problem);
    runtime = toc(tStart);
    hv = extractHV(Algorithm);
    objMetricSummary = extractObjectiveMetrics(Algorithm);
    actualFE = Problem.FE;
end

function hv = extractHV(Algorithm)
    m = Algorithm.Metric('HV');
    hv = m(:,2)';
    if isempty(hv)
        error('No HV metric captured. Ensure Problem.M>1 and Algorithm saved results.');
    end
end

function objMetricSummary = extractObjectiveMetrics(Algorithm)
    objMetricSummary = struct('meanSignal', NaN, 'meanSwitchCount', NaN, ...
        'meanCoverageRatio', NaN, 'finalPopulationSize', 0);

    if isempty(Algorithm.result) || isempty(Algorithm.result{end})
        return;
    end

    finalPopulation = Algorithm.result{end};
    if isempty(finalPopulation)
        return;
    end

    popObj = finalPopulation.objs;
    if isempty(popObj)
        return;
    end

    objMetricSummary.finalPopulationSize = size(popObj, 1);
    objMetricSummary.meanSignal = meanValid(-popObj(:, 1));
    objMetricSummary.meanSwitchCount = meanValid(popObj(:, 2));
    if size(popObj, 2) >= 3
        objMetricSummary.meanCoverageRatio = meanValid(-popObj(:, 3));
    end
end

function value = meanValid(values)
    values = values(~isnan(values) & isfinite(values));
    if isempty(values)
        value = NaN;
    else
        value = mean(values);
    end
end

function value = stdValid(values)
    values = values(~isnan(values) & isfinite(values));
    if isempty(values)
        value = NaN;
    else
        value = std(values);
    end
end

function plotBarComparison(ax, yLabelText, titleText, groupNames, values, errors, colors, smartYLim)
    x = 1:numel(groupNames);
    b = bar(ax, x, values);
    b.FaceColor = 'flat';
    for i = 1:numel(values)
        b.CData(i,:) = colors(i,:);
    end
    hold(ax, 'on');
    errorbar(ax, x, values, errors, 'k', 'linestyle', 'none', 'LineWidth', 1.2);
    ylabel(ax, yLabelText);
    title(ax, titleText);
    grid(ax, 'on');
    set(ax, 'FontSize', 10, 'XTick', x, 'XTickLabel', groupNames);
    xtickangle(ax, 30);

    if smartYLim
        validValues = values(~isnan(values));
        if ~isempty(validValues)
            validErrors = errors(~isnan(values));
            validErrors(isnan(validErrors)) = 0;
            vMin = min(validValues - validErrors);
            vMax = max(validValues + validErrors);
            vRange = vMax - vMin;
            if vRange > 0
                margin = vRange * 0.15;
                ylim(ax, [vMin - margin, vMax + margin]);
            end
        end
    end
end
