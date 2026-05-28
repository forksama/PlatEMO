function tests = test_UAVPathPlanning_A3
% Unit tests for the A3 handover trigger used by UAVPathPlanning.
tests = functiontests(localfunctions);
end

function testA3RequiresStrictHysteresisMargin(testCase)
currentSignal = -80;
hysteresisMargin = 3;
tttCounter = 1;
tttRequiredSteps = 1;

verifyFalse(testCase, UAVPathPlanning.shouldTriggerA3Handover( ...
    currentSignal, -77, hysteresisMargin, tttCounter, tttRequiredSteps));
verifyTrue(testCase, UAVPathPlanning.shouldTriggerA3Handover( ...
    currentSignal, -76.9, hysteresisMargin, tttCounter, tttRequiredSteps));
end

function testA3RequiresTimeToTriggerConfirmation(testCase)
currentSignal = -80;
candidateSignal = -76;
hysteresisMargin = 3;
tttRequiredSteps = 2;

verifyFalse(testCase, UAVPathPlanning.shouldTriggerA3Handover( ...
    currentSignal, candidateSignal, hysteresisMargin, 1, tttRequiredSteps));
verifyTrue(testCase, UAVPathPlanning.shouldTriggerA3Handover( ...
    currentSignal, candidateSignal, hysteresisMargin, 2, tttRequiredSteps));
end
