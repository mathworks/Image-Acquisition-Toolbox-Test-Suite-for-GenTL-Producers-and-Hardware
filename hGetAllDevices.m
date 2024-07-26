function deviceList = hGetAllDevices()
% Create a device structure enumerating all devices available in the
% current producer configuration. When this is run by runGenTLSuite or any
% individual test point, only one producer will be specified in the
% GENICAM_GENTL64_PATH environment variable.

% Copyright 2024 The MathWorks, Inc.

try
    % Get list of all connected gentl hardware
    hwinfo = imaqhwinfo("gentl");
catch ME
    % Error out if imaqhwinfo fails
    error("Error while collecting information on connected GenTL hardware");
end
if isempty(hwinfo.DeviceIDs)
    % Error out if no devices found
    error("No GenTL hardware detected. Exiting test suite.");
end
deviceInfo = hwinfo.DeviceInfo;
deviceList = cell(1, numel(deviceInfo));
for k=1:numel(deviceInfo)
    deviceList{k}.DEVICENAME = deviceInfo(k).DeviceName;
    % DeviceID can change depending on producer
    deviceList{k}.IMAQHWID = deviceInfo(k).DeviceID;
    deviceList{k}.SUPPORTEDFORMATS = deviceInfo(k).SupportedFormats;
    deviceList{k}.CurrentFormat = deviceInfo(k).DefaultFormat;
    hwSpecFileName = regexprep( ...
        ['gentl_', deviceInfo(k).DeviceName, '_', deviceInfo(k).DefaultFormat], ...
        '\W', '_');
    % Note that this only defines what the hw spec file SHOULD be
    % named, it does not guarantee that it has been created.
    deviceList{k}.hwSpecFileName = hwSpecFileName;
end
end