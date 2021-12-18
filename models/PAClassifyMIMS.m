% ======================================================================
%> @file PAClassifyMIMS.cpp
%> @brief Placeholder for MIMs activity classifier class - currently the same as counts classifier.
% ======================================================================
classdef PAClassifyMIMS < PAClassifyCounts

    methods        
        function obj = PAClassifyMIMS(varargin)  %  (mims vector, inputSettings)
            obj = obj@PAClassifyCounts(varargin{:});                        
        end
    end
end
     