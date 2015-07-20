function matout =  cells2mat(varargin)
%similar to cell2mat, however, this implicitly handles the case
% of multiple cells by using the varargin feature of MATLAB which
% short cuts the typical process of 
%    matout = cell(size(varargin));
%    [matout{:}] = varargin;
%    matout = cell2mat(matout);
%    
% pass in multiple cells and convert to a single matrix of
% size = numel(varargin) x numel(varargin{1})
%
% Written: Hyatt Moore IV
% 10.10.12

rows = numel(varargin);
matout = reshape(cell2mat(varargin),[],rows)';
end