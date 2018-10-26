


% ======================================================================
%> @brief Inserts the second argument into any empty fields of the first
%> struct argument.
%> @param ltStruct A structure whose empty fields will be set to the second argument.
%> @param rtStruct A structure
%> @retval ltStruct The structure that results from inserting rtStruct into ltStruct.
%> @note For example:
%> @note ltStruct =
%> @note     accel: [1x1 struct]
%> @note            [x]: []
%> @note            [y]: []
%> @note     lux: []
%> @note
%> @note rtStruct =
%> @note     color: 'k'
%> @note     data: [1x1 struct]
%> @note            [pos]: [0.5000, 1, 0]
%> @note
%> @note
%> @note structEval(rtStruct,ltStruct)
%> @note ans =
%> @note     accel: [1x1 struct]
%> @note              [x]: [1x1 struct]
%> @note                   color: 'k'
%> @note                   data: [1x1 struct]
%> @note                         [pos]: [0.5000, 1, 0]
%> @note              [y]: [1x1 struct]
%> @note                   color: 'k'
%> @note                   data: [1x1 struct]
%> @note                         [pos]: [0.5000, 1, 0]
%> @note     lux: [1x1 struct]
%> @note          color: 'k'
%> @note          data: [1x1 struct]
%> @note                [pos]: [0.5000, 1, 0]
%> @note
% ======================================================================
function ltStruct = overwriteEmptyStruct(ltStruct,rtStruct)
    if(isstruct(ltStruct))
        fnames = fieldnames(ltStruct);
        for f=1:numel(fnames)
            curField = fnames{f};
            ltStruct.(curField) = overwriteEmptyStruct(ltStruct.(curField),rtStruct);
        end
    elseif(isempty(ltStruct))
        ltStruct = rtStruct;
    end
end