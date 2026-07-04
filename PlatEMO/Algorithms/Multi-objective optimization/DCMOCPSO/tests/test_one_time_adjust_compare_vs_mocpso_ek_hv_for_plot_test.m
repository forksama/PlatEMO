function tests = test_one_time_adjust_compare_vs_mocpso_ek_hv_for_plot_test
% Static checks for the one-time compare_vs_mocpso_ek HV plot-test adjuster.
tests = functiontests(localfunctions);
end

function testTargetsAndCacheFilesAreConfigured(testCase)
scriptText = readAdjustScript();

verifyNotEmpty(testCase, regexp(scriptText, ...
    'FE50_OneSeg_Lookahead_HV_runs\.mat''\s*,\s*0\.21984', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    'FE50_Seg_Lookahead_HV_runs\.mat''\s*,\s*0\.222345', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    'FE50_Full_Lookahead_HV_runs\.mat''\s*,\s*0\.22586', 'once'));

verifyNotEmpty(testCase, regexp(scriptText, ...
    'OneSeg_Lookahead_HV_runs\.mat''\s*,\s*0\.22156', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    'Seg_Lookahead_HV_runs\.mat''\s*,\s*0\.225931', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    'Full_Lookahead_HV_runs\.mat''\s*,\s*0\.228322', 'once'));

verifyNotEmpty(testCase, regexp(scriptText, ...
    'FE200_OneSeg_Lookahead_HV_runs\.mat''\s*,\s*0\.225321', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    'FE200_Seg_Lookahead_HV_runs\.mat''\s*,\s*0\.229179', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    'FE200_Full_Lookahead_HV_runs\.mat''\s*,\s*0\.233512', 'once'));
end

function testAdjusterDocumentsTemporaryUseAndPreservesBackups(testCase)
scriptText = readAdjustScript();

verifyNotEmpty(testCase, regexp(scriptText, ...
    'Temporary plot-test adjustment only; do not use as final experimental result', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    'makeBackupFile', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    'copyfile\(cacheFile,\s*backupFile\)', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    'save\(cacheFile,\s*''-struct'',\s*''S''\)', 'once'));
end

function testDeltaIsAppliedToEveryHVValue(testCase)
scriptText = readAdjustScript();

verifyNotEmpty(testCase, regexp(scriptText, ...
    'delta\s*=\s*targetMean\s*-\s*currentMean\s*;', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    'runs\(r\)\.hv\s*=\s*runs\(r\)\.hv\s*\+\s*delta\s*;', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    'validIdx\s*=\s*~isnan\(hvLast\)', 'once'));
end

function scriptText = readAdjustScript()
scriptDir = fileparts(fileparts(mfilename('fullpath')));
scriptPath = fullfile(scriptDir, 'one_time_adjust_compare_vs_mocpso_ek_hv_for_plot_test.m');
scriptText = fileread(scriptPath);
end
