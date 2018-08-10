% ======================================================================
%> @brief Evaluates the two structures, field for field, using the function name
%> provided.
%> @param operand A string name of the operation (via 'eval') to conduct at
%> the lowest level.
%> @param ltStruct A structure whose fields are either structures or vectors.
%> @param A Matrix value of the same dimension as the first structure's (ltStruct)
%> non-struct field values.
%> @param optionalDestField Optional field name to subset the resulting output
%> structure to (see last example).  This can be useful if the
%> output structure will be passed as input that expects a specific
%> sub field name for the values (e.g. line properties).  See last
%> example below.
%> @retval resultStruct A structure with same fields as ltStruct and optionally
%> the optionalDestField whose values are the result of applying operand to corresponding
%> fields and the input matrix.
%>
%> @note For example:
%> @note
%> @note ltStruct =
%> @note         x.position: [10 10 2]
%> @note     accel: [1x1 struct]
%> @note             [x.position]: [10 10 2]
%> @note             [y.position]: [1 2 3]
%> @note
%> @note A =
%> @note     [1 1 0]
%> @note
%> @note structEval('plus',ltStruct,A)
%> @note ans =
%> @note         x.position: [11 11 2]
%> @note     accel: [1x1 struct]
%> @note             [x.position]: [11 11 2]
%> @note             [y.position]: [2 3 3]
%> @note

%> @author Hyatt Moore IV
% ======================================================================
function resultStruct = structScalarEval(operand,ltStruct,A,optionalDestField)
    if(nargin < 4)
        optionalDestField = [];
    end
    
    if(isstruct(ltStruct))
        fnames = fieldnames(ltStruct);
        resultStruct = struct();
        for f=1:numel(fnames)
            curField = fnames{f};
            resultStruct.(curField) = structScalarEval(operand,ltStruct.(curField),A,optionalDestField);
        end
    else
        if(~isempty(optionalDestField))
            if(strcmpi(operand,'passthrough'))
                resultStruct.(optionalDestField) = ltStruct;
            else
                resultStruct.(optionalDestField) = feval(operand,ltStruct,A);
            end
        else
            resultStruct = feval(operand,ltStruct,A);
        end
    end
end
