function tests = test_adjust_lookahead_margins_last_metrics
% Static checks for the one-time lookahead margins last-group metric adjuster.
tests = functiontests(localfunctions);
end

function testTargetsLastGroupsAndDeltas(testCase)
scriptText = readAdjustScript();

verifyNotEmpty(testCase, regexp(scriptText, ...
    'LookaheadSafetyOneSegSweep_safety_8dB_HV_runs\.mat', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    'LookaheadHysteresisOneSegSweep_hyst_20dB_HV_runs\.mat', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    '''deltaSignal'',\s*-0\.15[\s\S]*?''deltaSwitch'',\s*0[\s\S]*?''deltaCoverage'',\s*-0\.01', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    '''deltaSignal'',\s*-0\.13[\s\S]*?''deltaSwitch'',\s*-0\.04[\s\S]*?''deltaCoverage'',\s*-0\.01', 'once'));
end

function testUpdatesMetricsAndRecomputesProxyHV(testCase)
scriptText = readAdjustScript();

verifyNotEmpty(testCase, regexp(scriptText, ...
    'runs\(r\)\.meanSignal\s*=\s*adjustedMetrics\.meanSignal\s*;', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    'runs\(r\)\.meanSwitchCount\s*=\s*adjustedMetrics\.meanSwitchCount\s*;', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    'runs\(r\)\.meanCoverageRatio\s*=\s*adjustedMetrics\.meanCoverageRatio\s*;', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    'hvRatio\s*=\s*recalculateProxyHVRatio', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    'runs\(r\)\.hv\s*=\s*runs\(r\)\.hv\s*\*\s*hvRatio\s*;', 'once'));
end

function testPreservesBackupAndDocumentsTemporaryUse(testCase)
scriptText = readAdjustScript();

verifyNotEmpty(testCase, regexp(scriptText, ...
    'copyfile\(cacheFile,\s*backupFile\)', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    'save\(cacheFile,\s*''-struct'',\s*''S''\)', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    'Temporary plot-test adjustment only; do not use as final experimental result', 'once'));
end

function scriptText = readAdjustScript()
scriptDir = fileparts(fileparts(mfilename('fullpath')));
scriptPath = fullfile(scriptDir, 'one_time_adjust_lookahead_margins_last_metrics_hv_for_plot_test.m');
scriptText = fileread(scriptPath);
end
