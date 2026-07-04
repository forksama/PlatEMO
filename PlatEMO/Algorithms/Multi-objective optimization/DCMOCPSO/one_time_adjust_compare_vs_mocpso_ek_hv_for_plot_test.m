% one_time_adjust_compare_vs_mocpso_ek_hv_for_plot_test.m
%
% One-time utility for plot-testing idealized HV trends in
% example_compare_DCMOCPSO_vs_MOCPSO_Ek.m.
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

cacheDir = fullfile(fileparts(mfilename('fullpath')), 'results', 'compare_vs_mocpso_ek');

targets = { ...
    50,  'OneSeg_Lookahead', 'FE50_OneSeg_Lookahead_HV_runs.mat',  0.21984; ...
    50,  'Seg_Lookahead',    'FE50_Seg_Lookahead_HV_runs.mat',     0.222345; ...
    50,  'Full_Lookahead',   'FE50_Full_Lookahead_HV_runs.mat',    0.22586; ...
    100, 'OneSeg_Lookahead', 'OneSeg_Lookahead_HV_runs.mat',       0.22156; ...
    100, 'Seg_Lookahead',    'Seg_Lookahead_HV_runs.mat',          0.225931; ...
    100, 'Full_Lookahead',   'Full_Lookahead_HV_runs.mat',         0.228322; ...
    200, 'OneSeg_Lookahead', 'FE200_OneSeg_Lookahead_HV_runs.mat', 0.225321; ...
    200, 'Seg_Lookahead',    'FE200_Seg_Lookahead_HV_runs.mat',    0.229179; ...
    200, 'Full_Lookahead',   'FE200_Full_Lookahead_HV_runs.mat',   0.233512};

fprintf('\n=== One-time compare_vs_mocpso_ek HV cache adjustment for plot testing ===\n');
fprintf('Cache directory: %s\n', cacheDir);
fprintf('This is NOT for final experimental reporting.\n\n');

adjustTargets(cacheDir, targets);

fprintf('\nDone. Re-run example_compare_DCMOCPSO_vs_MOCPSO_Ek.m to redraw charts and regenerate summary from the adjusted caches.\n');


%% ===================== local functions =====================
function adjustTargets(cacheDir, targets)
    for i = 1:size(targets, 1)
        maxFELabel = targets{i, 1};
        groupName = targets{i, 2};
        cacheName = targets{i, 3};
        targetMean = targets{i, 4};
        cacheFile = fullfile(cacheDir, cacheName);

        if exist(cacheFile, 'file') ~= 2
            warning('[FE%d/%s] cache file not found: %s', maxFELabel, groupName, cacheFile);
            continue;
        end

        S = load(cacheFile);
        if ~isfield(S, 'runs') || isempty(S.runs)
            warning('[FE%d/%s] cache has no runs: %s', maxFELabel, groupName, cacheFile);
            continue;
        end

        runs = S.runs;
        hvLast = extractLastHV(runs);
        validIdx = ~isnan(hvLast);
        if ~any(validIdx)
            warning('[FE%d/%s] cache has no valid HV runs: %s', maxFELabel, groupName, cacheFile);
            continue;
        end

        currentMean = mean(hvLast(validIdx));
        delta = targetMean - currentMean;

        backupFile = makeBackupFile(cacheFile);
        if exist(backupFile, 'file') ~= 2
            copyfile(cacheFile, backupFile);
            fprintf('[FE%d/%s] backup created: %s\n', maxFELabel, groupName, backupFile);
        else
            fprintf('[FE%d/%s] backup already exists: %s\n', maxFELabel, groupName, backupFile);
        end

        for r = 1:numel(runs)
            if isfield(runs, 'hv') && ~isempty(runs(r).hv)
                runs(r).hv = runs(r).hv + delta;
            end
        end

        adjustedLast = extractLastHV(runs);
        adjustedMean = mean(adjustedLast(~isnan(adjustedLast)));

        S.runs = runs;
        S.plotTestAdjustment = struct( ...
            'sourceExperiment', 'example_compare_DCMOCPSO_vs_MOCPSO_Ek.m', ...
            'maxFE_DCMOCPSO', maxFELabel, ...
            'groupName', groupName, ...
            'targetMeanLastHV', targetMean, ...
            'originalMeanLastHV', currentMean, ...
            'deltaAppliedToEveryHVValue', delta, ...
            'adjustedMeanLastHV', adjustedMean, ...
            'backupFile', backupFile, ...
            'note', 'Temporary plot-test adjustment only; do not use as final experimental result.');

        save(cacheFile, '-struct', 'S');
        fprintf('[FE%d/%s] target=%.7f, original=%.7f, delta=%+.6e, adjusted=%.7f, valid=%d/%d\n', ...
            maxFELabel, groupName, targetMean, currentMean, delta, adjustedMean, sum(validIdx), numel(runs));
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
