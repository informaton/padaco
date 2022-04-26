% ======================================================================
%> @file PAClassifyGravities.cpp
%> @brief Padaco count activity classifier
% ======================================================================
classdef PAClassifyGravities < PAClassifyUsage

    methods
        % ======================================================================
        %> @brief Constructor for PAClassifyGravities class.
        %> @param vector of count values to process.
        %> @param pStruct Optional struct of parameters to use.  If it is not
        %> included then parameters from getDefaults method are used.
        %> @retval Instance of PAClassifyGravities.
         % =================================================================
        function obj = PAClassifyGravities(varargin)  %  (gravity vector, inputSettings)
            obj = obj@PAClassifyUsage(varargin{:});                        
        end
        
        function [sigma_bai, sigma_x, sigma_y_sigma_z] = classifiyBaiActivity(obj, g_x, g_y, g_z, fs)
            narginchk(4, 5);
            % check that all are the same length
            n_x = numel(g_x);
            n_y = numel(g_y);
            n_z = numel(g_z);
            if ~(n_x==n_y && n_y==n_z)
                error('x, y, and z gravity vectors are not the same length');
            else
                n = n_x;
                if nargin<5
                    fs = 40; % 40 hz sampling default
                end
                n = n-rem(n, fs);
                g_x = g_x(1:n);
                g_y = g_y(1:n);
                g_z = g_z(1:n);
                sigma_x = std(reshape(g_x(:), n, []))';  % reshape so columns contain consecutive 1-s blocks
                sigma_y = std(reshape(g_y(:), n, []))';  % std calculates standard deviation along columns and returns a row vector
                sigma_z = std(reshape(g_z(:), n, []))';  % transpose (') row vector to be a column vector
                sigma_bai = (sigma_x+sigma_y+sigma_z)/3;                
            end
        end
     
        % ======================================================================
        %> @brief Categorizes the study's usage state.
        %> @param obj Instance of PAClassifyGravities.
        %> @param vector of gravity values to apply classification rules to.
        %> If not provided, then the vector magnitude is used
        %> @retval usageVec A vector of length datetimeNums whose values
        %> represent the usage category at each sample instance specified by
        %> @b dateTimeNum.
        %> @retval wearState Vector of wear vs non-wear state.  Each element represent the
        %> consecutive grouping of like states found in the usage vector.
        %> @retval startStopDatenums Start and stop datenums for each usage
        %> state row entry of usageState.
        % ======================================================================
        function [usageVec, wearState, startStopDateNums] = classifyUsageState(obj, gravityVec, datetimeNums, rules)
           
            % By default activity determined from vector magnitude signal
            if(nargin<2 || isempty(gravityVec))
                gravityVec = obj.dataVec;
            end
            if(nargin<3 || isempty(datetimeNums))
                datetimeNums = obj.datenumVec;
            end
            
            if(nargin>3)
                obj.setUsageClassificationRules(rules);
            end

            rules = obj.settings;
                                        
            tagStruct = obj.getActivityTags();

            %  STUCK_VALUES/MALFUNCTION = -5; 

            longFilterLengthMinutes = rules.longFilterLengthMinutes;   % 5 minute or 1/4 hour filter
            shortFilterLengthMinutes = rules.shortFilterLengthMinutes; % 1 minute or 1/12 hour filter

            samplesPerMinute = obj.getSampleRate()*60; % samples per second * 60 seconds per minute
            samplesPerHour = 60*samplesPerMinute;

            longFilterLength = longFilterLengthMinutes*samplesPerMinute;
            shortFilterLength = shortFilterLengthMinutes*samplesPerMinute;

            longSum = obj.movingSummer(gravityVec,longFilterLength);
            shortSum = obj.movingSummer(gravityVec,shortFilterLength);

            usageVec = repmat(tagStruct.UNKNOWN,(size(datetimeNums)));
            
            isStuck = diff(shortSum)==0 & shortSum(2:end)~=0;
            isStuckEvents = obj.thresholdcrossings(isStuck, 0);
            min_dur_sec = rules.minMinutesForStuck*60;
            % stuckThreshold = shortFilterLengthMinutes*rules.minMinutesForStuck;
            if ~isempty(isStuckEvents) &&  min_dur_sec> 0 
                diff_sec = (isStuckEvents(:,2)-isStuckEvents(:,1))/obj.getSampleRate();
                isStuckEvents = isStuckEvents(diff_sec>=min_dur_sec,:);                
            end            
            isStuck = obj.unrollEvents(isStuckEvents, numel(usageVec));
            
            burstThresholdG = rules.excessiveGravitiesPerMinuteCutoff*shortFilterLength; % shortFilterLengthMinutes*samplesPerMinute; % each filtered value represents the sum of the neighboring shortFilterLengthMinutes (e.g. 5 minutes) worth of data
            isBursting = shortSum > burstThresholdG; % 1 indicates working
            isBurstingEvents = obj.thresholdcrossings(isBursting, 0);
            if ~isempty(isBurstingEvents)
                isBurstingEvents = [max(isBurstingEvents(:, 1)-shortFilterLength/2,1), min(isBurstingEvents(:, 2)+ shortFilterLength/2, numel(isBursting))];
                % Merge?
                % Verify correct length if our shortFilterLenghtMinutes ~= rules.minMInutesForExessiveGravities
            end
            isBurstingVec = obj.unrollEvents(isBurstingEvents, numel(usageVec));
            
            % Here, I compare it to the long some though - is that right?           
            % These are for 0 value runs
            notWorkingThreshold = shortFilterLengthMinutes*rules.workingGravitiesPerMinuteCutoff;            
            isWorking = longSum > notWorkingThreshold; % 1 indicates working
            isNotWorkingEvents= obj.thresholdcrossings(~isWorking, 0);
            
            if ~isempty(isNotWorkingEvents)
                studyOverParams.merge_within_sec = rules.mergeWithinHoursForStudyOver*samplesPerHour; %-> group within 6 hours ..
                studyOverParams.min_dur_sec = rules.minHoursForStudyOver*samplesPerHour;%12;% -> this is for classifying state as over.
                merge_distance = round(studyOverParams.merge_within_sec*obj.getSampleRate());
                
                candidate_studyover_events = obj.merge_nearby_events(isNotWorkingEvents,merge_distance);
                diff_sec = (candidate_studyover_events(:,2)-candidate_studyover_events(:,1))/obj.getSampleRate();
                studyover_events = candidate_studyover_events(diff_sec>=studyOverParams.min_dur_sec,:);                
                study_not_started_events = studyover_events;                
            end

            isNotWorkingVec = obj.unrollEvents(isNotWorkingEvents, numel(usageVec));

            % Akin to obj.getDurationSamples() or obj.durSamples -> see
            % PASensorData.m
            numSamples = numel(datetimeNums);
             
            % Round the study over events to the end of the study if it is
            % within 4 hours of the end of the study.
            % --- Otherwise, should I remove all study over events, because
            % the study is clearly not over then (i.e. there is more
            % activity being presented).
            if(~isempty(studyover_events))
                diff_hours = (numSamples-studyover_events(end))/samplesPerHour; %      obj.getSampleRate()/3600;
                if(diff_hours<=rules.mergeWithinHoursForStudyOver)
                    studyover_events(end) = numSamples;
                else
                    studyover_events = [];
                end
                
                diff_hours = (study_not_started_events(1))/samplesPerHour;
                if diff_hours <= rules.mergeWithinHoursOfStudyNotStarted
                    study_not_started_events(1) = 1;
                else
                    study_not_started_events = [];
                end
            end

            % We really just want one section of study over -> though this
            % may be worthwhile to note in cases where studies have large
            % gaps.
            if(size(studyover_events,1)>1)
                studyover_events = studyover_events(end,:);
            end
            
            if(size(study_not_started_events,1)>1)
                study_not_started_events = study_not_started_events(1,:);
            end

            studyOverVec = obj.unrollEvents(studyover_events,numel(usageVec));
            studyNotStartedVec = obj.unrollEvents(study_not_started_events,numel(usageVec));

            if ~isempty(isNotWorkingEvents) && ~isempty(datetimeNums)
                nonwearStartStopDateNums = [datetimeNums(isNotWorkingEvents(:,1)),datetimeNums(isNotWorkingEvents(:,2))];
            else
                nonwearStartStopDateNums = [];
            end
            nonwearState = repmat(tagStruct.NONWEAR,size(isNotWorkingEvents,1),1);

            %            wearVec = runningActivitySum>=offBodyThreshold;
            isWorkingVec = ~isNotWorkingVec;
            wear = obj.thresholdcrossings(isWorkingVec,0);
            if(isempty(wear))
                % only have non wear then
                wearState = nonwearState;
                startStopDateNums = nonwearStartStopDateNums;
            else
                if ~isempty(datetimeNums)
                    wearStartStopDateNums = [datetimeNums(wear(:,1)),datetimeNums(wear(:,2))];
                else
                    wearStartStopDateNums = [];
                end
                wearState = repmat(tagStruct.WEAR,size(wear,1),1);
                wearState = [nonwearState;wearState];
                [startStopDateNums, sortIndex] = sortrows([nonwearStartStopDateNums;wearStartStopDateNums]);
                wearState = wearState(sortIndex);
            end
           
            usageVec(isWorkingVec) = tagStruct.WORKING; %10;
            usageVec(isNotWorkingVec) = tagStruct.NOT_WORKING; %5;
            usageVec(studyOverVec) = tagStruct.STUDYOVER;%0;            
            usageVec(studyNotStartedVec) = tagStruct.STUDY_NOT_STARTED;           
            usageVec(isBurstingVec) = tagStruct.SENSOR_BURST;     
            usageVec(isStuck) = tagStruct.SENSOR_STUCK;

            % usageVec(studyMalfunction) = tagStruct.MALFUNCTION;
            
        end
    end

    methods(Static)
        % ======================================================================
        %> @brief Returns a structure of PAClassifyGravities's default parameters as a struct.
        %> @retval pStruct A structure of default parameters which include the following
        %> fields
        %> - @c usageState Struct defining usage state classification
        %> thresholds and parameters.
        %> @note This is useful with the PASettings companion class.
        %> @note When adding default parameters, be sure to match saveable
        %> parameters in getSaveParameters()
        %======================================================================
        function usageStateRules = getDefaults()
            
            usageStateRules.longFilterLengthMinutes=5;
            usageStateRules.shortFilterLengthMinutes = 1;
            
            usageStateRules.accelerometerStuckMinutesCutoff = 1;  % exceeding the cutoff means you are awake                 
            usageStateRules.workingGravitiesPerMinuteCutoff = 0; % exceeding the cutoff indicates working            
            usageStateRules.excessiveGravitiesPerMinuteCutoff = 4; % exceeding the cutoff indicates excessive
            
            usageStateRules.minMinutesForStuck = 1;
            usageStateRules.minMinutesForNotWorking = 1;
            usageStateRules.minMinutesForExessiveGravities = 5;

            % usageStateRules.mergeWithinHoursForNonWear = 4;
            % usageStateRules.minHoursForNonWear = 4;

            usageStateRules.mergeWithinHoursForStudyOver = 6;
            usageStateRules.minHoursForStudyOver = 2;% -> this is for classifying state as over. had been 12
            usageStateRules.mergeWithinFinalHoursOfStudy = 4;
            
            usageStateRules.mergeWithinHoursForStudyNotStarted = 6;
            usageStateRules.minHoursForStudyNotStarted = 2;% -> this is for classifying state as not yet starting.
            usageStateRules.mergeWithinHoursOfStudyNotStarted = 4;            
            
            usageStateRules.sampleRate = 1;
        end
    end
end


