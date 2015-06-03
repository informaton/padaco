function cellout =  cells2cell(varargin)
%similar to cells2mat, but converts a variable number of independent cells
%into a single cell;
%    
% pass in multiple cells and convert to a single matrix of
% size = numel(varargin) x numel(varargin{1})
%
% Written: Hyatt Moore IV
% 10.10.12

cellout = varargin;
% rows = numel(varargin);
% cellout = cell(rows,1);
% [cellout{:}] = varargin;
end