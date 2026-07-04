function tests = test_adjust_num_segments_switch_count
% Static checks for the one-time numSegments full_param switch-count adjuster.
tests = functiontests(localfunctions);
end

function testTargetsRequestedGroupsOnly(testCase)
scriptText = readAdjustScript();

verifyNotEmpty(testCase, regexp(scriptText, ...
    'NumSegments_Full_seg_1_HV_objMetrics_runs\.mat''\s*,\s*0\.4', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    'NumSegments_Full_seg_5_HV_objMetrics_runs\.mat''\s*,\s*0\.3', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    'NumSegments_Full_seg_7_HV_objMetrics_runs\.mat''\s*,\s*0\.2', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    'NumSegments_Full_seg_9_HV_objMetrics_runs\.mat''\s*,\s*0\.2', 'once'));
verifyEmpty(testCase, regexp(scriptText, ...
    'NumSegments_Full_seg_3_HV_objMetrics_runs\.mat', 'once'));
end

function testAdjustsRunLevelSwitchCountAndObjMetricSummary(testCase)
scriptText = readAdjustScript();

verifyNotEmpty(testCase, regexp(scriptText, ...
    'runs\(r\)\.meanSwitchCount\s*=\s*adjustedMetrics\.meanSwitchCount\s*;', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    'runs\(r\)\.objMetricSummary\.meanSwitchCount\s*=\s*adjustedMetrics\.meanSwitchCount\s*;', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    'copyfile\(cacheFile,\s*backupFile\)', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    'save\(cacheFile,\s*''-struct'',\s*''S''\)', 'once'));
end

function testSummarySwitchCountIsUpdatedForPlotConsistency(testCase)
scriptText = readAdjustScript();

verifyNotEmpty(testCase, regexp(scriptText, ...
    'summaryFile\s*=\s*fullfile\(cacheDir,\s*''NumSegments_Full_sweep_summary\.mat''\)', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    'results\.meanSwitchCountAll\{groupIndex\}\s*=\s*results\.meanSwitchCountAll\{groupIndex\}\s*-\s*switchCountDecrease\s*;', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    'results\.meanSwitchCount\(groupIndex\)\s*=\s*meanValid\(results\.meanSwitchCountAll\{groupIndex\}\(validIdx\)\)\s*;', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    'save\(summaryFile,\s*''results''\)', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    'Temporary plot-test adjustment only; do not use as final experimental result', 'once'));
end

function testProxyHVIsRecomputedFromAdjustedMetrics(testCase)
scriptText = readAdjustScript();

verifyNotEmpty(testCase, regexp(scriptText, ...
    'hvRatio\s*=\s*recalculateProxyHVRatio\(originalMetrics,\s*adjustedMetrics\)\s*;', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    'runs\(r\)\.hv\s*=\s*runs\(r\)\.hv\s*\*\s*hvRatio\s*;', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    'signalScore\s*=\s*clamp\(\(metrics\.meanSignal\s*\+\s*120\)\s*/\s*70,\s*0,\s*1\)', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    'switchScore\s*=\s*clamp\(1\s*-\s*metrics\.meanSwitchCount\s*/\s*30,\s*0,\s*1\)', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    'coverageScore\s*=\s*clamp\(metrics\.meanCoverageRatio,\s*0,\s*1\)', 'once'));
end

function testSummaryHVIsUpdatedForPlotConsistency(testCase)
scriptText = readAdjustScript();

verifyNotEmpty(testCase, regexp(scriptText, ...
    'results\.hvLastAll\{groupIndex\}\(r\)\s*=\s*results\.hvLastAll\{groupIndex\}\(r\)\s*\*\s*hvRatio\s*;', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    'results\.hvSeriesAll\{groupIndex\}\{r\}\s*=\s*results\.hvSeriesAll\{groupIndex\}\{r\}\s*\*\s*hvRatio\s*;', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    'results\.meanHV\(groupIndex\)\s*=\s*meanValid\(results\.hvLastAll\{groupIndex\}\(validHVIdx\)\)\s*;', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    'results\.stdHV\(groupIndex\)\s*=\s*stdValid\(results\.hvLastAll\{groupIndex\}\(validHVIdx\)\)\s*;', 'once'));
end

function scriptText = readAdjustScript()
scriptDir = fileparts(fileparts(mfilename('fullpath')));
scriptPath = fullfile(scriptDir, 'one_time_adjust_num_segments_full_param_hv_for_plot_test.m');
scriptText = fileread(scriptPath);
end
