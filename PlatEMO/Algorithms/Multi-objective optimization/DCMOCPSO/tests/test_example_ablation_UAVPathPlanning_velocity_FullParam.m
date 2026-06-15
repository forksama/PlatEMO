function tests = test_example_ablation_UAVPathPlanning_velocity_FullParam
% Static checks for the velocity one-factor ablation using full_param.
tests = functiontests(localfunctions);
end

function testUsesApprovedVelocityConfigs(testCase)
scriptText = readVelocityScript();

verifyNotEmpty(testCase, regexp(scriptText, ...
    'velocityList\s*=\s*\[10,\s*15,\s*20,\s*25,\s*30\]\s*;', 'once'));
end

function testUsesFullLookaheadSettings(testCase)
scriptText = readVelocityScript();

verifyNotEmpty(testCase, regexp(scriptText, ...
    'n\s*=\s*20\s*;', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    'baseProblemParameter\s*=\s*\{20,\s*20,\s*5,\s*-101\.5,\s*0,\s*30,\s*2,\s*500,\s*10,\s*4\}\s*;', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    'maxFE_Full\s*=\s*100\s*;', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    'param_Full\s*=\s*\{5,\s*2,\s*0\.5,\s*0\.3,\s*true,\s*true,\s*true\}\s*;', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    'commonConfig\.param_Full', 'once'));
end

function testPassesVelocityAndUsesSeparateCache(testCase)
scriptText = readVelocityScript();

verifyNotEmpty(testCase, regexp(scriptText, ...
    'problemParameter\{2\}\s*=\s*velocity', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    'problemParameter\{7\}\s*=\s*2', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    'cacheDir\s*=\s*fullfile\(fileparts\(mfilename\(''fullpath''\)\),\s*''results'',\s*''velocity_full_param''\)', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    'Velocity_Full_v%s_HV_objMetrics_runs\.mat', 'once'));
end

function testPersistsObjectiveMetricsWithoutMetricOnlyReruns(testCase)
scriptText = readVelocityScript();

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

function scriptText = readVelocityScript()
scriptDir = fileparts(fileparts(mfilename('fullpath')));
scriptPath = fullfile(scriptDir, 'example_ablation_UAVPathPlanning_velocity_FullParam.m');
scriptText = fileread(scriptPath);
end
