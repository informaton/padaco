% ======================================================================
%> @brief Evaluates the two structures, field for field, using the function name
%> provided.
%> @param operand A string name of the operation (via 'eval') to conduct at
%> the lowest level.  Additional operands include:
%> - passthrough Requires Optional field name to be set.
%> - calculateposition (requires rtStruct to have .xdata and .ydata
%> fields.
%> @param ltStruct A structure whose fields are either structures or vectors.
%> @param rtStruct A structure whose fields are either structures or vectors.
%> @param optionalDestField Optional field name to subset the resulting output
%> structure to (see last example).  This can be useful if the
%> output structure will be passed as input that expects a specific
%> sub field name for the values (e.g. line properties).  See last
%> example below.
%> @retval resultStruct A structure with same fields as ltStruct and rtStruct
%> whose values are the result of applying operand to corresponding
%> fields.
%> @note In the special case that operand is set to 'passthrough'
%> only ltStruct is used (enter ltStruct as the rtStruct value)
%> and the optionalDestField must be set (i.e. cannot be empty).
%> The purpose of the 'passthrough' operation is to insert a field named
%> optionalDestField between any field/non-struct value pairs.
%>
%> @note For example:
%> @note ltStruct =
%> @note         x: 2
%> @note     accel: [1x1 struct]
%> @note       [x]: 0.5000
%> @note       [y]: 1
%> @note
%> @note rtStruct =
%> @note         x: [10 10 2]
%> @note     accel: [1x1 struct]
%> @note             [x]: [10 10 2]
%> @note             [y]: [1 2 3]
%> @note
%> @note
%> @note
%> @note structEval('plus',rtStruct,ltStruct)
%> @note ans =
%> @note         x: [12 12 4]
%> @note     accel: [1x1 struct]
%> @note             [x]: [10.5000 10.5000 2.5000]
%> @note             [y]: [2 3 4]
%> @note
%> @note structEval('plus',rtStruct,ltStruct,'ydata')
%> @note ans =
%> @note         x.ydata: [12 12 4]
%> @note           accel: [1x1 struct]
%> @note                   [x].ydata: [10.5000 10.5000 2.5000]
%> @note                   [y].ydata: [2 3 4]
%> @note
%> @note PASensorData.structEval('passthrough',ltStruct,ltStruct,'string')
%> @note ans =
%> @note         x.string: 2
%> @note            accel: [1x1 struct]
%> @note                    [x].string: 0.5000
%> @note                    [y].string: 1
%> @note
%> @note structEval('overwrite',ltStruct,ltStruct,value)
%> @note ans =
%> @note         x: value
%> @note     accel: [1x1 struct]
%> @note              [x]: value
%> @note              [y]: value
%> @note
%> @note

%> @author Hyatt Moore IV 
% ======================================================================
function resultStruct = structEval(operand,ltStruct,rtStruct,optionalDestFieldOrValue)
    if(nargin < 4)
        optionalDestFieldOrValue = [];
    end

    if(isstruct(ltStruct))
        fnames = fieldnames(ltStruct);
        resultStruct = struct();
        for f=1:numel(fnames)
            curField = fnames{f};
            resultStruct.(curField) = structEval(operand,ltStruct.(curField),rtStruct.(curField),optionalDestFieldOrValue);
        end
    else
        if(strcmpi(operand,'calculateposition'))
            resultStruct.position = [rtStruct.xdata(1), rtStruct.ydata(1), 0];
        else
            if(~isempty(optionalDestFieldOrValue))
                if(strcmpi(operand,'passthrough'))
                    resultStruct.(optionalDestFieldOrValue) = ltStruct;
                elseif(strcmpi(operand,'overwrite'))
                    resultStruct = optionalDestFieldOrValue;
                elseif(strcmpi(operand,'repmat'))
                    resultStruct = repmat(ltStruct,optionalDestFieldOrValue);
                else
                    resultStruct.(optionalDestFieldOrValue) = feval(operand,ltStruct,rtStruct);
                end
            else
                resultStruct = feval(operand,ltStruct,rtStruct);
            end
        end
    end
end