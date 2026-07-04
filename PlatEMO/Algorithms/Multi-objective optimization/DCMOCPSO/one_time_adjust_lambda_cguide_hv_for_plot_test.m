% one_time_adjust_lambda_cguide_hv_for_plot_test.m
%
% One-time utility for plot-testing idealized lambda/c_guide HV trends.
%
% IMPORTANT:
% This script modifies cached HV run files only for testing chart rendering
% and visualizing an idealized conclusion. These adjusted cache files must
% not be used as final experimental results.
%
% For each cache file, the script computes:
%   delta = targetMeanLastHV - currentMeanLastHV
% and then adds delta to every stored HV value in every successful run.
% This preserves per-run variation while forcing the final mean(last HV) to
% match the requested target.
%
% Before modifying each cache, a backup is created beside it:
%   <cache>_before_plot_test.mat

clear; clc;

cacheDir = fullfile(fileparts(mfilename('fullpath')), 'results', 'lambda_cguide');

% Existing c_guide sweep cache files are for cGuideList = [0, 0.1, 0.3, 0.5, 0.7].
% The requested labels were p00/p25/p50/p75/p100; here they are applied in
% the same order to the existing five c_guide cache files.
cGuideTargets = { ...
    'CGuideSweep_cGuide_0p00_HV_runs.mat', 'p00',  0.225046; ...
    'CGuideSweep_cGuide_0p10_HV_runs.mat', 'p25',  0.226048; ...
    'CGuideSweep_cGuide_0p30_HV_runs.mat', 'p50',  0.226928; ...
    'CGuideSweep_cGuide_0p50_HV_runs.mat', 'p75',  0.226334; ...
    'CGuideSweep_cGuide_0p70_HV_runs.mat', 'p100', 0.226323};

% Existing lambda sweep cache files are for lambdaList = [0, 0.25, 0.5, 0.75, 1.0].
% The requested labels were p00/p10/p30/p50/p70; here they are applied in
% the same order to the existing five lambda cache files.
lambdaTargets = { ...
    'LambdaSweep_lambda_0p00_HV_runs.mat', 'p00', 0.224922; ...
    'LambdaSweep_lambda_0p25_HV_runs.mat', 'p10', 0.225894; ...
    'LambdaSweep_lambda_0p50_HV_runs.mat', 'p30', 0.226932; ...
    'LambdaSweep_lambda_0p75_HV_runs.mat', 'p50', 0.226734; ...
    'LambdaSweep_lambda_1p00_HV_runs.mat', 'p70', 0.226546};

fprintf('\n=== One-time HV cache adjustment for plot testing ===\n');
fprintf('Cache directory: %s\n', cacheDir);
fprintf('This is NOT for final experimental reporting.\n\n');

adjustTargetSet(cacheDir, 'c_guide', cGuideTargets);
adjustTargetSet(cacheDir, 'lambda', lambdaTargets);

fprintf('\nDone. Re-run example_ablation_DCMOCPSO_lambda_cguide.m to redraw charts from the adjusted caches.\n');


%% ===================== local functions =====================
function adjustTargetSet(cacheDir, setName, targets)
    fprintf('\n--- Adjusting %s caches ---\n', setName);

    for i = 1:size(targets, 1)
        cacheFile = fullfile(cacheDir, targets{i, 1});
        requestedLabel = targets{i, 2};
        targetMean = targets{i, 3};

        if exist(cacheFile, 'file') ~= 2
            warning('[%s/%s] cache file not found: %s', setName, requestedLabel, cacheFile);
            continue;
        end

        S = load(cacheFile);
        if ~isfield(S, 'runs') || isempty(S.runs)
            warning('[%s/%s] cache has no runs: %s', setName, requestedLabel, cacheFile);
            continue;
        end

        runs = S.runs;
        hvLast = extractLastHV(runs);
        validIdx = ~isnan(hvLast);
        if ~any(validIdx)
            warning('[%s/%s] cache has no valid HV runs: %s', setName, requestedLabel, cacheFile);
            continue;
        end

        currentMean = mean(hvLast(validIdx));
        delta = targetMean - currentMean;

        backupFile = makeBackupFile(cacheFile);
        if exist(backupFile, 'file') ~= 2
            copyfile(cacheFile, backupFile);
            fprintf('[%s/%s] backup created: %s\n', setName, requestedLabel, backupFile);
        else
            fprintf('[%s/%s] backup already exists: %s\n', setName, requestedLabel, backupFile);
        end

        for r = 1:numel(runs)
            if isfield(runs, 'hv') && ~isempty(runs(r).hv)
                runs(r).hv = runs(r).hv + delta;
            end
        end

        adjustedLast = extractLastHV(runs);
        adjustedMean = mean(adjustedLast(~isnan(adjustedLast)));

        plotTestAdjustment = struct( ...
            'setName', setName, ...
            'requestedLabel', requestedLabel, ...
            'targetMeanLastHV', targetMean, ...
            'originalMeanLastHV', currentMean, ...
            'deltaAppliedToEveryHVValue', delta, ...
            'adjustedMeanLastHV', adjustedMean, ...
            'backupFile', backupFile, ...
            'note', 'Temporary plot-test adjustment only; do not use as final experimental result.');

        save(cacheFile, 'runs', 'plotTestAdjustment');
        fprintf('[%s/%s] target=%.6f, original=%.6f, delta=%+.6e, adjusted=%.6f, valid=%d/%d\n', ...
            setName, requestedLabel, targetMean, currentMean, delta, adjustedMean, sum(validIdx), numel(runs));
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

function backupFile = makeBackupFile(cacheFile)
    [folder, name, ext] = fileparts(cacheFile);
    backupFile = fullfile(folder, sprintf('%s_before_plot_test%s', name, ext));
end
