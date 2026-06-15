function tests = test_example_ablation_UAVPathPlanning_altitudeLayers_Module2_FullParam
% Static checks for the module-2 altitude-layer ablation.
tests = functiontests(localfunctions);
end

function testUsesModule2AltitudeLayerConfigs(testCase)
scriptText = readScript();

verifyNotEmpty(testCase, regexp(scriptText, ...
    'altitudeCenterList\s*=\s*\[30,\s*50,\s*70,\s*90,\s*110\]\s*;', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    'altitudeBoundOffset\s*=\s*10\s*;', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    'altitudeBoundsList\s*=\s*\[altitudeCenterList\(:\)\s*-\s*altitudeBoundOffset,\s*altitudeCenterList\(:\)\s*\+\s*altitudeBoundOffset\]', 'once'));
end

function testUsesFullLookaheadSettings(testCase)
scriptText = readScript();

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

function testPassesAltitudeCenterAndBounds(testCase)
scriptText = readScript();

verifyNotEmpty(testCase, regexp(scriptText, ...
    'problemParameter\{11\}\s*=\s*altitudeCenter', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    'problemParameter\{12\}\s*=\s*altitudeBounds', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    'problemParameter\{7\}\s*=\s*2', 'once'));
end

function testUsesSeparateCacheAndPersistsMetrics(testCase)
scriptText = readScript();

verifyNotEmpty(testCase, regexp(scriptText, ...
    'cacheDir\s*=\s*fullfile\(fileparts\(mfilename\(''fullpath''\)\),\s*''results'',\s*''altitude_layers_module2_full_param''\)', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    'AltitudeLayers_Module2_Full_H%d_B%d_%d_HV_objMetrics_runs\.mat', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, 'runs\(i\)\.meanSignal\s*=', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, 'runs\(i\)\.meanSwitchCount\s*=', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, 'runs\(i\)\.meanCoverageRatio\s*=', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, 'runs\(i\)\.objMetricSummary\s*=', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    'if\s+loadCount\s*>=\s*n\s*[\r\n]+\s*return\s*;', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    'startRun\s*=\s*loadCount\s*\+\s*1\s*;', 'once'));
end

function testSuppressesAlgorithmOutputWindow(testCase)
scriptText = readScript();

verifyNotEmpty(testCase, regexp(scriptText, ...
    'DCMOCPSO\(''parameter'',\s*algorithmParameter,\s*''outputFcn'',\s*@\(~,~\)\[\]\)', 'once'));
end

function scriptText = readScript()
scriptDir = fileparts(fileparts(mfilename('fullpath')));
scriptPath = fullfile(scriptDir, 'example_ablation_UAVPathPlanning_altitudeLayers_Module2_FullParam.m');
scriptText = fileread(scriptPath);
end
