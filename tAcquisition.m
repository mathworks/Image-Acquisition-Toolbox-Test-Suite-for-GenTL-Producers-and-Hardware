classdef tAcquisition < matlab.unittest.TestCase
    % tAcquisition tests capability of GenTL producer and GenICam-compliant
    % device combinations to perform basic image acquisition with the
    % MATLAB gentl consumer.
    % INCLUDED TESTS:
    %
    %       verifyAcquisition   - Verify start() function and logging with
    %                             disklogger
    %       verifySnapshot      - Verify getsnapshot() function, max/min
    %                             resolution, and native data types
    %       verifyPreview       - Verify preview() function and ROI updates
    %       verifyTestPattern   - Verify correctness of acquired data
    %                             (requires TestPattern source properties)

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
            % by cameras
            testCase.applyFixture(SuppressedWarningsFixture({...
                'imaq:gige:adaptorPropertyHealed',...
                'imaq:gige:adaptorErrorPropSet',...
                'imaq:gentl:adaptorSetROIModified' ...
                'MATLAB:hg:AutoSoftwareOpenGL'}))
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

    methods(TestMethodTeardown)
        function deleteVideoinputs(testCase)
            delete(imaqfind);
        end
    end

    % Verification Methods
    methods(Test)
        function verifyAcquisition(testCase)
            % Verify that IMAQ can acquire frames using start() from the
            % device-under-test using the producer-under-test
            import matlab.unittest.constraints.Eventually
            import matlab.unittest.constraints.IsEqualTo

            vid = hCreateVideoInput(testCase.TestParams);
            tempVidFileName = testCase.TestParams.hwSpecFileName + "_VideoWriter.avi";
            tempVidFilePath = fullfile(testCase.TestParams.imaqTempDir, tempVidFileName);

            % Set up video writer for disk logging
            % AVI file is not created until acquisition has completed.
            vwObj = VideoWriter(tempVidFilePath, "Default");
            if any(ismember(properties(vwObj), "Colormap"))
                vwObj.Colormap = gray(256);
            end
            set(vid, "DiskLogger", vwObj);
            set(vid, "LoggingMode", "disk&memory");

            % Begin acquisition, make sure file is written.
            start(vid);
            wait(vid, inf, "logging");
            % Pause to let frames finish logging to VideoWriter
            pause(3);
            testCase.verifyThat(@()vid.FramesAcquired, ...
                Eventually(IsEqualTo(vwObj.FrameCount),"WithTimeoutOf", 60), ...
                "Discrepancy in number of frames reported to be captured by" + ...
                " videoinput object and actual number of frames in disklogger");
            testCase.verifyThat(@()vid.DiskLoggerFrameCount, ...
                Eventually(IsEqualTo(vwObj.FrameCount),"WithTimeoutOf", 60), ...
                "Discrepancy in number of frames expected by videoinput " + ...
                "in disklogger and actual number of frames in disklogger");

            % Update the videoinput object by acquiring info about
            % DiskLoggerFormat, FramesAvailable, and FramesAcquired
            % properties using the StartFcn
            vid.StartFcn = @testCase.localStartFcn;
            % Begin acquisition again
            start(vid);
            testCase.verifyWarningFree(@() wait(vid, inf, "logging"));

            % Get UserData values populated by StartFcn
            userData = vid.UserData;
            diskLogFrameCount = userData{1};
            framesAvail = userData{2};
            framesAcq = userData{3};

            % Verify that DiskLoggerFrameCount is reset to 0 when start is
            % called and that data in buffer is flushed without warning
            % when start is called
            testCase.verifyEqual(diskLogFrameCount, 0, ...
                "DiskLoggerFrameCount should be set to 0 when start() is called");
            testCase.verifyEqual(framesAvail, 0, ...
                "The value of the FrameAvailable in the buffer should be " +...
                "flushed when start() is called");
            testCase.verifyEqual(framesAcq, 0, ...
                "The value of the FrameAcquired in the buffer should be " +...
                "flushed when start() is called");

            delete(vid);
        end

        function verifySnapshot(testCase)
            % Verify that IMAQ can acquire a snapshot using getsnapshot()
            % from the device-under-test using the producer-under-test
            % Several snapshots of decreasing size will be acquired,
            % beginning with maximum resolution, followed by several with
            % various size and offset, ending with one of minumum
            % resolution

            vid = hCreateVideoInput(testCase.TestParams);
            % Get device's expected data type and maximum resolution for
            % later verification
            expClass = imaqhwinfo(vid, "NativeDataType");
            maxSize = [imaqhwinfo(vid, "MaxWidth") imaqhwinfo(vid, "MaxHeight")];

            % Generate ROIPosition values of various sizes and offsets
            % Select first few offsets (total number equal to offsetDiv)
            % in case mod(maxSize,offsetDiv) is not 0
            offsetDiv = 5;
            xoffset = 0 : floor(maxSize(1)/offsetDiv) : (maxSize(1)-1);
            xoffset = xoffset(1:offsetDiv);
            yoffset = 0 : floor(maxSize(2)/offsetDiv) : (maxSize(2)-1);
            yoffset = yoffset(1:offsetDiv);
            for n=1:offsetDiv
                roi = [xoffset(n) yoffset(n) (maxSize(1) - xoffset(n)) (maxSize(2) - yoffset(n))];
                vid.ROIPosition = roi;
                try
                    % Try/Catch as certain ROI values can error
                    data = getsnapshot(vid);
                catch ME
                    % Skip this loop as no data is returned.
                    disp("Camera was not able to capture a snapshot using " + ...
                        "ROI value [" + num2str(roi) + "]. This value will" + ...
                        " not be used for verification")
                    continue
                end
                verifyROIData;
            end

            % Verify size and data type of minimum size ROI
            % [0 0 1 1] is the smallest ROI possible, but not necessarily
            % supported by the device. IMAQ will automatically adjust the
            % ROI to the minimum size allowable (and output a warning,
            % which will need to be suppressed)
            warnState = warning;
            testCase.addTeardown(@warning, warnState)
            % Temporarily suppresses all warnings
            warning("off","all");
            % Setting the following ROI will usually give a "The
            % ROIPosition property was modified by the device." This would
            % cause the test to fail even though it is desired behavior.
            vid.ROIPosition = [0 0 1 1];
            warning(warnState); % Restore the initial warning state
            data = getsnapshot(vid);
            verifyROIData;

            function verifyROIData
                % Get the size of the image
                imageSize = size(data, [1 2]);
                % Get expected image size from ROI value
                roiPos = vid.ROIPosition;
                expectedSize = [roiPos(4) roiPos(3)];
                % Verify acquired snapshot is the same size as ROI
                testCase.verifyEqual(imageSize, expectedSize, "Captured" + ...
                    "snapshot size does not match set value for ROIPosition.")

                % Determine class (data type) of the data
                actClass = class(data);
                % Verify that getsnapshot returns data in the device's native
                % data type (uint8 or uin16)
                testCase.verifyEqual(actClass, expClass);
            end

            % Reset to original (maximum) resolution before cleaning up.
            vid.ROIPosition = [0 0 maxSize(1) maxSize(2)];
            delete(vid);
        end

        function verifyPreview(testCase)
            % Verify that IMAQ can display a preview of acquisition from
            % the device-under-test using the producer-under-test
            vid = hCreateVideoInput(testCase.TestParams, "smallROI");
            preROI = get(vid, "ROIPosition");
            hImage = preview(vid);

            % Verify the preview image matches the width and height.
            imageData = get(hImage, "CData");
            [actHeight, actWidth, ~] = size(imageData);
            testCase.verifyEqual(preROI(3:4), [actWidth, actHeight], ...
                "Default object ROI is not displayed on preview window.");

            % Set new ROI to half of the original ROI and give the window a
            % chance to be updated with the new ROI.
            % Adaptor should automatically round any decimal values down
            postROI = [preROI(1:2) preROI(3:4)/2];
            set(vid, "ROIPosition", postROI);
            pause(5);

            % Verify the image matches the new width and height.
            imageData = get(hImage, "CData");
            [actHeight, actWidth, ~] = size(imageData);
            testCase.verifyEqual([actWidth, actHeight], postROI(3:4),...
                "Adjusted object ROI is not displayed on preview window.");

            closepreview;
            delete(vid);
        end

        function verifyTestPattern(testCase)
            % This test is automatically filtered if the selected
            % configuration does not have TestPatternGeneratorSelector and
            % TestPattern as video source properties.
            % Individual verifications will be performed based on the
            % availability of settable test patterns (e.g. Black, White,
            % GreyHorizontalRamp, GreyVerticalRamp).

            % Get property information from hw spec file
            allProps = testCase.getProps();
            propNames = {allProps.Name};
            % Filter test if necessary properties aren't found
            testCase.assumeTrue(...
                any(ismember(propNames,"TestPattern")) && ...
                any(ismember(propNames,"TestPatternGeneratorSelector")), ...
                "Filtering test point as device does not have Test " + ...
                "Patterns available")
            % Only use Sensor test patterns in this test
            tpgsConstraints = allProps(ismember( ...
                propNames,"TestPatternGeneratorSelector")).ConstraintValue;
            testCase.assumeTrue(any(ismember(tpgsConstraints,"Sensor")), ...
                "Filtering test point as Sensor is not an option for " +...
                "TestPatternGeneratorSelector")

            vid = hCreateVideoInput(testCase.TestParams);
            src = getselectedsource(vid);

            src.TestPatternGeneratorSelector = "Sensor";
            % Get testable test patterns
            possibleTestPatterns = ["Black", "White",...
                "GreyHorizontalRamp", "GreyVerticalRamp"];
            % Get test patterns available on device directly from source
            % object instead of hw spec file as the listed ConstraintValue
            % can depend on what TestPatternGeneratorSelector was set to
            % when the file was generated
            tpConstraints = propinfo(src,"TestPattern").ConstraintValue;
            testPatterns = intersect(possibleTestPatterns, tpConstraints);
            % Filter if none of the above test patterns are available
            testCase.assumeFalse(isempty(testPatterns), "No testable" +...
                " test patterns found on device")

            testCase.addTeardown(@turnOffTestPattern, src, "Off");
            % Perform verification with available test patterns
            for k=1:length(testPatterns)
                src.TestPattern = testPatterns(k);
                img = getsnapshot(vid);
                % Use only one layer of image data for non-Mono
                % formats--they should all be the same or similar anyway
                img = img(:,:,1);
                switch testPatterns(k)
                    case "Black"
                        % Verify all pixels are the same
                        testCase.verifyTrue(isscalar(unique(img)), ...
                            "Not all pixels in Black test pattern " +...
                            "are the same");
                        % Verify that pixels are black (values
                        % should be 0 or 1 for Mono image)
                        testCase.verifyTrue(unique(img)<=1, ...
                            "Pixels in Black test pattern are not black");

                    case "White"
                        % Verify all pixels are the same
                        testCase.verifyTrue(isscalar(unique(img)), ...
                            "Not all pixels in White test pattern " +...
                            "are the same");
                        % Verify that pixels are white (values
                        % should be 254 or 255 for Mono image)
                        testCase.verifyTrue(unique(img)>=254, ...
                            "Pixels in White test pattern are not white");

                    case "GreyHorizontalRamp"
                        % Verify pixels get progressively lighter from left 
                        % to right
                        % Verify that every column contains only one value
                        for n=1:size(img,2)
                            column = img(:,n);
                            pixelVal = unique(column);
                            % Verify that column is all one value
                            testCase.verifyTrue(isscalar(pixelVal), ...
                                "Column " + num2str(n) + " of " + ...
                                "GreyHorizontalRamp not all one value");
                        end
                        % Verify each row is sorted in left-to-right 
                        % increasing order
                        testCase.verifyTrue(issorted(img,1), ...
                            "GreyHorizontalRamp TestPattern does not " + ...
                            "increase left to right consistently")
                        % Verify that every row is identical. Take the 
                        % vertical difference between each row and then 
                        % verify that all values are zero
                        rowDiffs = diff(img,1,1);
                        testCase.verifyTrue(nnz(rowDiffs)==0, ...
                            "Not all rows of GreyHorizontalRamp " + ...
                            "TestPattern are equal")

                    case "GreyVerticalRamp"
                        % Verify pixels get progressively lighter from top 
                        % to bottom
                        % Verify that every row contains only one value
                        for n=1:size(img,1)
                            row = img(n,:);
                            pixelVal = unique(row);
                            % Verify that column is all one value
                            testCase.verifyTrue(isscalar(pixelVal), ...
                                "Row " + num2str(n) + " of " + ...
                                "GreyVerticalRamp not all one value");
                        end
                        % Verify each column is sorted in top-to-bottom 
                        % increasing order
                        testCase.verifyTrue(issorted(img,2), ...
                            "GreyVerticalRamp TestPattern does not " + ...
                            "increase top to bottom consistently")
                        % Verify that every column is identical. Take the 
                        % horizontal difference between each column and 
                        % then verify that all values are zero
                        colDiffs = diff(img,1,2);
                        testCase.verifyTrue(nnz(colDiffs)==0, ...
                            "Not all columns of GreyVerticalRamp " + ...
                            "TestPattern are equal")
                end
            end
            % In-method utility for changing TestPattern source property to
            % a specific value in testCase teardown
            function turnOffTestPattern(s,setting)
                s.TestPattern = setting;
            end
        end
    end

    % Local Helper Methods
    methods
        function props = getProps(testCase)
            import matlab.unittest.fixtures.PathFixture
            import matlab.unittest.fixtures.SuppressedWarningsFixture
            % Some hw spec file names might be excessively long due to long
            % device names. Suppress the 63-character limit warning
            testCase.applyFixture(SuppressedWarningsFixture( ...
                "MATLAB:namelengthmaxexceeded"))
            % get all supported properties for given device
            if exist(testCase.TestParams.hwSpecFilePath,"file")
                f = testCase.applyFixture(PathFixture( ...
                    testCase.TestParams.imaqTempDir));
                specFcn = str2func(testCase.TestParams.hwSpecTempName);
                props = specFcn('property');
            else
                error("No hardware spec named " + ...
                    testCase.TestParams.hwSpecFilesName + " found")
            end
        end
    end

    methods(Static)
        function localStartFcn(obj,~)
            % These will be executed when start is called and will be
            % stored in UserData to access them outside the function
            obj.UserData = {obj.DiskLoggerFrameCount,...
                obj.FramesAvailable,...
                obj.FramesAcquired};
        end
    end
end