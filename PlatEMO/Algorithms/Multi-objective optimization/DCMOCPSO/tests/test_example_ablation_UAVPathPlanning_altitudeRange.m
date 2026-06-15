function tests = test_example_ablation_UAVPathPlanning_altitudeRange
% Static checks for the altitude/range one-factor ablation.
tests = functiontests(localfunctions);
end

function testUsesApprovedAltitudeConfigs(testCase)
scriptText = readAltitudeScript();

verifyNotEmpty(testCase, regexp(scriptText, ...
    'altitudeCenterList\s*=\s*\[35,\s*50,\s*65,\s*80,\s*95\]\s*;', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    'altitudeBoundOffset\s*=\s*20\s*;', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    'altitudeBoundsList\s*=\s*\[altitudeCenterList\(:\)\s*-\s*altitudeBoundOffset,\s*altitudeCenterList\(:\)\s*\+\s*altitudeBoundOffset\]', 'once'));
end

function testUsesFullLookaheadSettings(testCase)
scriptText = readAltitudeScript();

verifyNotEmpty(testCase, regexp(scriptText, ...
    'n\s*=\s*10\s*;', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    'baseProblemParameter\s*=\s*\{20,\s*20,\s*5,\s*-101\.5,\s*0,\s*30,\s*2,\s*500,\s*10,\s*4\}\s*;', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    'maxFE_Full\s*=\s*100\s*;', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    'param_Full\s*=\s*\{5,\s*2,\s*0\.5,\s*0\.3,\s*true,\s*true,\s*true\}\s*;', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    'commonConfig\.param_Full', 'once'));
end

function testPassesAltitudeParametersAndUsesSeparateCache(testCase)
scriptText = readAltitudeScript();

verifyNotEmpty(testCase, regexp(scriptText, ...
    'problemParameter\{11\}\s*=\s*altitudeCenter', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    'problemParameter\{12\}\s*=\s*altitudeBounds', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    'cacheDir\s*=\s*fullfile\(fileparts\(mfilename\(''fullpath''\)\),\s*''results'',\s*''altitude_range_full_param''\)', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    'AltitudeRange_Full_H%d_B%d_%d_HV_objMetrics_runs\.mat', 'once'));
end

function testPersistsObjectiveMetricsWithoutMetricOnlyReruns(testCase)
scriptText = readAltitudeScript();

verifyNotEmpty(testCase, regexp(scriptText, 'runs\(i\)\.meanSignal\s*=', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, 'runs\(i\)\.meanSwitchCount\s*=', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, 'runs\(i\)\.meanCoverageRatio\s*=', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, 'runs\(i\)\.objMetricSummary\s*=', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    'if\s+loadCount\s*>=\s*n\s*[\r\n]+\s*return\s*;', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    'startRun\s*=\s*loadCount\s*\+\s*1\s*;', 'once'));
verifyEmpty(testCase, regexp(scriptText, ...
    'all\(~isnan\(hvLast\)\)', 'once'));
verifyEmpty(testCase, regexp(scriptText, ...
    'startRun\s*=\s*find\(isnan\(hvLast\),\s*1\)', 'once'));
end

function scriptText = readAltitudeScript()
scriptDir = fileparts(fileparts(mfilename('fullpath')));
scriptPath = fullfile(scriptDir, 'example_ablation_UAVPathPlanning_altitudeRange.m');
scriptText = fileread(scriptPath);
end
