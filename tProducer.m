classdef tProducer < matlab.unittest.TestCase
    % tProducer tests that GenTL producers registered in the
    % GENICAM_GENTL64_PATH environment variable are usable with the MATLAB
    % consumer
    % INCLUDED TESTS:
    %
    %       verifyProducerListed   - Verify that imaqsupport generates the
    %                                correct information about the producer
    %                                currently in use
    %       verifyVendorDriver     - Verify that all videoinput objects
    %                                created using a producer have the same
    %                                VendorDriverDescription property

    % Copyright 2024 The MathWorks, Inc.

    properties
        TestParams
        CurrDevice
        CurrProducer
        DeviceConfig = hConstructParams()
    end

    properties(ClassSetupParameter)
        % Initialize Producer parameter for the whole test file.
        % Devices are not specifically parameterized in this test as
        % verifyProducerListed does not directly create videoinput objects,
        % and verifyVendorDriver requires two or more devices
        Producer = hGetAllProducers()
    end

    % Test Setup
    methods(TestClassSetup)
        function setup(testCase, Producer)
            import matlab.unittest.fixtures.SuppressedWarningsFixture
            % Create test parameters based on current configuration of
            % device and producer
            testCase.applyFixture(SuppressedWarningsFixture( ...
                "imaq:imaqhwinfo"))
            testCase.CurrDevice = testCase.DeviceConfig{1};
            testCase.CurrProducer = testCase.DeviceConfig{1}.Producer;
            testCase.TestParams = hTestSetup(testCase.TestParams, ...
                testCase.CurrDevice, testCase.CurrProducer);
            testCase.CurrProducer = Producer;
            setenv("GENICAM_GENTL64_PATH", testCase.CurrProducer);
            imaqreset;
        end
    end

    % Test Cleanup
    methods(TestClassTeardown)
        function cleanup(testCase)
            testCase.TestParams = hTestCleanup(testCase, testCase.TestParams);
            setenv("GENICAM_GENTL64_PATH", testCase.TestParams.initialGentlEnv);
        end
    end

    % Verification Methods
    methods(Test)
        function verifyProducerListed(testCase)
            import matlab.unittest.constraints.IsEqualTo
            import matlab.unittest.constraints.StringComparator
            % Verify that producer listed in imaqsupport is the same as the
            % one in use when a videoinput is created with gentl adaptor
            imaqsupport("gentl", fullfile(tempdir, "imaqsupport.txt"));
            testCase.addTeardown(@testCase.deleteImaqsupport);
            text = fileread(fullfile(tempdir, "imaqsupport.txt"));
            idx = strfind(text, ...
                "--------------------GENICAM--------------------");
            gText = text(idx:end);
            lines = split(gText, newline);
            % Verify listed path
            gentlPath = lines(contains(lines, "GENICAM_GENTL64_PATH"));
            gentlPath = strip(gentlPath{1}(24:end));
            testCase.verifyEqual(gentlPath, testCase.CurrProducer);

            % Sometimes the entry contains multiple .CTI files appended to
            % the directory path. Separate these then verify individually
            ctiPath = lines(contains(lines, "Producer found"));
            ctiPath = split(strip(ctiPath{1}(18:end)), filesep);
            ctiFiles = ctiPath(endsWith(ctiPath, ".cti"));
            for k=1:length(ctiFiles)
                ctiFilePath = [gentlPath filesep ctiFiles{k}];
                testCase.verifyTrue(isfile(ctiFilePath), ...
                    "CTI file not found at " + ctiFilePath);
            end
            testCase.verifyEqual( ...
                strjoin(ctiPath(~endsWith(ctiPath, ".cti")), filesep), ...
                testCase.CurrProducer, "Current producer was not listed in " + ...
                "imaqsupport when set as GENICAM_GENTL64_PATH");
        end

        function verifyVendorDriver(testCase)
            % Verify that videoinput objects created to connect to devices 
            % enumerated by the same producer have the same 
            % VendorDriverDescription and VendorDriverVerision properties.
            % This test requires at least two cameras to run verification

            hwInfo = imaqhwinfo("gentl");
            vddList = cell(1,length(hwInfo.DeviceIDs));
            vdvList = cell(1,length(hwInfo.DeviceIDs));
            % Verification can only occur if there were two or more
            % devices detected by the producer
            testCase.assumeTrue(length(vddList)>=2, ...
                "Less than 2 devices detected by producer in " + ...
                testCase.CurrProducer + newline + ...
                "Skipping verification for this producer");
            for m=1:length(hwInfo.DeviceIDs)
                vid = videoinput("gentl", hwInfo.DeviceIDs{m});
                % Get VendorDriverDescription, remove "Image
                % Acquisition Toolbox GenTL Adaptor with" lead string
                vdd = imaqhwinfo(vid).VendorDriverDescription(46:end);
                vddList{m} = vdd;
                vdv = imaqhwinfo(vid).VendorDriverVersion;
                vdvList{m} = vdv;
                delete(vid);
            end

            % Verify that all the VendorDriverDescriptions are the same
            % for devices using the same producer
            allEqualVDD = cellfun(@(x) isequal(vddList{1}, x), vddList);
            testCase.verifyTrue(all(allEqualVDD), ...
                "Not all VendorDriverDescriptions are the same for " + ...
                "devices using producer in " +  testCase.CurrProducer);
            % Verify that all the VendorDriverVersions are the same
            % for devices using the same producer
            allEqualVDV = cellfun(@(x) isequal(vdvList{1}, x), vdvList);
            testCase.verifyTrue(all(allEqualVDV), ...
                "Not all VendorDriverVersions are the same for " + ...
                "devices using producer in " +  testCase.CurrProducer);
        end
    end

    methods (Static)
        function deleteImaqsupport()
            % close and delete generated imaqsupport file
            imaqsupportPath = fullfile(tempdir,"imaqsupport.txt");
            editorTab = matlab.desktop.editor.findOpenDocument(imaqsupportPath);
            if ~isempty(editorTab)
                editorTab.closeNoPrompt
            end
            delete(imaqsupportPath);
        end
    end
end