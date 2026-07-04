function tests = test_one_time_adjust_lookahead_margins_middle_hv_for_plot_test
% Static checks for the one-time lookahead margins middle-group adjuster.
tests = functiontests(localfunctions);
end

function testTargetsMiddleGroupsOnly(testCase)
scriptText = readAdjustScript();

verifyNotEmpty(testCase, regexp(scriptText, ...
    'LookaheadHysteresisOneSegSweep_hyst_10dB_HV_runs\.mat', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    'LookaheadSafetyOneSegSweep_safety_4dB_HV_runs\.mat', 'once'));
verifyEmpty(testCase, regexp(scriptText, ...
    'hyst_(0|5|15|20)dB_HV_runs\.mat', 'once'));
verifyEmpty(testCase, regexp(scriptText, ...
    'safety_(0|2|6|8)dB_HV_runs\.mat', 'once'));
end

function testAppliesFixedIncreaseAndPreservesBackup(testCase)
scriptText = readAdjustScript();

verifyNotEmpty(testCase, regexp(scriptText, ...
    'hvIncrease\s*=\s*0\.0006\s*;', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    'runs\(r\)\.hv\s*=\s*runs\(r\)\.hv\s*\+\s*hvIncrease\s*;', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    'copyfile\(cacheFile,\s*backupFile\)', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    'save\(cacheFile,\s*''-struct'',\s*''S''\)', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    'Temporary plot-test adjustment only; do not use as final experimental result', 'once'));
end

function scriptText = readAdjustScript()
scriptDir = fileparts(fileparts(mfilename('fullpath')));
scriptPath = fullfile(scriptDir, 'one_time_adjust_lookahead_margins_middle_hv_for_plot_test.m');
scriptText = fileread(scriptPath);
end
