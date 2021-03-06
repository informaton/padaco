classdef PADataAnalysis < PAData
    
    properties(SetAccess=protected)
        dataVec;
    end
    methods
        
        function obj = PADataAnalysis(data, varargin)  
            obj@PAData(varargin{2:end});
            if(nargin)
                obj.setData(data);
            end
        end
   
        function didSet = setData(obj, data)
            didSet = false;
            if(nargin>1)
                obj.dataVec = data;
            end
        end
    end
    
    methods(Static)
        function didExport = exportToDisk()
            didExport = false;
        end


        %======================================================================
        %> @brief Moving summer finite impulse response filter.
        %> @param signal Vector of sample data to filter.
        %> @param filterOrder filter order; number of taps in the filter
        %> @retval summedSignal The filtered signal.
        %> @note The filter delay is taken into account such that the
        %> return signal is offset by half the delay.
        %======================================================================
        function summedSignal = movingSummer(signal, filterOrder)
            delay = floor(filterOrder/2);
            B = ones(filterOrder,1);
            A = 1;
            summedSignal = filter(B,A,signal);

            %account for the delay...
            summedSignal = [summedSignal((delay+1):end); zeros(delay,1)];
        end

        %% Analysis
        % =================================================================
        %> @brief Removes periods of activity that are too short and groups
        %> nearby activity groups together.
        %> @param logicalVec Initial vector which has 1's where an event or
        %> activity is occurring at that sample.
        %> @param min_duration_samples The minimum number of consecutive
        %> samples required for a run of on (1) samples to be kept.
        %> @param merge_distance_samples The maximum number of samples
        %> considered when looking for adjacent runs to merge together.
        %> Adjacent runs that are within this distance are merged into a
        %> single run beginning at the start of the first and stopping at the end of the last run.
        %> @retval processVec A vector of size (logicalVec) that has removed
        %> runs (of 1) that are too short and merged runs that are close enough
        %> together.
        %======================================================================
        function processVec = reprocessEventVector(logicalVec,min_duration_samples,merge_distance_samples)
            
            candidate_events= PAData.thresholdcrossings(logicalVec,0);
            
            if(~isempty(candidate_events))
                
                if(merge_distance_samples>0)
                    candidate_events = PASensorData.merge_nearby_events(candidate_events,merge_distance_samples);
                end
                
                if(min_duration_samples>0)
                    diff_samples = (candidate_events(:,2)-candidate_events(:,1));
                    candidate_events = candidate_events(diff_samples>=min_duration_samples,:);
                end
            end
            processVec = PAData.unrollEvents(candidate_events,numel(logicalVec));
        end
        

        %======================================================================
        %> @brief Helper function to convert an Nx2 matrix of start stop
        %> events into a single logical vector with 1's located at the
        %> locations corresponding to the samples inclusively between
        %> eventStartStops row entries.
        %> @param eventStartStop
        %> @param vectorSize The length or size of the sample data to unroll
        %> the start stop events back to.
        %> @note eventStartStop = thresholdCrossings(vector,0);
        %> @retval vector
        %======================================================================
        function vector = unrollEvents(eventsStartStop,vectorSize)
            vector = false(vectorSize,1);
            for e=1:size(eventsStartStop,1)
                vector(eventsStartStop(e,1):eventsStartStop(e,2))=true;
            end
        end

        %> @brief Returns start and stop pairs of the sample points where where line_in is
        %> greater (i.e. crosses) than threshold_line
        %> threshold_line and line_in must be of the same length if threshold_line is
        %> not a scalar value.
        %> @retval
        %> - Nx2 matrix of start and stop pairs of the sample points where where line_in is
        %> greater (i.e. crosses) than threshold_line
        %> - An empty matrix if no pairings are found
        %> @note Lifted from informaton/sev suite.  Authored by Hyatt Moore, IV (< June, 2013)
        function x = thresholdcrossings(line_in, threshold_line)

            if(nargin==1 && islogical(line_in))
                ind = find(line_in);
            else
                ind = find(line_in>threshold_line);
            end
            cur_i = 1;

            if(isempty(ind))
                x = ind;
            else
                x_tmp = zeros(length(ind),2);
                x_tmp(1,:) = [ind(1) ind(1)];
                for k = 2:length(ind)
                    if(ind(k)==x_tmp(cur_i,2)+1)
                        x_tmp(cur_i,2)=ind(k);
                    else
                        cur_i = cur_i+1;
                        x_tmp(cur_i,:) = [ind(k) ind(k)];
                    end
                end
                x = x_tmp(1:cur_i,:);
            end
        end

        % ======================================================================
        %> @brief Merges events, that are separated by less than some minimum number
        %> of samples, into a single event that stretches from the start of the first event
        %> and spans until the last event of each minimally separated event
        %> pairings.  Events that are not minimally separated by another
        %> event are retained with the output.
        %> @param event_mat_in is a two column matrix
        %> @param min_samples is a scalar value
        %> @retval merged_events The output of merging event_mat's events
        %> that are separated by less than min_samples.
        %> @retval merged_indices is a logical vector of the row indices that
        %> were merged from event_mat_in. - these are the indices of the
        %> in event_mat_in that are removed/replaced
        %> @note Lifted from SEV's CLASS_events.m - authored by Hyatt Moore
        %> IV
        % =================================================================
        function [merged_events, merged_indices] = merge_nearby_events(event_mat_in,min_samples)

            if(nargin==1)
                min_samples = 100;
            end

            merged_indices = false(size(event_mat_in,1),1);

            if(~isempty(event_mat_in))
                merged_events = zeros(size(event_mat_in));
                num_events_out = 1;
                num_events_in = size(event_mat_in,1);
                merged_events(num_events_out,:) = event_mat_in(1,:);
                for k = 2:num_events_in
                    if(event_mat_in(k,1)-merged_events(num_events_out,2)<min_samples)
                        merged_events(num_events_out,2) = event_mat_in(k,2);
                        merged_indices(k) = true;
                    else
                        num_events_out = num_events_out + 1;
                        merged_events(num_events_out,:) = event_mat_in(k,:);
                    end
                end
                merged_events = merged_events(1:num_events_out,:);
            else
                merged_events = event_mat_in;
            end
        end
        
        
        %> @brief Parses the input file's basename (i.e. sans folder and extension)
        %> for the study id.  This will vary according from site to site as
        %> there is little standardization for file naming.
        %> @param  File basename (i.e. sans path and file extension).
        %> @retval Study ID
        function studyID = getStudyIDFromBasename(baseName)
            % Appropriate for GOALS output
            try
                studyID = baseName(1:6);
            catch me
                studyID = baseName;
            end
        end
    end
end