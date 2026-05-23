% example_ablation_DCMOCPSO_lambda_cguide.m
%
% One-factor ablation/sensitivity study for lambda and c_guide in DCMOCPSO.
%
% Experiment 1: lambda sweep with c_guide fixed at 0.3
%   lambdaList = [0, 0.25, 0.5, 0.75, 1.0]
%
% Experiment 2: c_guide sweep with lambda fixed at 0.5
%   cGuideList = [0, 0.1, 0.3, 0.5, 0.7]
%
% Each parameter setting is cached independently. After every successful
% independent run, the corresponding cache file is saved immediately.

clear; clc; close all;

%% Settings
n = 10;

% Start and warm up the parallel pool before per-run timing begins, so the
% parpool startup cost is not counted in any algorithm runtime.
enableParallelPool = true;
parallelPoolProfile = 'Processes';
parallelPoolNumWorkers = [];
prepareParallelPool(enableParallelPool, parallelPoolProfile, parallelPoolNumWorkers);

% UAVPathPlanning parameters.
N = 20;
problemParameter_Lookahead = {20, 20, 5, -101.5, 0, 30, 2, 500};

% DCMOCPSO common settings.
maxFE_DCMOCPSO = 100;
numSegments = 5;
segmentOverlap = 2;
useDynamicGrouping = true;
useDynamicMutation = true;
useEk = true;
uniformPointMultiplier = 3;

% Ablation values requested for the two one-factor experiments.
lambdaList = [0, 0.25, 0.5, 0.75, 1.0];
cGuideList = [0, 0.1, 0.3, 0.5, 0.7];
fixedLambda = 0.5;
fixedCGuide = 0.3;

% Result cache. Use experiment-specific files to avoid mixing with older
% DCMOCPSO ablation caches.
cacheDir = fullfile(fileparts(mfilename('fullpath')), 'results');
if exist(cacheDir, 'dir') ~= 7
    mkdir(cacheDir);
end

commonConfig = struct( ...
    'N', N, ...
    'maxFE', maxFE_DCMOCPSO, ...
    'problemParameter', {problemParameter_Lookahead}, ...
    'numSegments', numSegments, ...
    'segmentOverlap', segmentOverlap, ...
    'useDynamicGrouping', useDynamicGrouping, ...
    'useDynamicMutation', useDynamicMutation, ...
    'useEk', useEk, ...
    'uniformPointMultiplier', uniformPointMultiplier);

%% Experiment 1: lambda sweep
lambdaGroupNames = arrayfun(@(v) sprintf('lambda_%s', valueTag(v)), lambdaList, 'UniformOutput', false);
lambdaGroupParams = cell(1, numel(lambdaList));
for i = 1:numel(lambdaList)
    lambdaGroupParams{i} = makeDCMOCPSOParam(commonConfig, lambdaList(i), fixedCGuide);
end

lambdaResults = runExperimentSet( ...
    'LambdaSweep', lambdaGroupNames, lambdaGroupParams, lambdaList, ...
    'lambda', fixedCGuide, 'c_guide', cacheDir, n, commonConfig);

%% Experiment 2: c_guide sweep
cGuideGroupNames = arrayfun(@(v) sprintf('cGuide_%s', valueTag(v)), cGuideList, 'UniformOutput', false);
cGuideGroupParams = cell(1, numel(cGuideList));
for i = 1:numel(cGuideList)
    cGuideGroupParams{i} = makeDCMOCPSOParam(commonConfig, fixedLambda, cGuideList(i));
end

cGuideResults = runExperimentSet( ...
    'CGuideSweep', cGuideGroupNames, cGuideGroupParams, cGuideList, ...
    'c_guide', fixedLambda, 'lambda', cacheDir, n, commonConfig);

%% Save combined summary
combinedSummaryFile = fullfile(cacheDir, 'LambdaCGuide_sweep_summary.mat');
save(combinedSummaryFile, 'lambdaResults', 'cGuideResults', 'lambdaList', 'cGuideList', ...
    'fixedLambda', 'fixedCGuide', 'n', 'commonConfig');
fprintf('\nCombined summary saved to: %s\n', combinedSummaryFile);

%% Plot comparisons
colorsLambda = lines(numel(lambdaList));
colorsCGuide = lines(numel(cGuideList));

plotBarComparison('lambda sweep HV', 'Mean of last HV', ...
    sprintf('DCMOCPSO lambda sweep: c\\_guide = %.2f', fixedCGuide), ...
    lambdaGroupNames, lambdaResults.meanHV, lambdaResults.stdHV, colorsLambda, [200, 200, 860, 520], true);

plotBarComparison('lambda sweep runtime', 'Mean runtime (seconds)', ...
    sprintf('DCMOCPSO lambda sweep runtime: c\\_guide = %.2f', fixedCGuide), ...
    lambdaGroupNames, lambdaResults.meanRuntime, lambdaResults.stdRuntime, colorsLambda, [1120, 200, 860, 520], false);

plotBarComparison('c_guide sweep HV', 'Mean of last HV', ...
    sprintf('DCMOCPSO c\\_guide sweep: lambda = %.2f', fixedLambda), ...
    cGuideGroupNames, cGuideResults.meanHV, cGuideResults.stdHV, colorsCGuide, [200, 780, 860, 520], true);

plotBarComparison('c_guide sweep runtime', 'Mean runtime (seconds)', ...
    sprintf('DCMOCPSO c\\_guide sweep runtime: lambda = %.2f', fixedLambda), ...
    cGuideGroupNames, cGuideResults.meanRuntime, cGuideResults.stdRuntime, colorsCGuide, [1120, 780, 860, 520], false);


%% ===================== local functions =====================
function results = runExperimentSet(experimentName, groupNames, groupParams, sweptValues, sweptParamName, fixedValue, fixedParamName, cacheDir, n, commonConfig)
    numGroups = numel(groupNames);
    hvLastAll = cell(1, numGroups);
    hvSeriesAll = cell(1, numGroups);
    actualFEAll = cell(1, numGroups);
    runtimeAll = cell(1, numGroups);

    fprintf('\n=== %s (n=%d) ===\n', experimentName, n);
    fprintf('Common settings: N=%d, maxFE=%d, numSegments=%d, segmentOverlap=%d, uniformPointMultiplier=%d\n', ...
        commonConfig.N, commonConfig.maxFE, commonConfig.numSegments, commonConfig.segmentOverlap, commonConfig.uniformPointMultiplier);
    fprintf('Sweeping %s; fixed %s = %.4g\n', sweptParamName, fixedParamName, fixedValue);

    for i = 1:numGroups
        cacheFile = fullfile(cacheDir, sprintf('%s_%s_HV_runs.mat', experimentName, groupNames{i}));
        [hvLastAll{i}, hvSeriesAll{i}, actualFEAll{i}, runtimeAll{i}] = runOrLoad( ...
            sprintf('%s/%s', experimentName, groupNames{i}), cacheFile, n, ...
            @() runOne_DCMOCPSO(commonConfig.N, commonConfig.maxFE, commonConfig.problemParameter, groupParams{i}), ...
            true);
    end

    meanHV = nan(1, numGroups);
    stdHV = nan(1, numGroups);
    meanRuntime = nan(1, numGroups);
    stdRuntime = nan(1, numGroups);
    meanActualFE = nan(1, numGroups);
    validCount = zeros(1, numGroups);

    fprintf('\n--- %s summary ---\n', experimentName);
    for i = 1:numGroups
        validIdx = ~isnan(hvLastAll{i});
        validCount(i) = sum(validIdx);
        meanHV(i) = mean(hvLastAll{i}(validIdx));
        stdHV(i) = std(hvLastAll{i}(validIdx));
        meanRuntime(i) = mean(runtimeAll{i}(validIdx));
        stdRuntime(i) = std(runtimeAll{i}(validIdx));
        meanActualFE(i) = mean(actualFEAll{i}(validIdx));

        fprintf('%-16s : %s=%.4g, mean(last HV)=%.6e, std=%.6e (valid=%d/%d, actualFE mean=%.1f, runtime mean=%.2fs, std=%.2fs)\n', ...
            groupNames{i}, sweptParamName, sweptValues(i), meanHV(i), stdHV(i), validCount(i), n, meanActualFE(i), meanRuntime(i), stdRuntime(i));
    end

    results = struct();
    results.experimentName = experimentName;
    results.groupNames = groupNames;
    results.groupParams = groupParams;
    results.sweptParamName = sweptParamName;
    results.sweptValues = sweptValues;
    results.fixedParamName = fixedParamName;
    results.fixedValue = fixedValue;
    results.hvLastAll = hvLastAll;
    results.hvSeriesAll = hvSeriesAll;
    results.actualFEAll = actualFEAll;
    results.runtimeAll = runtimeAll;
    results.meanHV = meanHV;
    results.stdHV = stdHV;
    results.meanRuntime = meanRuntime;
    results.stdRuntime = stdRuntime;
    results.meanActualFE = meanActualFE;
    results.validCount = validCount;

    summaryFile = fullfile(cacheDir, sprintf('%s_summary.mat', experimentName));
    save(summaryFile, 'results');
    fprintf('%s summary saved to: %s\n', experimentName, summaryFile);
end

function param = makeDCMOCPSOParam(commonConfig, lambda, cGuide)
    param = { ...
        commonConfig.numSegments, ...
        commonConfig.segmentOverlap, ...
        lambda, ...
        cGuide, ...
        commonConfig.useDynamicGrouping, ...
        commonConfig.useDynamicMutation, ...
        commonConfig.useEk, ...
        commonConfig.uniformPointMultiplier};
end

function tag = valueTag(value)
    tag = strrep(sprintf('%.2f', value), '.', 'p');
end

function [hvLast, hvSeries, actualFE, runtime, lastAlgorithm, lastProblem] = runOrLoad(algName, cacheFile, n, runOneFn, allowRun)
    hvLast = nan(1,n);
    hvSeries = cell(1,n);
    actualFE = nan(1,n);
    runtime = nan(1,n);
    lastAlgorithm = [];
    lastProblem = [];

    runs = struct('hv', {}, 'actualFE', {}, 'runtime', {});
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

    startRun = find(isnan(hvLast), 1);
    if isempty(startRun)
        return;
    end

    fprintf('[%s] cache miss/incomplete -> run %d time(s)\n', algName, n - startRun + 1);

    for i = startRun:n
        fprintf('\n>>> Current algorithm: %s\n', algName);
        fprintf('  Run %d/%d...\n', i, n);
        try
            [hvSeries{i}, actualFE(i), runtime(i), lastAlgorithm, lastProblem] = runOneFn();
            hvLast(i) = hvSeries{i}(end);
            runs(i).hv = hvSeries{i};
            runs(i).actualFE = actualFE(i);
            runs(i).runtime = runtime(i);
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

    warmup = zeros(1, pool.NumWorkers);
    parfor i = 1:pool.NumWorkers
        warmup(i) = i;
    end
    fprintf('[Parallel] Pool ready with %d worker(s).\n', pool.NumWorkers);
end

function [hv, actualFE, runtime, Algorithm, Problem] = runOne_DCMOCPSO(N, maxFE, problemParameter, param_DCMOCPSO)
    Algorithm = DCMOCPSO('parameter', param_DCMOCPSO, 'outputFcn', @(~,~)[]);
    Problem = UAVPathPlanning('N', N, 'maxFE', maxFE, 'parameter', problemParameter);
    tStart = tic;
    Algorithm.Solve(Problem);
    runtime = toc(tStart);
    hv = extractHV(Algorithm);
    actualFE = Problem.FE;
end

function hv = extractHV(Algorithm)
    m = Algorithm.Metric('HV');
    hv = m(:,2)';
    if isempty(hv)
        error('No HV metric captured. Ensure Problem.M>1 and Algorithm saved results.');
    end
end

function plotBarComparison(figName, yLabelText, titleText, groupNames, values, errors, colors, position, smartYLim)
    figure('Name', figName, 'Position', position);
    x = categorical(groupNames);
    x = reordercats(x, groupNames);

    b = bar(x, values);
    b.FaceColor = 'flat';
    for i = 1:size(colors, 1)
        b.CData(i,:) = colors(i,:);
    end
    hold on;

    xPos = 1:numel(groupNames);
    errorbar(xPos, values, errors, 'k.', 'LineWidth', 1.1, 'CapSize', 10);

    ylabel(yLabelText, 'FontSize', 12, 'FontWeight', 'bold');
    title(titleText, 'FontSize', 14, 'FontWeight', 'bold');
    grid on;
    xtickangle(20);

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
                ylim([vMin - margin, vMax + margin]);
            elseif vMin ~= 0
                ylim([vMin * 0.95, vMin * 1.05]);
            end
        end
    end
end
