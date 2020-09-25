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
        function obj = PAClassifyGravities(varargin)  % icountVector should be first argument,  nputSettings is second argument
            obj = obj@PAClassifyUsage(varargin{:});                        
        end
        
     
        % ======================================================================
        %> @brief Categorizes the study's usage state.
        %> @param obj Instance of PAClassifyGravities.
        %> @param vector of count activity to apply classification rules
        %> too.  If not provided, then the vector magnitude is used by
        %> default.
        %> @retval usageVec A vector of length datetimeNums whose values
        %> represent the usage category at each sample instance specified by
        %> @b dateTimeNum.
        %> - c usageVec(activeVec) = 30
        %> - c usageVec(inactiveVec) = 25
        %> - c usageVec(~awakeVsAsleepVec) = 20
        %> - c usageVec(sleepVec) = 15  sleep period (could be a nap)
        %> - c usageVec(remSleepVec) = 10  REM sleep
        %> - c usageVec(nonwearVec) = 5  Non-wear
        %> - c usageVec(studyOverVec) = 0  Non-wear, study over.
        %> @retval whereState Vector of wear vs non-wear state.  Each element represent the
        %> consecutive grouping of like states found in the usage vector.
        %> @note Wear states are categorized as follows:
        %> - c 5 Nonwear
        %> - c 10 Wear
        %> @retval startStopDatenums Start and stop datenums for each usage
        %> state row entry of usageState.
        % ======================================================================
        function [usageVec, wearState, startStopDateNums] = classifyUsageState(obj, gravityVec, datetimeNums, usageStateRules)

           
            % By default activity determined from vector magnitude signal
            if(nargin<2 || isempty(gravityVec))
                gravityVec = obj.dataVec;
            end
            if(nargin<3 || isempty(datetimeNums))
                datetimeNums = obj.datenumVec;
            end
            
            if(nargin>3)
                obj.setUsageClassificationRules(usageStateRules);
            end

            usageStateRules = obj.settings;
                                        
            tagStruct = obj.getActivityTags();

            %  STUCK_VALUES/MALFUNCTION = -5;
            %  UNKNOWN = -1;
            %  NONWEAR = 5;
            %  WEAR = 10;
            %  STUDYOVER=0;
            %  REMS = 10;
            %  NREMS = 15;
            %  NAPPING = 20;
            %  INACTIVE = 25;
            %  ACTIVE = 30;

            longClassificationMinimumDurationOfMinutes = usageStateRules.longClassificationMinimumDurationOfMinutes; %15; %a 15 minute or 1/4 hour filter
            shortClassificationMinimumDurationOfMinutes = usageStateRules.shortClassificationMinimumDurationOfMinutes; %5; %a 5 minute or 1/12 hour filter

            samplesPerMinute = obj.getSampleRate()*60; % samples per second * 60 seconds per minute
            samplesPerHour = 60*samplesPerMinute;

            longFilterLength = longClassificationMinimumDurationOfMinutes*samplesPerMinute;
            shortFilterLength = shortClassificationMinimumDurationOfMinutes*samplesPerMinute;

            longRunningActivitySum = obj.movingSummer(gravityVec,longFilterLength);
            shortRunningActivitySum = obj.movingSummer(gravityVec,shortFilterLength);

            %            usageVec = zeros(size(datetimeNums));
            usageVec = repmat(tagStruct.UNKNOWN,(size(datetimeNums)));

            offBodyThreshold = longClassificationMinimumDurationOfMinutes*onBodyVsOffBodyCountsPerMinuteCutoff;

            longActiveThreshold = longClassificationMinimumDurationOfMinutes*(activeVsInactiveCountsPerSecondCutoff*60);

            awakeVsAsleepVec = longRunningActivitySum>awakeVsAsleepCountsPerSecondCutoff; % 1 indicates Awake
            activeVec = longRunningActivitySum>longActiveThreshold; % 1 indicates active
            inactiveVec = awakeVsAsleepVec&~activeVec; %awake, but not active
            sleepVec = ~awakeVsAsleepVec; % not awake

            sleepPeriodParams.merge_within_samples = usageStateRules.mergeWithinHoursForSleep*samplesPerHour; % 3600*2*obj.getSampleRate();
            sleepPeriodParams.min_dur_samples = usageStateRules.minHoursForSleep*samplesPerHour; %3600*4*obj.getSampleRate();
            sleepVec = obj.reprocessEventVector(sleepVec,sleepPeriodParams.min_dur_samples,sleepPeriodParams.merge_within_samples);

            %% Short vector sum - applied to sleep states
            % Examine rem sleep on a shorter time scale
            shortOffBodyThreshold = shortClassificationMinimumDurationOfMinutes*onBodyVsOffBodyCountsPerMinuteCutoff;
            % shortActiveThreshold = shortClassificationMinimumDurationOfMinutes*(activeVsInactiveCountsPerSecondCutoff*60);
            shortNoActivityVec = shortRunningActivitySum<shortOffBodyThreshold;

            remSleepPeriodParams.merge_within_samples = usageStateRules.mergeWithinMinutesForREM*samplesPerMinute;  %merge within 5 minutes
            remSleepPeriodParams.min_dur_samples = usageStateRules.minMinutesForREM*samplesPerMinute;   %require minimum of 20 minutes
            remSleepVec = obj.reprocessEventVector(sleepVec&shortNoActivityVec,remSleepPeriodParams.min_dur_samples,remSleepPeriodParams.merge_within_samples);

            % Check for nonwear
            longNoActivityVec = longRunningActivitySum<offBodyThreshold;
            candidate_nonwear_events= obj.thresholdcrossings(longNoActivityVec,0);

            params.merge_within_sec = usageStateRules.mergeWithinHoursForNonWear*samplesPerHour; %4;
            params.min_dur_sec = usageStateRules.minHoursForNonWear*samplesPerHour; %4;

            if(~isempty(candidate_not_collecting))

                if(params.merge_within_sec>0)
                    merge_distance = round(params.merge_within_sec*obj.getSampleRate());
                    nonwear_events = obj.merge_nearby_events(candidate_nonwear_events,merge_distance);
                end

                if(params.min_dur_sec>0)
                    diff_sec = (candidate_nonwear_events(:,2)-candidate_nonwear_events(:,1))/obj.getSampleRate();
                    nonwear_events = candidate_nonwear_events(diff_sec>=params.min_dur_sec,:);
                end

                studyOverParams.merge_within_sec = usageStateRules.mergeWithinHoursForStudyOver*samplesPerHour; %-> group within 6 hours ..
                studyOverParams.min_dur_sec = usageStateRules.minHoursForStudyOver*samplesPerHour;%12;% -> this is for classifying state as over.
                merge_distance = round(studyOverParams.merge_within_sec*obj.getSampleRate());
                candidate_studyover_events = obj.merge_nearby_events(nonwear_events,merge_distance);
                diff_sec = (candidate_studyover_events(:,2)-candidate_studyover_events(:,1))/obj.getSampleRate();
                studyover_events = candidate_studyover_events(diff_sec>=studyOverParams.min_dur_sec,:);

            end

            nonwearVec = obj.unrollEvents(nonwear_events,numel(usageVec));

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
                if(diff_hours<=usageStateRules.mergeWithinHoursForStudyOver)
                    studyover_events(end) = numSamples;
                end
            end

            % We really just want one section of study over -> though this
            % may be worthwhile to note in cases where studies have large
            % gaps.
            if(size(studyover_events,1)>1)
                studyover_events = studyover_events(end,:);
            end

            studyOverVec = obj.unrollEvents(studyover_events,numel(usageVec));

            nonwear_events = obj.thresholdcrossings(nonwearVec,0);
            if(~isempty(nonwear_events))
                nonwearStartStopDateNums = [datetimeNums(nonwear_events(:,1)),datetimeNums(nonwear_events(:,2))];
                %durationOff = nonwear(:,2)-nonwear(:,1);
                %durationOffInHours = (nonwear(:,2)-nonwear(:,1))/3600;
            else
                nonwearStartStopDateNums = [];
            end
            nonwearState = repmat(tagStruct.NONWEAR,size(nonwear_events,1),1);

            %            wearVec = runningActivitySum>=offBodyThreshold;
            wearVec = ~nonwearVec;
            wear = obj.thresholdcrossings(wearVec,0);
            if(isempty(wear))
                % only have non wear then
                wearState = nonwearState;
                startStopDateNums = nonwearStartStopDateNums;
            else
                wearStartStopDateNums = [datetimeNums(wear(:,1)),datetimeNums(wear(:,2))];
                wearState = repmat(tagStruct.WEAR,size(wear,1),1);

                wearState = [nonwearState;wearState];
                [startStopDateNums, sortIndex] = sortrows([nonwearStartStopDateNums;wearStartStopDateNums]);
                wearState = wearState(sortIndex);
            end

            %usageVec(awakeVsAsleepVec) = 20;
            %usageVec(wearVec) = 10;   %        This is covered

            usageVec(activeVec) = tagStruct.ACTIVE;%35;  %None!
            usageVec(inactiveVec) = tagStruct.INACTIVE;%25;
            usageVec(~awakeVsAsleepVec) = tagStruct.NAP;%20;
            usageVec(sleepVec) = tagStruct.NREM;%15;   %Sleep period
            usageVec(remSleepVec) = tagStruct.REMS;%10;  %REM sleep
            usageVec(nonwearVec) = tagStruct.NONWEAR;%5;
            usageVec(studyOverVec) = tagStruct.STUDYOVER;%0;            
            usageVec(studyNotStarted) = tagStruct.STUDY_NOT_STARTED;
            usageVec(studyMalfunction) = tagStruct.MALFUNCTION;
            
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
            
            usageStateRules.longClassificationMinimumDurationOfMinutes=5;
            usageStateRules.shortClassificationMinimumDurationOfMinutes = 1;
            
            usageStateRules.accelerometerStuckMinutesCutoff = 1;  % exceeding the cutoff means you are awake            
            usageStateRules.workingGravitiesPerMinuteCutoff = 0; % exceeding the cutoff indicates working

            
            usageStateRules.minMinutesForStuck = 1;
            usageStateRules.minMinutesForNotWorking = 1;

            usageStateRules.mergeWithinHoursForNonWear = 4;
            usageStateRules.minHoursForNonWear = 4;

            usageStateRules.mergeWithinHoursForStudyOver = 6;
            usageStateRules.minHoursForStudyOver = 12;% -> this is for classifying state as over.
            usageStateRules.mergeWithinFinalHoursOfStudy = 4;
            
            usageStateRules.mergeWithinHoursForStudyNotStarted = 6;
            usageStateRules.minHoursForStudyNotStarted = 2;% -> this is for classifying state as not yet starting.
            usageStateRules.mergeWithinHoursOfStudyNotStarted = 4;            
            
            usageStateRules.sampleRate = 1;
        end
    end
end


