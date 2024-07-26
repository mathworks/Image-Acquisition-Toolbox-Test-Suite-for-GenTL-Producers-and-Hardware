function testparams = hTestCleanup(testCase, testparams)
% Verify that no videoinput objects exist once tests have completed. Reset
% MATLAB to its initial state and restore any changed environment variables.

% Copyright 2024 The MathWorks, Inc.

if (isfield(testparams, "skipcleanup") && (testparams.skipcleanup == true))
    return;
end

% Verify that there are no videoinput objects.
testCase.verifyEmpty(imaqfind, ...
    "hTestCleanup failed because invalid videoinput objects were found");
delete(imaqfind);

% Delete any existing timer object
testCase.verifyEmpty(timerfind, ...
    "hTestCleanup failed because invalid timer objects were found");
delete(timerfind);

% Reset the flag to limit the frame memory used.
imaqmex('feature', '-limitphysicalmemoryusage', true);
imaqreset

% Now check to make sure that no other adaptors were left unregistered by
% any of the tests that registered them
currentlyRegAdaptors = imaqregister;
unregAdaptors = setdiff(currentlyRegAdaptors, testparams.originalRegAdaptors);
if ~isempty(unregAdaptors)
    testCase.verifyEmpty(unregAdaptors, ...
        "hTestCleanup failed to unregister extra adaptors");
    for k = 1:numel(unregAdaptors)
        imaqregister(unregAdaptors{k}, "unregister");
    end
    imaqreset
end

% Remove temporary directory
[dirDelSuccess, delMsg]= rmdir(testparams.imaqTempDir, "s");
testCase.verifyTrue(dirDelSuccess, ...
    sprintf("hTestCleanup failed to delete temporary directory: %s\n <Error: %s>", ...
    testparams.imaqTempDir, delMsg));

% Restore original path
% Restore GenTL environment variables
path(testparams.OriginalPath);
hInternalHook(2);
setenv("GENICAM_GENTL64_PATH", testparams.initialGentlEnv);