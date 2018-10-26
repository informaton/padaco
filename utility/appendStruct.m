% ======================================================================
%> @brief Appends the fields of one to another.  Values for fields of the same name are taken from the right struct (rtStruct)
%> and built into the output struct.  If the left struct does not
%> have a matching field, then it will be created with the right
%> structs value.
%> @param ltStruct A structure whose fields are to be appended by the other.
%> @param rtStruct A structure whose fields are will be appened to the other.
%> @retval ltStruct The resultof append rtStruct to ltStruct.
%> @note For example:
%> @note ltStruct =
%> @note     ydata: [1 1]
%> @note     accel: [1x1 struct]
%> @note            [x]: 0.5000
%> @note            [y]: 1
%> @note
%> @note rtStruct =
%> @note     xdata: [1 100]
%> @note
%> @note structEval(ltStruct,rtStruct)
%> @note ans =
%> @note     ydata: [1 1]
%> @note     xdata: [1 100]
%> @note     accel: [1x1 struct]
%> @note            [xdata]: [1 100]
%> @note            [x]: [10.5000 10.5000 2.5000]
%> @note            [y]: [2 3 4]
%> @note
% ======================================================================
function ltStruct = appendStruct(ltStruct,rtStruct)
    if(isstruct(ltStruct))
        fnames = fieldnames(ltStruct);
        for f=1:numel(fnames)
            curField = fnames{f};
            if(isstruct(ltStruct.(curField)))
                ltStruct.(curField) = appendStruct(ltStruct.(curField),rtStruct);
            else
                % This is a bit of an issue ...
                appendNames=fieldnames(rtStruct);
                for a=1:numel(appendNames)
                    ltStruct.(appendNames{a}) = rtStruct.(appendNames{a});
                end
            end
        end
    end
end