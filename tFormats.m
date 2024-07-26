classdef tFormats < matlab.unittest.TestCase
    % tFormat tests the capability of devices and producers to specify a
    % pixel format on videoinput object creation
    % INCLUDED TESTS:
    %
    %       verifyFormat   - Verify that formats listed by the device/user
    %                        are valid and create valid videoinput objects

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

    properties(TestParameter)
        % Initialize pixel format parameter at the test point level
        TestFormat
    end


    methods(TestParameterDefinition, Static)
        function TestFormat = createFormatsParam(DeviceConfig)
            % All possible format parameter values have already been
            % extracted in the device configuration, but need to be set 
            % into a separate cell array to work as parameters.
            TestFormat = DeviceConfig.SUPPORTEDFORMATS;
        end
    end

    % Test Setup
    methods(TestClassSetup)
        function setup(testCase, DeviceConfig)
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
        function verifyFormat(testCase, TestFormat)
            % Verify that all formats listed by device-under-test can be
            % used to create valid videoinput objects
            % User can manually supply a cell array of formats to that they
            % wish to verify for all device/producer configurations using
            % external parameter injection:
            % https://www.mathworks.com/help/matlab/matlab_prog/use-external-parameters-in-parameterized-test.html
            % Example:
            %   formats = {'BGR8', 'BayerRG16', 'Mono10Packed', 'Mono16'}
            %   param = Parameter.fromData("TestFormat", formats)
            %   suite = TestSuite.fromClass(?tFormats, "ExternalParameters", param)
            %   {suite.Name}' % View all parameterizations
            %   result = suite.run;
            % Please verify that the GENICAM_GENTL64_PATH environment
            % variable is set appropriately before attempting this.

            % Get supported formats from DUT hw spec file
            supportedFormats = testCase.getFormats();
            % Check that the format-under-test is listed in the hw spec,
            % otherwise filter and move on to the next test point.
            testCase.assumeTrue(ismember(TestFormat, supportedFormats), ...
                "Format-under-test was not found in the list of formats " + ...
                "provided by the hardware spec file." + newline + ...
                "Filtering test point for format " + TestFormat);

            disp("Verifying " + TestFormat + " format for device " + ...
                num2str(testCase.TestParams.IMAQHWID) + ...
                " using producer at: " + testCase.CurrProducer)
            vid = videoinput("gentl", testCase.TestParams.IMAQHWID, ...
                TestFormat);
            testCase.addTeardown(@delete, vid);
            % Construct the expected name property.
            expectedName = [TestFormat, '-gentl-', ...
                num2str(testCase.TestParams.IMAQHWID)];
            testCase.verifyTrue(isvalid(vid), "Videoinput created with " + ...
               TestFormat + " format is not valid")
            testCase.verifyEqual(vid.VideoFormat, TestFormat, ...
                "ncorrect Video Format: " + TestFormat);
            testCase.verifyEqual(vid.Name, expectedName, ...
                "Incorrect Name for videoinput created with format: " + TestFormat);
            testCase.verifyEqual(vid.DeviceID, testCase.TestParams.IMAQHWID, ...
                "Incorrect ID for videoinput created with format: " + TestFormat);
        end
    end

    methods
        function formats = getFormats(testCase)
            import matlab.unittest.fixtures.PathFixture
            import matlab.unittest.fixtures.SuppressedWarningsFixture
            % Some hw spec file names might be excessively long due to long
            % device names. Suppress the 63-character limit warning
            testCase.applyFixture(SuppressedWarningsFixture( ...
                "MATLAB:namelengthmaxexceeded"));
            % Get all supported formats for given device
            if exist(testCase.TestParams.hwSpecFilePath, "file")
                f = testCase.applyFixture(PathFixture( ...
                    testCase.TestParams.imaqTempDir));
                specFcn = str2func(testCase.TestParams.hwSpecTempName);
                formats = specFcn('formats');
            else
                error("No hardware spec named " +...
                    testCase.TestParams.hwSpecFilesName + " found");
            end
        end
    end
end