classdef tVideoinput < matlab.unittest.TestCase
    % tVideoinput tests basic behavior of videoinput objects created using
    % a GenTL producer
    % INCLUDED TESTS:
    %
    %       verifyVideoinputObj   - Verify videoinput objects have the
    %                               correct properties on creation
    %       verifySelectedSource  - Verify source properties of videoinput
    %                               objects

    % Copyright 2024 The MathWorks, Inc.

    properties
        TestParams
        CurrDevice
        CurrProducer
    end

    properties(ClassSetupParameter)
        % Initialize IMAQHWTYPE, DEVICENAME, IMAQHWID, SUPPORTEDFORMATS,
        % CurrentFormat, and hwSpecFileName for the whole test file
        DeviceConfig = hConstructParams()
    end

    % Test Setup
    methods(TestClassSetup)
        function setup(testCase, DeviceConfig)
            import matlab.unittest.fixtures.SuppressedWarningsFixture
            % Suppress common source property warnings sometimes thrown
            % by cameras using ethernet connections
            testCase.applyFixture(SuppressedWarningsFixture( ...
                {'imaq:gige:adaptorPropertyHealed', ...
                'imaq:gige:adaptorErrorPropSet'}))
            % Create test parameters based on current configuration of
            % device and producer
            testCase.CurrDevice = DeviceConfig;
            testCase.CurrProducer = DeviceConfig.Producer;
            testCase.TestParams = hTestSetup(testCase.TestParams, ...
                testCase.CurrDevice, testCase.CurrProducer);
        end
    end

    % Test Cleanup
    methods(TestClassTeardown)
        function cleanup(testCase)
            testCase.TestParams = hTestCleanup(testCase, testCase.TestParams);
        end
    end

    % Verification Methods
    methods(Test)
        function verifyVideoinputObj(testCase)
            % Verify that gentl adaptor videoinput objects are created
            % correctly with accurate object properties
            vid = hCreateVideoInput(testCase.TestParams);

            % Gather expected values from imaqhwinfo
            vidInfo = imaqhwinfo(vid);
            fields = fieldnames(vidInfo);
            expectedFields = [...
                "AdaptorName", ...
                "DeviceName", ...
                "MaxHeight", ...
                "MaxWidth", ...
                "NativeDataType", ...
                "TotalSources", ...
                "VendorDriverDescription", ...
                "VendorDriverVersion"];
            testCase.verifyEmpty(setdiff(fields, expectedFields), ...,
                "imaqhwinfo(OBJ) did not return the required fields.");

            % Video resolution should be at the maximum by default
            vidRes = vid.VideoResolution;
            expectedMaxHeight = vidRes(2);
            expectedMaxWidth = vidRes(1);
            expectedTotalSources = length(vid.Source);

            % Get one frame to infer the data type
            data = getsnapshot(vid);
            expectedDataType = class(data);
            testCase.verifyEqual(vidInfo.AdaptorName, 'gentl', ...
                "IMAQHWINFO(OBJ) did not return adaptor name gentl.");
            testCase.verifyEqual(vidInfo.MaxHeight, expectedMaxHeight, ...
                "IMAQHWINFO(OBJ) returned incorrect max height.");
            testCase.verifyEqual(vidInfo.MaxWidth, expectedMaxWidth, ...
                "IMAQHWINFO(OBJ) returned incorrect max width.");
            testCase.verifyEqual(vidInfo.NativeDataType, expectedDataType, ...
                "IMAQHWINFO(OBJ) returned incorrect data type.")
            testCase.verifyEqual(vidInfo.TotalSources, expectedTotalSources, ...
                "IMAQHWINFO(OBJ) returned incorrect number of sources.");
            testCase.verifyNotEmpty(vidInfo.VendorDriverDescription, ...
                "IMAQHWINFO(OBJ) returned empty driver description");
            testCase.verifyNotEmpty(vidInfo.VendorDriverVersion, ...
                "IMAQHWINFO(OBJ) returned empty driver version");
            delete(vid);
        end

        function verifySelectedSource(testCase)
            % Verify that selected source is set to the first one available
            % Also verify that a videosource object is created for each
            % source listed in the AvailableSources property

            vid = hCreateVideoInput(testCase.TestParams);
            % Get all available sources from videoinput object
            availableSources = set(vid, "SelectedSourceName");
            testCase.verifyNotEmpty(availableSources, ...
                "videoinput object does not have any available sources")
            testCase.verifyEqual(vid.SelectedSource, availableSources{1}, ...
                "SelectedSourceName was not set to the first available " + ...
                "source on videoinput object creation")

            % Get all source names directly from sources
            srcs = get(vid, "Source");
            srcsProps = get(srcs);
            srcsNames = {srcsProps.SourceName};

            testCase.verifyEqual(length(srcs), length(availableSources), ...
                "Number of sources is inconsistent")
            testCase.verifyEmpty(setdiff(srcsNames, availableSources), ...
                "Source names differed from the allowed SelectedSourceName values")
            delete(vid)
        end
    end
end