% ======================================================================
%> @brief Merge the fields of one struct with another.  Copies over
%> matching field values.  Similar to appendStruct, but now the second argument
%> is itself a struct with similar organization as the first
%> argument.
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
%> @note            [x]: [1.0]
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
function ltStruct = mergeStruct(ltStruct,rtStruct)

    if(isstruct(rtStruct))
        fnames = fieldnames(rtStruct);
        for f=1:numel(fnames)
            curField = fnames{f};
            if(isstruct(rtStruct.(curField)))
                if(isfield(ltStruct,curField))
                    ltStruct.(curField) = mergeStruct(ltStruct.(curField),rtStruct.(curField));
                else
                    ltStruct.(curField) = rtStruct.(curField);
                end
            else
                if(isfield(ltStruct,curField) && isa(ltStruct.(curField),'PAParam') && ~(isa(rtStruct.(curField),'PAParam')))
                    ltStruct.(curField).setValue(rtStruct.(curField));
                else
                    ltStruct.(curField) = rtStruct.(curField);
                end
            end
        end
    end
end