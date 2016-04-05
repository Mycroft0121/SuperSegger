function CONST = loadConstantsNN( res, PARALLEL_FLAG )
% loadConstants loads the parameters for the superSegger/trackOpti package.
% If you want to customize the constants DO NOT CHANGE
% THIS FILE! Rename this file loadConstantsMine.m and
% put in somehwere in the path.
% That file will load automatically rather than this one.
% When you make loadConstantsMine.m, change
% disp( 'loadConstants: Initializing.')
% to loadConstantsMine to avoid confusion.
%
% INPUT :
%   res : number for resolution of microscope used (60 or 100) for E. coli
%         or use a string as shown below
%   PARALLEL_FLAG : 1 if you want to use parallel computation
%                   0 for single core computation
%
% Copyright (C) 2016 Wiggins Lab
% University of Washington, 2016
% This file is part of SuperSeggerOpti.

if nargin < 1 || isempty( res )
    res = 60;
end

if ~exist('PARALLEL_FLAG','var') || isempty( PARALLEL_FLAG )
    PARALLEL_FLAG = true;
end


disp( 'loadConstants: Initializing.');

% Octoscope setting
CONST.imAlign.DAPI    = [-0.0354   -0.0000    1.5500   -0.3900];
CONST.imAlign.mCherry = [-0.0512   -0.0000   -1.1500    1.0000];
CONST.imAlign.GFP     = [ 0.0000    0.0000    0.0000    0.0000];

CONST.imAlign.out = {CONST.imAlign.GFP, ...    % c1 channel name
    CONST.imAlign.GFP,...  % c2 channel name
    CONST.imAlign.GFP};        % c3 channel name


%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%                                                                         %
% Parallel processing on multiple cores :
%                                                                         %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% PARALLEL FOR MATLAB 2015
if PARALLEL_FLAG
    poolobj = gcp('nocreate'); % If no pool, do not create new one.
    if isempty(poolobj)
        poolobj = parpool('local')
    end
    poolobj.IdleTimeout = 360; % close after idle for 3 hours
    CONST.parallel.parallel_pool_num = poolobj.NumWorkers
else
    CONST.parallel.parallel_pool_num = 0;
end

CONST.parallel.xy_parallel = 0;
CONST.parallel.PARALLEL_FLAG = PARALLEL_FLAG;
CONST.parallel.show_status   = ~(CONST.parallel.parallel_pool_num);

% PARALLEL FOR MATLAB 2014
% if PARALLEL_FLAG
%     if exist( 'matlabpool', 'file' )
%         CONST.parallel_pool_num = matlabpool('size');
%         if ( CONST.parallel_pool_num == 0 )
%             matlabpool
%             try
%                 CONST.parallel_pool_num =  matlabpool('size');
%             catch
%                 distcomp.feature('LocalUseMpiexec',false)
%                 CONST.parallel_pool_num =  matlabpool('size');
%             end
%             disp( ['loadConstants: Parallel processing pool opened. Size ', num2str(CONST.parallel_pool_num),'.' ] );
%
%         else
%             disp( ['loadConstants: Parallel processing pool already open. Size ', num2str( CONST.parallel_pool_num),'.']);
%         end
%     else
%         disp( 'loadConstants: Attempted to open matlab pool, but no parallel processing toolbox.' );
%         CONST.parallel_pool_num = 0;
%     end
% else
%     CONST.parallel_pool_num = 0;
%     %pause( 2 );
% end
%
%
%
%
% CONST.PARALLEL_FLAG = PARALLEL_FLAG;
% CONST.show_status   = ~(CONST.parallel_pool_num);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%                                                                         %
% Specify scope resolution here                                           %
%                                                                         %
% Set the res flag to apply to your exp.                                  %
%                                                                         %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


% Values for setting res
%
% '100XPa': loadConstants 100X Pseudomonas
% '60XEc' : loadConstants 60X Ecoli
% '100XEc': loadConstants 100X Ecoli

% R100XEc    = 1; % for 100X unbinned, 6 um pixels
% R100XB   = 2; % for 100X 2x2 binned, 6 um pixels
% R60XEc     = 3; % for 60X, 6 um pixels
% R100XPa  = 4; % for 100X, Pseudomonas
% R60XPa   = 5; % for 60X, Pseudomonas
% R60XEcHR = 6; % for 60X, coli slow high density.
% RR60XEcLB = 7; % for 60X, coli slow high density.
% R60XA    = 8; % for 60X, coli ASKA
% R60XPaM  = 9; % for 60X, Pseudomonas Minimal
% R60XPaM2 = 10; % for 60X, Pseudomonas Minimal
% R60XBthai = 11;

% CONST.100XEc    = 100XEc;
% CONST.R100XB   = R100XB;
% CONST.60XEc     = 60XEc;
% CONST.100XPa  = 100XPa;
% CONST.60XPa   = 60XPa;
% CONST.60XEcHR = 60XEcHR;
% CONST.R60XEcLB = R60XEcLB;
% CONST.60XA    = 60XA;
% CONST.60XPaM  = 60XPaM;
% CONST.60XPaM2 = 60XPaM2;
% CONST.60XPaM2 = 60XBthai;



cl = class(res);

if strcmp(cl,'double' )  && res == 60
    disp('loadConstants: 60X');
    CONST = load('60XEcnn_FULLCONST.mat');
elseif strcmp(cl,'double' )  && res == 100
    disp('loadConstants:  100X');
    CONST = load('100XEcnn_FULLCONST.mat');
elseif strcmp(cl, 'char' );
    if strcmp(res,'60XEc') % 1
        disp('loadConstants:  60X Ecoli');
        CONST = load('60XEcnn_FULLCONST.mat');
    elseif strcmp(res,'100XEc') % 2
        disp('loadConstants:  100X Ecoli');
        CONST = load('100XEcnn_FULLCONST.mat');
    elseif strcmp(res,'60XEcLB') % 2
        disp('loadConstants:  60X LB Ecoli');
        CONST = load('60XEcLBnn_FULLCONST.mat');
    else
        error('Constants not loaded : no match found. Aborting.');
    end
else
    error('Constants not loaded : no match found. Aborting.');
end




end