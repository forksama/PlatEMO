% example_compare_DCMOCPSO_vs_baselines.m
%
% Algorithm-level comparison on UAVPathPlanning.
%
% Groups:
% 1) DCMOCPSO    : improved algorithm, reusing Full_Lookahead_HV_runs.mat
% 2) Base-MOCPSO : baseline represented by OneSeg_Lookahead_HV_runs.mat
% 3) IMMOEAD     : competitor algorithm
% 4) DGEA        : competitor algorithm
%
% Disabled:
% - MMOPSO       : competitor algorithm
%
% The old DCMOCPSO/Base-MOCPSO cache files are loaded by default and are not
% recomputed unless allowRunCachedGroups is set to true.

clear; clc; close all;

%% Settings
n = 10;

% Set this to true only if the old cached groups are missing and you really
% want to recompute them. Recomputing can take several hours.
allowRunCachedGroups = true;

% Start and warm up the parallel pool before per-run timing begins, so the
% parpool startup cost is not counted in any algorithm runtime.
enableParallelPool = true;
parallelPoolProfile = 'Processes';
parallelPoolNumWorkers = [];
prepareParallelPool(enableParallelPool, parallelPoolProfile, parallelPoolNumWorkers);

% UAVPathPlanning parameters shared by all groups.
N = 20;
problemParameter_Lookahead = {20, 20, 5, -101.5, 0, 30, 2, 500};

% DCMOCPSO settings used by the existing Full_Lookahead cache.
maxFE_DCMOCPSO = 100;
numSegments = 5;
param_Full   = {numSegments, 2, 0.5, 0.3, true,  true,  true};
param_OneSeg = {1,           2, 0.5, 0.3, false, false, false};

% Result cache. The first two names intentionally match the existing
% ablation-study cache files so the script can reuse hours of completed runs.
cacheDir = fullfile(fileparts(mfilename('fullpath')), 'results');
if exist(cacheDir, 'dir') ~= 7
    mkdir(cacheDir);
end

cacheFile_DCMOCPSO    = fullfile(cacheDir, 'Full_Lookahead_HV_runs.mat');
cacheFile_BaseMOCPSO  = fullfile(cacheDir, 'OneSeg_Lookahead_HV_runs.mat');
% cacheFile_MMOPSO      = fullfile(cacheDir, 'MMOPSO_HV_runs.mat');
cacheFile_IMMOEAD     = fullfile(cacheDir, 'IMMOEAD_HV_runs.mat');
cacheFile_DGEA        = fullfile(cacheDir, 'DGEA_HV_runs.mat');

%% Run or load groups
[hvLast_DCMOCPSO, hvSeries_DCMOCPSO, actualFE_DCMOCPSO, runtime_DCMOCPSO, meanSignal_DCMOCPSO, meanSwitchCount_DCMOCPSO, meanCoverageRatio_DCMOCPSO, objMetricSummary_DCMOCPSO] = runOrLoad( ...
    'DCMOCPSO', cacheFile_DCMOCPSO, n, ...
    @() runOneAlgorithm(@() DCMOCPSO('parameter', param_Full, 'outputFcn', @(~,~)[]), N, maxFE_DCMOCPSO, problemParameter_Lookahead), ...
    allowRunCachedGroups);

validFE_DCMOCPSO = loadAllActualFE(cacheFile_DCMOCPSO);
if isempty(validFE_DCMOCPSO)
    validFE_DCMOCPSO = actualFE_DCMOCPSO(~isnan(actualFE_DCMOCPSO));
end
if isempty(validFE_DCMOCPSO)
    competitorMaxFE = maxFE_DCMOCPSO;
    maxFE_BaseMOCPSO = maxFE_DCMOCPSO;
else
    competitorMaxFE = round(mean(validFE_DCMOCPSO));
    maxFE_BaseMOCPSO = max(1, round(competitorMaxFE / numSegments));
end

[hvLast_BaseMOCPSO, hvSeries_BaseMOCPSO, actualFE_BaseMOCPSO, runtime_BaseMOCPSO, meanSignal_BaseMOCPSO, meanSwitchCount_BaseMOCPSO, meanCoverageRatio_BaseMOCPSO, objMetricSummary_BaseMOCPSO] = runOrLoad( ...
    'Base-MOCPSO', cacheFile_BaseMOCPSO, n, ...
    @() runOneAlgorithm(@() DCMOCPSO('parameter', param_OneSeg, 'outputFcn', @(~,~)[]), N, maxFE_BaseMOCPSO, problemParameter_Lookahead), ...
    allowRunCachedGroups);

[hvLast_DGEA, hvSeries_DGEA, actualFE_DGEA, runtime_DGEA, meanSignal_DGEA, meanSwitchCount_DGEA, meanCoverageRatio_DGEA, objMetricSummary_DGEA] = runOrLoad( ...
    'DGEA', cacheFile_DGEA, n, ...
    @() runOneAlgorithm(@() DGEA('outputFcn', @(~,~)[]), N, competitorMaxFE, problemParameter_Lookahead), ...
    true);

[hvLast_IMMOEAD, hvSeries_IMMOEAD, actualFE_IMMOEAD, runtime_IMMOEAD, meanSignal_IMMOEAD, meanSwitchCount_IMMOEAD, meanCoverageRatio_IMMOEAD, objMetricSummary_IMMOEAD] = runOrLoad( ...
    'IMMOEAD', cacheFile_IMMOEAD, n, ...
    @() runOneAlgorithm(@() IMMOEAD('outputFcn', @(~,~)[]), N, competitorMaxFE, problemParameter_Lookahead), ...
    true);

% [hvLast_MMOPSO, hvSeries_MMOPSO, actualFE_MMOPSO, runtime_MMOPSO] = runOrLoad( ...
%     'MMOPSO', cacheFile_MMOPSO, n, ...
%     @() runOneAlgorithm(@() MMOPSO('outputFcn', @(~,~)[]), N, competitorMaxFE, problemParameter_Lookahead), ...
%     true);

%% Summary
groupNames = {'DCMOCPSO', 'Base-MOCPSO', 'IMMOEAD', 'DGEA'};
hvLastAll = {hvLast_DCMOCPSO, hvLast_BaseMOCPSO, hvLast_IMMOEAD, hvLast_DGEA};
actualFEAll = {actualFE_DCMOCPSO, actualFE_BaseMOCPSO, actualFE_IMMOEAD, actualFE_DGEA};
runtimeAll = {runtime_DCMOCPSO, runtime_BaseMOCPSO, runtime_IMMOEAD, runtime_DGEA};
meanSignalAll = {meanSignal_DCMOCPSO, meanSignal_BaseMOCPSO, meanSignal_IMMOEAD, meanSignal_DGEA};
meanSwitchCountAll = {meanSwitchCount_DCMOCPSO, meanSwitchCount_BaseMOCPSO, meanSwitchCount_IMMOEAD, meanSwitchCount_DGEA};
meanCoverageRatioAll = {meanCoverageRatio_DCMOCPSO, meanCoverageRatio_BaseMOCPSO, meanCoverageRatio_IMMOEAD, meanCoverageRatio_DGEA};
objMetricSummaryAll = {objMetricSummary_DCMOCPSO, objMetricSummary_BaseMOCPSO, objMetricSummary_IMMOEAD, objMetricSummary_DGEA};
maxFEAll = [maxFE_DCMOCPSO, maxFE_BaseMOCPSO, competitorMaxFE, competitorMaxFE];

meanHV = nan(1, numel(groupNames));
meanRuntime = nan(1, numel(groupNames));
meanActualFE = nan(1, numel(groupNames));
meanSignal = nan(1, numel(groupNames));
meanSwitchCount = nan(1, numel(groupNames));
meanCoverageRatio = nan(1, numel(groupNames));
validCount = zeros(1, numel(groupNames));

fprintf('\n=== Algorithm comparison summary (n=%d) ===\n', n);
fprintf('Competitor algorithms use maxFE=%d, estimated from all cached DCMOCPSO actualFE values.\n', competitorMaxFE);
for i = 1:numel(groupNames)
    validIdx = ~isnan(hvLastAll{i});
    validCount(i) = sum(validIdx);
    meanHV(i) = mean(hvLastAll{i}(validIdx));
    meanRuntime(i) = mean(runtimeAll{i}(validIdx));
    meanActualFE(i) = mean(actualFEAll{i}(validIdx));
    meanSignal(i) = meanValid(meanSignalAll{i}(validIdx));
    meanSwitchCount(i) = meanValid(meanSwitchCountAll{i}(validIdx));
    meanCoverageRatio(i) = meanValid(meanCoverageRatioAll{i}(validIdx));

    fprintf('%-12s : mean(last HV) = %.6e (valid=%d/%d, maxFE=%d, actualFE mean=%.1f, runtime mean=%.2fs, signal mean=%.4f, switch mean=%.4f, coverage mean=%.4f)\n', ...
        groupNames{i}, meanHV(i), validCount(i), n, maxFEAll(i), meanActualFE(i), meanRuntime(i), meanSignal(i), meanSwitchCount(i), meanCoverageRatio(i));
end

results = struct();
results.experimentName = 'DCMOCPSO_vs_baselines';
results.groupNames = groupNames;
results.hvLastAll = hvLastAll;
results.actualFEAll = actualFEAll;
results.runtimeAll = runtimeAll;
results.meanSignalAll = meanSignalAll;
results.meanSwitchCountAll = meanSwitchCountAll;
results.meanCoverageRatioAll = meanCoverageRatioAll;
results.objMetricSummaryAll = objMetricSummaryAll;
results.maxFEAll = maxFEAll;
results.meanHV = meanHV;
results.meanRuntime = meanRuntime;
results.meanActualFE = meanActualFE;
results.meanSignal = meanSignal;
results.meanSwitchCount = meanSwitchCount;
results.meanCoverageRatio = meanCoverageRatio;
results.validCount = validCount;
summaryFile = fullfile(cacheDir, 'DCMOCPSO_vs_baselines_summary.mat');
save(summaryFile, 'results');
fprintf('\nSummary saved to: %s\n', summaryFile);

%% Plot comparisons
colors = [
    0.20, 0.40, 0.80;  % DCMOCPSO
    0.90, 0.60, 0.10;  % Base-MOCPSO
    0.35, 0.55, 0.70;  % IMMOEAD
    0.75, 0.35, 0.20   % DGEA
];

plotBarComparison('HV comparison', 'Mean of last HV', 'Algorithm Comparison: HV Metric', ...
    groupNames, meanHV, colors, [200, 200, 760, 500], true);

plotBarComparison('Runtime comparison', 'Mean runtime (seconds)', 'Algorithm Comparison: Runtime', ...
    groupNames, meanRuntime, colors, [980, 200, 760, 500], false);


%% ===================== local functions =====================
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
            if loadCount >= n && all(~isnan(hvLast)) && all(~isnan(meanSignal)) && all(~isnan(meanSwitchCount)) && all(~isnan(meanCoverageRatio))
                return;
            end
        end
    end

    if ~allowRun
        fprintf('[%s] cache is missing or incomplete, and recomputation is disabled. Missing runs remain NaN.\n', algName);
        return;
    end

    startRun = find(isnan(hvLast) | isnan(meanSignal) | isnan(meanSwitchCount) | isnan(meanCoverageRatio), 1);
    if isempty(startRun)
        return;
    end

    fprintf('[%s] cache miss/incomplete -> run %d time(s)\n', algName, n - startRun + 1);
    runs = struct('hv', {}, 'actualFE', {}, 'runtime', {}, 'meanSignal', {}, 'meanSwitchCount', {}, 'meanCoverageRatio', {}, 'objMetricSummary', {});
    if exist(cacheFile, 'file') == 2
        S = load(cacheFile);
        if isfield(S, 'runs')
            runs = S.runs;
        end
    end

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
        catch ME
            fprintf('  Run %d/%d FAILED: %s\n', i, n, ME.message);
        end
    end
end

function actualFE = loadAllActualFE(cacheFile)
    actualFE = [];
    if exist(cacheFile, 'file') ~= 2
        return;
    end

    S = load(cacheFile);
    if ~isfield(S, 'runs')
        return;
    end

    runs = S.runs;
    for i = 1:numel(runs)
        if isfield(runs, 'actualFE') && ~isempty(runs(i).actualFE) && ~isnan(runs(i).actualFE)
            actualFE(end+1) = runs(i).actualFE; %#ok<AGROW>
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

    warmup = zeros(1, pool.NumWorkers);
    parfor i = 1:pool.NumWorkers
        warmup(i) = i;
    end
    fprintf('[Parallel] Pool ready with %d worker(s).\n', pool.NumWorkers);
end

function [hv, actualFE, runtime, objMetricSummary, Algorithm, Problem] = runOneAlgorithm(createAlgorithmFn, N, maxFE, problemParameter)
    Algorithm = createAlgorithmFn();
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
    if isempty(Algorithm.result)
        return;
    end

    finalPopulation = Algorithm.result{end, 2};
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

function plotBarComparison(figName, yLabelText, titleText, groupNames, values, colors, position, smartYLim)
    figure('Name', figName, 'Position', position);
    x = categorical(groupNames);
    x = reordercats(x, groupNames);

    b = bar(x, values);
    b.FaceColor = 'flat';
    for i = 1:size(colors, 1)
        b.CData(i,:) = colors(i,:);
    end

    ylabel(yLabelText, 'FontSize', 12, 'FontWeight', 'bold');
    title(titleText, 'FontSize', 14, 'FontWeight', 'bold');
    grid on;

    if smartYLim
        validValues = values(~isnan(values));
        if ~isempty(validValues)
            vMin = min(validValues);
            vMax = max(validValues);
            vRange = vMax - vMin;
            if vRange > 0
                margin = vRange * 0.15;
                ylim([vMin - margin, vMax + margin]);
            elseif vMin ~= 0
                ylim([vMin * 0.95, vMin * 1.05]);
            end
        end
    end
end
