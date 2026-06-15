function tests = test_example_ablation_UAVPathPlanning_TTT_bsDensity_FullParam
% Static checks for the TTT and base-station-density one-factor ablations.
tests = functiontests(localfunctions);
end

function testUsesRequestedSweepValues(testCase)
scriptText = readScript();

verifyNotEmpty(testCase, regexp(scriptText, ...
    'TTTList\s*=\s*\[1,\s*3,\s*5,\s*7,\s*9\]\s*;', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    'bsPerKm2List\s*=\s*\[5,\s*10,\s*20,\s*30,\s*40\]\s*;', 'once'));
end

function testUsesFullParamAndRequestedBudget(testCase)
scriptText = readScript();

verifyNotEmpty(testCase, regexp(scriptText, ...
    'n\s*=\s*20\s*;', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    'maxFE_Full\s*=\s*100\s*;', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    'param_Full\s*=\s*\{5,\s*2,\s*0\.5,\s*0\.3,\s*true,\s*true,\s*true\}\s*;', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    'baseProblemParameter\s*=\s*\{20,\s*20,\s*5,\s*-101\.5,\s*0,\s*30,\s*2,\s*500,\s*10,\s*4\}\s*;', 'once'));
end

function testPassesTTTAndBsDensityToProblem(testCase)
scriptText = readScript();

verifyNotEmpty(testCase, regexp(scriptText, ...
    'problemParameter\{3\}\s*=\s*TTT', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    'problemParameter\{1\}\s*=\s*bsPerKm2', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    'problemParameter\{7\}\s*=\s*2', 'once'));
end

function testUsesSeparateCacheAndPlotsObjectiveMetrics(testCase)
scriptText = readScript();

verifyNotEmpty(testCase, regexp(scriptText, ...
    'cacheDir\s*=\s*fullfile\(fileparts\(mfilename\(''fullpath''\)\),\s*''results'',\s*''ttt_bs_density_full_param''\)', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    'TTT_Full_ttt_%ss_HV_objMetrics_runs\.mat', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    'BSDensity_Full_bs_%s_HV_objMetrics_runs\.mat', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    'plotMetricSet\(tttResults', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    'plotMetricSet\(bsDensityResults', 'once'));
end

function testCacheCompletionUsesRunCountOnly(testCase)
scriptText = readScript();

verifyNotEmpty(testCase, regexp(scriptText, ...
    'if\s+loadCount\s*>=\s*n\s*[\r\n]+\s*return\s*;', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    'startRun\s*=\s*loadCount\s*\+\s*1\s*;', 'once'));
verifyEmpty(testCase, regexp(scriptText, ...
    'all\(~isnan\(hvLast\)\)', 'once'));
end

function scriptText = readScript()
scriptDir = fileparts(fileparts(mfilename('fullpath')));
scriptPath = fullfile(scriptDir, 'example_ablation_UAVPathPlanning_TTT_bsDensity_FullParam.m');
scriptText = fileread(scriptPath);
end
