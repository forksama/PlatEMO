function tests = test_example_compare_UAVPathPlanning_lookahead_only_OneSeg
% Static checks for the lookahead-only comparison script.
tests = functiontests(localfunctions);
end

function testUsesRequestedOneSegParameterSet(testCase)
scriptText = readScript();

verifyNotEmpty(testCase, regexp(scriptText, ...
    'param_OneSeg\s*=\s*\{1,\s*2,\s*0\.5,\s*0\.3,\s*false,\s*false,\s*false\}\s*;', 'once'));
end

function testOnlySwitchMethodDiffersBetweenGroups(testCase)
scriptText = readScript();

verifyNotEmpty(testCase, regexp(scriptText, ...
    'problemParameter_Base\s*=\s*\{20,\s*20,\s*5,\s*-101\.5,\s*0,\s*30,\s*0,\s*500\}\s*;', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    'problemParameter_Lookahead\s*=\s*problemParameter_Base\s*;', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    'problemParameter_Lookahead\{7\}\s*=\s*2\s*;', 'once'));
end

function testOnlyRunsBaseAndLookaheadGroups(testCase)
scriptText = readScript();

verifyNotEmpty(testCase, regexp(scriptText, ...
    'groupNames\s*=\s*\{''OneSeg_Base'',\s*''OneSeg_Lookahead''\}\s*;', 'once'));
verifyEmpty(testCase, regexp(scriptText, 'Seg_Lookahead|Full_Lookahead|OneSeg_A3', 'once'));
end

function scriptText = readScript()
scriptDir = fileparts(fileparts(mfilename('fullpath')));
scriptPath = fullfile(scriptDir, 'example_compare_UAVPathPlanning_lookahead_only_OneSeg.m');
scriptText = fileread(scriptPath);
end
