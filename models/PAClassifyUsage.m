% ======================================================================
%> @file PAClassifyUsage.cpp
%> @brief Padaco count activity classifier
% ======================================================================
classdef PAClassifyUsage < PADataAnalysis

    properties (SetAccess = protected)
        %> @brief Structure of usage states determined from the following axes counts:
        %> @li x x-axis
        %> @li y y-axis
        %> @li z z-axis
        %> @li vecMag vectorMagnitude
        usage;
        
        % vector of datenum's which correspond to date and time of vector.
        datenumVec;
        
        %> @brief Mode of usage state vector (i.e. taken from getUsageActivity) for current frame rate.
        usageFrames;
    end
    
    methods(Abstract)
        [usageVec, wearState, startStopDateNums] = classifyUsageState(obj, countActivity, datetimeNums, usageStateRules)
    end

    methods

        % ======================================================================
        %> @brief Constructor for PAClassifyUsage class.
        %> @param vector of count values to process.
        %> @param pStruct Optional struct of parameters to use.  If it is not
        %> included then parameters from getDefaults method are used.
        %> @retval Instance of PAClassifyUsage.
         % =================================================================
        function obj = PAClassifyUsage(varargin)  % icountVector should be first argument,  nputSettings is second argument
            obj = obj@PADataAnalysis(varargin{:});            
            if(~isempty(obj.dataVec) && ~isempty(obj.datenumVec))
                obj = obj.classifyUsageState();
            end
        end
        
        function usageRules = getUsageClassificationRules(obj)
            usageRules = obj.settings;
        end

        function setDatenumVec(obj, datenums)
            obj.datenumVec = datenums;
        end
        
        %> @brief Updates the usage state rules with an input struct.
        function didSet = setUsageClassificationRules(obj, ruleStruct)
            didSet = false;
            try
                if(isstruct(ruleStruct))
                    obj.settings = mergeStructi(obj.settings, ruleStruct);
                    didSet = true;
                end
            catch me
                showME(me);
                didSet = false;
            end
        end

        % ======================================================================
        %> @brief Describes an activity.
        %> @note This is not yet implemented.
        %> @param obj Instance of PAClassifyUsage.
        %> @param categoryStr The type of activity to describe.  This is a string.  Values include:
        %> - c sleep
        %> - c wake
        %> - c inactivity
        %> @retval activityStruct A struct describing the activity.  Fields
        %> include:
        %> - c empty
        % ======================================================================
        function activityStruct = describeActivity(categoryStr)
            activityStruct = struct();
            switch(categoryStr)
                case 'sleep'
                    activityStruct.sleep = [];
                case 'wake'
                    activityStruct.wake = [];
                case 'inactivity'
                    activityStruct.inactivity = [];
            end
        end
        
        function fs = getSampleRate(obj)
%             fs = obj.settings.sampleRate;
            fs = obj.getSetting('sampleRate');
        end
    end

    methods(Static)


        % ======================================================================
        %> @brief Returns a structure of PAClassifyUsage's default parameters as a struct.
        %> when subclassed.  An empty struct is returned otherwise.  
        %> @retval usageStateRules A structure of default parameters 
        %> @note This is useful with the PASettings companion class.
        %> @note When adding default parameters, be sure to match saveable
        %> parameters in getSaveParameters()
        %======================================================================
        function usageStateRules = getDefaults()
            usageStateRules = struct();
        end

        function tagStruct = getActivityTags()
            tagStruct.ACTIVE = 35;
            tagStruct.INACTIVE = 25;
            tagStruct.NAP  = 20;
            tagStruct.NREM =  15;
            tagStruct.REMS = 10;
            tagStruct.WEAR = 10;
            tagStruct.NONWEAR = 5;
            tagStruct.STUDYOVER = 0;
            tagStruct.STUDY_NOT_STARTED = 1;
            
            tagStruct.UNKNOWN = -1;
            tagStruct.MALFUNCTION = -5;            
        end
    end
end


