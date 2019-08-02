% ======================================================================
%> @brief Case insensitive version of mergeStruct.  
%  Merge the fields of one struct with another.  Copies over
%> matching field values, where field name matches are case insensitive.
%> The field name of the first argument (ltStruct) is used for the merged
%> output when there is a case sensitivity difference between the field
%> names of both structs.
%> @param ltStruct A structure whose fields are to be appended by the other.
%> @param rtStruct A structure whose fields will be appended to the left structure, or overwrite 
%  same named fields.
%> @retval ltStruct The result of merging rtStruct with ltStruct.
%> @note For example:
%> @note ltStruct =
%> @note     accel: [1x1 struct]
%> @note            [x]: 0.5000
%> @note            [y]: 1
%> @note     lux: [1x1 struct]
%> @note            [z]: 0.5000
%> @note
%> @note rtStruct =
%> @note     accel: [1x1 struct]
%> @note            [X]: [1.0]
%> @note            [pos]: [0.5000, 1, 0]
%> @note
%> @note
%> @note structEval(rtStruct,ltStruct)
%> @note ans =
%> @note     accel: [1x1 struct]
%> @note              [x]: 1.0
%> @note              [y]: 1
%> @note              [pos]: [0.5000, 1, 0]
%> @note     lux: [1x1 struct]
%> @note            [z]: 0.5000
%> @note
% ======================================================================
function ltStruct = mergeStructi(ltStruct,rtStruct)
    if(isstruct(rtStruct))
        
        for curFieldCell=fieldnames(rtStruct)'
            curField = curFieldCell{1};
            ltField = getCaseSensitiveMatch(curField, ltStruct);
            if(isempty(ltField))
                ltStruct.(curField) = rtStruct.(curField);
            else
                if(isstruct(rtStruct.(curField)))
                    ltStruct.(ltField) = mergeStructi(ltStruct.(ltField),rtStruct.(curField));
                else
                    ltStruct.(ltField) = rtStruct.(curField);
                end
            end
        end
    end
end

