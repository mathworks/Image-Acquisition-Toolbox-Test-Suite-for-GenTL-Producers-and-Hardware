function vid = hCreateVideoInput(testparams, optionalArgument)
% Create a videoinput object based on given test parameters.
% This function assumes that the format included in testparams's
% CurrentFormat field is currently available on the device. Please make 
% sure that the device configuration does not have any setting enabled
% (e.g. SequencerMode) that would prevent it from using the default
% format specified in the associated hw spec file

% Copyright 2024 The MathWorks, Inc.

try
    vid = videoinput("gentl", testparams.IMAQHWID, testparams.CurrentFormat);
catch errVidCreation
    deviceSpecs = sprintf("\n\n==Adaptor Name: <%s>\n==Device ID: <%d>\n==Device Format: <%s>\n\n", ...
        "gentl", testparams.IMAQHWID, testparams.CurrentFormat);
    error("\n%s\n\nCould not create a video input object with the following parameters:\n %s", ...
        errVidCreation.message, deviceSpecs)
end

if nargin == 1
    return;
end

% Smaller frame size is preferable in some test cases to reduce overall
% memory footprint.
if strcmpi(optionalArgument, "smallROI")
    smallROI = vid.ROIPosition;
    smallROI = [smallROI(1), smallROI(2), ...
        min(smallROI(3), 512), min(smallROI(4), 256)];
    try
        vid.ROIPosition = smallROI;
    catch errMsg
        fprintf("\nRequested ROI, [%s], could not be set: \n %s\n", ...
            num2str(smallROI), errMsg.message);
    end
end
end