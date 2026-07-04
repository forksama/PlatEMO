% one_time_adjust_lookahead_margins_last_metrics_hv_for_plot_test.m
%
% One-time utility for plot-testing idealized metric/HV trends in
% example_ablation_DCMOCPSO_lookaheadMargins.m.
%
% IMPORTANT:
% This script modifies cached metric and HV run files only for testing chart
% rendering and visualizing an idealized conclusion. These adjusted cache
% files must not be used as final experimental results.
%
% The request repeated lookaheadSafetyMarginList twice. Based on the prior
% mechanism discussion, this script maps the two requested patterns to the
% last safety-margin group and the last hysteresis-range group:
%   safety_8dB: signal -0.15, coverage -0.01
%   hyst_20dB : signal -0.13, switch count -0.04, coverage -0.01
%
% The existing cache stores per-run aggregate metrics and HV histories, but
% not the final population objective matrix required by the real PlatEMO HV
% metric. Therefore, the script recalculates a plot-test proxy HV from the
% adjusted aggregate metrics and scales each stored HV history by the proxy
% HV ratio. This is only for idealized chart inspection.
%
% Before modifying each cache, a backup is created beside it:
%   <cache>_before_plot_test.mat

clear; clc;

cacheDir = fullfile(fileparts(mfilename('fullpath')), 'results', 'lookahead_margins_oneseg');

targets = { ...
    struct( ...
        'setName', 'lookaheadSafetyMargin', ...
        'requestedLabel', 'last_8dB', ...
        'cacheName', 'LookaheadSafetyOneSegSweep_safety_8dB_HV_runs.mat', ...
        'deltaSignal', -0.15, ...
        'deltaSwitch', 0, ...
        'deltaCoverage', -0.01); ...
    struct( ...
        'setName', 'lookaheadHysteresisRange', ...
        'requestedLabel', 'last_20dB', ...
        'cacheName', 'LookaheadHysteresisOneSegSweep_hyst_20dB_HV_runs.mat', ...
        'deltaSignal', -0.13, ...
        'deltaSwitch', -0.04, ...
        'deltaCoverage', -0.01)};

fprintf('\n=== One-time lookahead margins last-group metric/HV adjustment for plot testing ===\n');
fprintf('Cache directory: %s\n', cacheDir);
fprintf('This is NOT for final experimental reporting.\n\n');

adjustTargets(cacheDir, targets);

fprintf('\nDone. Re-run example_ablation_DCMOCPSO_lookaheadMargins.m to redraw charts and regenerate summaries from the adjusted caches.\n');


%% ===================== local functions =====================
function adjustTargets(cacheDir, targets)
    for i = 1:numel(targets)
        target = targets{i};
        cacheFile = fullfile(cacheDir, target.cacheName);

        if exist(cacheFile, 'file') ~= 2
            warning('[%s/%s] cache file not found: %s', target.setName, target.requestedLabel, cacheFile);
            continue;
        end

        S = load(cacheFile);
        if ~isfield(S, 'runs') || isempty(S.runs)
            warning('[%s/%s] cache has no runs: %s', target.setName, target.requestedLabel, cacheFile);
            continue;
        end

        runs = S.runs;
        backupFile = makeBackupFile(cacheFile);
        if exist(backupFile, 'file') ~= 2
            copyfile(cacheFile, backupFile);
            fprintf('[%s/%s] backup created: %s\n', target.setName, target.requestedLabel, backupFile);
        else
            fprintf('[%s/%s] backup already exists: %s\n', target.setName, target.requestedLabel, backupFile);
        end

        originalLastHV = extractLastHV(runs);
        originalSignal = extractField(runs, 'meanSignal');
        originalSwitch = extractField(runs, 'meanSwitchCount');
        originalCoverage = extractField(runs, 'meanCoverageRatio');

        for r = 1:numel(runs)
            originalMetrics = readRunMetrics(runs(r));
            adjustedMetrics = adjustRunMetrics(originalMetrics, target);
            hvRatio = recalculateProxyHVRatio(originalMetrics, adjustedMetrics);

            if isfield(runs, 'meanSignal')
                runs(r).meanSignal = adjustedMetrics.meanSignal;
            end
            if isfield(runs, 'meanSwitchCount')
                runs(r).meanSwitchCount = adjustedMetrics.meanSwitchCount;
            end
            if isfield(runs, 'meanCoverageRatio')
                runs(r).meanCoverageRatio = adjustedMetrics.meanCoverageRatio;
            end
            if isfield(runs, 'objMetricSummary') && ~isempty(runs(r).objMetricSummary)
                runs(r).objMetricSummary.meanSignal = adjustedMetrics.meanSignal;
                runs(r).objMetricSummary.meanSwitchCount = adjustedMetrics.meanSwitchCount;
                runs(r).objMetricSummary.meanCoverageRatio = adjustedMetrics.meanCoverageRatio;
            end
            if isfield(runs, 'hv') && ~isempty(runs(r).hv) && isfinite(hvRatio)
                runs(r).hv = runs(r).hv * hvRatio;
            end
        end

        adjustedLastHV = extractLastHV(runs);
        adjustedSignal = extractField(runs, 'meanSignal');
        adjustedSwitch = extractField(runs, 'meanSwitchCount');
        adjustedCoverage = extractField(runs, 'meanCoverageRatio');

        S.runs = runs;
        S.plotTestAdjustment = struct( ...
            'sourceExperiment', 'example_ablation_DCMOCPSO_lookaheadMargins.m', ...
            'setName', target.setName, ...
            'requestedLabel', target.requestedLabel, ...
            'deltaSignal', target.deltaSignal, ...
            'deltaSwitch', target.deltaSwitch, ...
            'deltaCoverage', target.deltaCoverage, ...
            'originalMeanLastHV', meanValid(originalLastHV), ...
            'adjustedMeanLastHV', meanValid(adjustedLastHV), ...
            'originalMeanSignal', meanValid(originalSignal), ...
            'adjustedMeanSignal', meanValid(adjustedSignal), ...
            'originalMeanSwitchCount', meanValid(originalSwitch), ...
            'adjustedMeanSwitchCount', meanValid(adjustedSwitch), ...
            'originalMeanCoverageRatio', meanValid(originalCoverage), ...
            'adjustedMeanCoverageRatio', meanValid(adjustedCoverage), ...
            'backupFile', backupFile, ...
            'note', 'Temporary plot-test adjustment only; do not use as final experimental result.');

        save(cacheFile, '-struct', 'S');
        fprintf(['[%s/%s] HV mean %.6f -> %.6f | signal %.4f -> %.4f | ' ...
            'switch %.4f -> %.4f | coverage %.4f -> %.4f | validHV=%d/%d\n'], ...
            target.setName, target.requestedLabel, ...
            S.plotTestAdjustment.originalMeanLastHV, S.plotTestAdjustment.adjustedMeanLastHV, ...
            S.plotTestAdjustment.originalMeanSignal, S.plotTestAdjustment.adjustedMeanSignal, ...
            S.plotTestAdjustment.originalMeanSwitchCount, S.plotTestAdjustment.adjustedMeanSwitchCount, ...
            S.plotTestAdjustment.originalMeanCoverageRatio, S.plotTestAdjustment.adjustedMeanCoverageRatio, ...
            sum(~isnan(adjustedLastHV)), numel(runs));
    end
end

function metrics = readRunMetrics(run)
    metrics = struct('meanSignal', NaN, 'meanSwitchCount', NaN, 'meanCoverageRatio', NaN);
    if isfield(run, 'meanSignal') && ~isempty(run.meanSignal)
        metrics.meanSignal = run.meanSignal;
    elseif isfield(run, 'objMetricSummary') && ~isempty(run.objMetricSummary) && isfield(run.objMetricSummary, 'meanSignal')
        metrics.meanSignal = run.objMetricSummary.meanSignal;
    end
    if isfield(run, 'meanSwitchCount') && ~isempty(run.meanSwitchCount)
        metrics.meanSwitchCount = run.meanSwitchCount;
    elseif isfield(run, 'objMetricSummary') && ~isempty(run.objMetricSummary) && isfield(run.objMetricSummary, 'meanSwitchCount')
        metrics.meanSwitchCount = run.objMetricSummary.meanSwitchCount;
    end
    if isfield(run, 'meanCoverageRatio') && ~isempty(run.meanCoverageRatio)
        metrics.meanCoverageRatio = run.meanCoverageRatio;
    elseif isfield(run, 'objMetricSummary') && ~isempty(run.objMetricSummary) && isfield(run.objMetricSummary, 'meanCoverageRatio')
        metrics.meanCoverageRatio = run.objMetricSummary.meanCoverageRatio;
    end
end

function adjusted = adjustRunMetrics(metrics, target)
    adjusted = metrics;
    adjusted.meanSignal = metrics.meanSignal + target.deltaSignal;
    adjusted.meanSwitchCount = max(0, metrics.meanSwitchCount + target.deltaSwitch);
    adjusted.meanCoverageRatio = min(1, max(0, metrics.meanCoverageRatio + target.deltaCoverage));
end

function hvRatio = recalculateProxyHVRatio(originalMetrics, adjustedMetrics)
    originalProxyHV = proxyHVFromMetrics(originalMetrics);
    adjustedProxyHV = proxyHVFromMetrics(adjustedMetrics);
    if isnan(originalProxyHV) || originalProxyHV <= 0 || isnan(adjustedProxyHV)
        hvRatio = 1;
    else
        hvRatio = max(0, adjustedProxyHV / originalProxyHV);
    end
end

function score = proxyHVFromMetrics(metrics)
    if any(isnan([metrics.meanSignal, metrics.meanSwitchCount, metrics.meanCoverageRatio]))
        score = NaN;
        return;
    end

    signalScore = clamp((metrics.meanSignal + 120) / 70, 0, 1);
    switchScore = clamp(1 - metrics.meanSwitchCount / 30, 0, 1);
    coverageScore = clamp(metrics.meanCoverageRatio, 0, 1);
    score = signalScore * switchScore * coverageScore;
end

function values = extractField(runs, fieldName)
    values = nan(1, numel(runs));
    for i = 1:numel(runs)
        if isfield(runs, fieldName) && ~isempty(runs(i).(fieldName))
            values(i) = runs(i).(fieldName);
        end
    end
end

function hvLast = extractLastHV(runs)
    hvLast = nan(1, numel(runs));
    for i = 1:numel(runs)
        if isfield(runs, 'hv') && ~isempty(runs(i).hv)
            hvLast(i) = runs(i).hv(end);
        end
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

function value = clamp(value, lowerBound, upperBound)
    value = min(upperBound, max(lowerBound, value));
end

function backupFile = makeBackupFile(cacheFile)
    [folder, name, ext] = fileparts(cacheFile);
    backupFile = fullfile(folder, sprintf('%s_before_plot_test%s', name, ext));
end
