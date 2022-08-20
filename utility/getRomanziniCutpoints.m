% Based on 1 minute epochs for count data as published by Romanzini et al., 2012
% (Calibration of ActiGraph GT3X, Actical and RT3 accelerometers in adolescents)
% % Returns:
%     romanzini_sb: [0 720]
%     romanzini_lpa: [721 3027]
%     romanzini_mpa: [328 4447]
%     romanzini_vpa: [4448 Inf]
function [rziStruct, fields, cutpoints] = getRomanziniCutpoints()
        fields = {'romanzini_sb','romanzini_mvpa','romanzini_lpa','romanzini_mpa','romanzini_vpa'};
        cutpoints = {[0, 720], [3028, inf], [721, 3027], [3028, 4447], [4448, inf]};
        rziStruct = mkstruct(fields, cutpoints);
end