function [data_c, data_r, cell_count,resetRegions] =  errorRez (time, ...
    data_c, data_r, data_f, CONST, cell_count, header, ignoreError, debug_flag)
% errorRez : links cells from the frame before to the current and attempts to
% resolve segmentation errors if the linking is inconsistent.
%
% INPUT :
%   time : current frame number
%   data_c : current time frame data (seg/err) file.
%   data_r : reverse time frame data (seg/err) file.
%   data_f : forward time frame data (seg/err) file.
%   CONST : segmentation parameters.
%   cell_count : last cell id used.
%   header : last cell id used.
%   debug_flag : 1 to display figures for debugging
%
% OUTPUT :
%   data_c : updated current time frame data (seg/err) file.
%   data_r : updated reverse time frame data (seg/err) file.
%   cell_count : last cell id used.
%   resetRegions : if true, regions were modified and this frame needs to
%   be relinked.
%
%
% Copyright (C) 2016 Wiggins Lab
% Written by Stella Stylianidou
% University of Washington, 2016
% This file is part of SuperSegger.
%
% SuperSegger is free software: you can redistribute it and/or modify
% it under the terms of the GNU General Public License as published by
% the Free Software Foundation, either version 3 of the License, or
% (at your option) any later version.
%
% SuperSegger is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
% GNU General Public License for more details.
%
% You should have received a copy of the GNU General Public License
% along with SuperSegger.  If not, see <http://www.gnu.org/licenses/>.

global SCORE_LIMIT_MOTHER
global SCORE_LIMIT_DAUGHTER
global REMOVE_STRAY
global header_string
global regToDelete
header_string = header;
verbose = CONST.parallel.verbose;
MIN_LENGTH = 10;
REMOVE_STRAY = CONST.trackOpti.REMOVE_STRAY;
SCORE_LIMIT_DAUGHTER =  CONST.trackOpti.SCORE_LIMIT_DAUGHTER;
SCORE_LIMIT_MOTHER = CONST.trackOpti.SCORE_LIMIT_MOTHER;
DA_MIN = CONST.trackOpti.DA_MIN;
DA_MAX =  CONST.trackOpti.DA_MAX;
regToDelete = [];
resetRegions = false;

% set all ids to 0
data_c.regs.ID = zeros(1,data_c.regs.num_regs);
modRegions = [];
for regNum =  1 : data_c.regs.num_regs;

    if data_c.regs.ID(regNum) ~= 0
          disp ([header, 'ErRes: Frame: ', num2str(time), ' already has an id ',num2str(regNum)]);
    elseif ismember (regNum,modRegions)
        disp ([header, 'ErRes: Frame: ', num2str(time), ' already modified ',num2str(regNum)]);
    else
        rCellsFromC = data_c.regs.map.r{regNum}; % where regNum maps in reverse
        
        if ~isempty(rCellsFromC)
            cCellsTransp = data_c.regs.revmap.r{rCellsFromC};
        else
            cCellsTransp = 0;
        end
        
        
        %%% maps to 0
        if numel(rCellsFromC) == 0 % maps to 0 in the previous frame - stray
            
            % think whether this is useful :  numel(mapRC) == 0
            if (time ~= 1) && (hasNoFwMapping(data_c,regNum) && REMOVE_STRAY)
                % deletes the regions not appearing at time = 1 that do not map to anything
                % or if remove_stray flag is set to true.
                data_c.regs.error.label{regNum} = ['Frame: ', num2str(time), ...
                    ', reg: ', num2str(regNum), '. is a stray region - Deleted.'];
                if verbose
                    disp([header, 'ErRes: ',data_c.regs.error.label{regNum}] );
                end
                regToDelete = [regToDelete;regNum];
                resetRegions = true;
            else % maps to a region in the next frame, or time is 1
                if time~=1
                    data_c.regs.error.label{regNum} = ['Frame: ', num2str(time), ...
                        ', reg: ', num2str(regNum), '. is a stray region.'];                   
                    if verbose
                        disp([header, 'ErRes: ',data_c.regs.error.label{regNum}] );
                    end
                end
                [data_c,cell_count] = createNewCell (data_c, regNum, time, cell_count);
            end
            
        elseif numel(rCellsFromC) == 1 &&  numel (cCellsTransp) == 1 && all(data_r.regs.map.f{rCellsFromC} == regNum)
            % MAPS TO ONE AND AGREES
            % sets cell ID from mapped reg, updates death in data_r
            [data_c, data_r] = continueCellLine( data_c, regNum, data_r, rCellsFromC, time, 0);
            
        elseif numel(rCellsFromC) == 1 && numel(data_r.regs.map.f{rCellsFromC}) == 1 &&  numel (cCellsTransp) == 2
            %% regNum maps to mapCR, mapCR maps to two in current, but mapCR maps to one otherwise, but disagreement
            
            sister1 = regNum;
            sister2 = cCellsTransp (cCellsTransp~=regNum);
            mapRC = cCellsTransp;
            mother = rCellsFromC;
            
            if debug_flag
                % red in c maps to blue in r, blue in r maps to green in c
                imshow(cat(3,0.5*ag(data_c.phase) + 0.5*ag(data_c.regs.regs_label==sister1),...
                    ag(data_r.regs.regs_label == mother),ag(data_c.regs.regs_label==sister2)));
                keyboard;
            end
            
            totAreaC = data_c.regs.props(sister1).Area + data_c.regs.props(sister2).Area;
            totAreaR =  data_r.regs.props(mother).Area;
            AreaChange = (totAreaC-totAreaR)/totAreaC;
            divAreaChange = (AreaChange > DA_MIN && AreaChange < DA_MAX);
            haveNoMatch = (isempty(data_c.regs.map.f{sister1}) || isempty(data_c.regs.map.f{sister2}));
            matchToTheSame = ~haveNoMatch && all(ismember(data_c.regs.map.f{sister1}, data_c.regs.map.f{sister2}));
            oneIsSmall = (data_c.regs.info(sister1,1) < MIN_LENGTH) ||  (data_c.regs.info(sister1,1) < MIN_LENGTH);
            if divAreaChange && ~ignoreError && ~isempty(data_f) && (haveNoMatch || matchToTheSame || oneIsSmall)
                % r: one has no forward mapping, or both map to the same in fw, or one small
                % wrong division merge cells
                [data_c,mergeReset] = merge2Regions (data_c, sister1, sister2, CONST);
                modRegions = [modRegions;sister1;sister2];   
                resetRegions = (resetRegions || mergeReset);
            elseif divAreaChange
                [data_c, data_r, cell_count] = createDivision (data_c,data_r,mother,sister1,sister2, cell_count, time,header, verbose);
                modRegions = [modRegions;sister1;sister2];                
            else
                % map to best, remove mapping from second
                [data_c,data_r,cell_count,reset_tmp,modids_tmp] = mapBestOfTwo (data_c, mapRC, data_r, rCellsFromC, time, verbose, cell_count,header);
                resetRegions = or(reset_tmp,resetRegions);
                modRegions = [modRegions;modids_tmp];
            end
            
        elseif numel(rCellsFromC) == 1 && numel(data_r.regs.map.f{rCellsFromC}) == 2
            % the 1 in reverse maps to two in current : possible splitting event
            mother = rCellsFromC;
            sister1 = regNum;
            mapRC = data_r.regs.map.f{mother};
            sister2 = mapRC (mapRC~=regNum);
            sister2Mapping = data_c.regs.map.r{sister2};
            
            if numel(sister2) == 1 && any(mapRC==regNum) && ~isempty(sister2Mapping) && all(sister2Mapping == mother)
                
                haveNoMatch = (isempty(data_c.regs.map.f{sister1}) || isempty(data_c.regs.map.f{sister2}));
                matchToTheSame = ~haveNoMatch && all(ismember(data_c.regs.map.f{sister1}, data_c.regs.map.f{sister2}));
                
                % r: one has no forward mapping, or both map to the same in fw
                if  ~isempty(data_f) && (haveNoMatch || matchToTheSame)
                    % wrong division merge cells
                    if ~ignoreError
                        [data_c,reset_tmp] = merge2Regions (data_c, sister1, sister2, CONST);
                         modRegions = [modRegions;sister1;sister2]; 
                    else
                        [data_c,data_r,cell_count,reset_tmp,modids_tmp] = mapBestOfTwo (data_c, mapRC, data_r, rCellsFromC, time, verbose, cell_count,header);
                        modRegions = [modRegions;modids_tmp]; 
                    end
                    resetRegions = or(reset_tmp,resetRegions);
                else
                    [data_c, data_r, cell_count] = createDivision (data_c,data_r,mother,sister1,sister2, cell_count, time,header, verbose);
                    modRegions = [modRegions;sister1;sister2]; 
                end
            elseif numel(sister2) == 1 && any(mapRC==regNum) && any(data_c.regs.map.r{sister2} ~= mother)
                % map the one-to-one to mother
                [data_c, data_r] = continueCellLine( data_c, regNum, data_r, rCellsFromC, time, 0);
                
            elseif  ~any(mapRC==regNum)
                % ERROR NOT FIXED :  mapCR maps to mother. but mother maps to
                % two other cells..
                % OTHER POSSIBLE RESOLUTIONS.. :
                % 1 : merging missing, cell divided but piece fell out - check
                % if all three should be mapped
                % 2 : get the best two couples of the three
                
                % force mapping
                sister1 = regNum;
                sister2 = mapRC(1);
                sister3 = mapRC(2);
                
                % make a new cell for regNum with error...
                [data_c,cell_count] = createNewCell (data_c, regNum, time, cell_count);
                data_c.regs.error.r(regNum) = 1;
                data_c.regs.error.label{regNum} = ['Frame: ', num2str(time),...
                    ', reg: ', num2str(regNum),'. Incorrect Mapping 1 to 2 - making a new cell'];
                
                if verbose
                    disp([header, 'ErRes: ', data_c.regs.error.label{regNum}]);
                end
                % red : regNum, green : ones mother maps to, blue : mother
                if debug_flag
                    imshow(cat(3,0.5*ag(data_c.phase) + 0.5*ag(data_c.regs.regs_label==regNum), ...
                        ag((data_c.regs.regs_label == mapRC(1)) + ...
                        (data_c.regs.regs_label==mapRC(2))),ag(data_r.regs.regs_label==mother)));
                    keyboard;
                end
            else
                data_c.regs.error.label{regNum} = ['Frame: ', num2str(time),...
                ', reg: ', num2str(regNum),'. Error not fixed - two to 1 but don''t know what to do.'];
            
            if verbose
                disp([header, 'ErRes: ', data_c.regs.error.label{regNum}]);
            end
           
            end
        elseif numel(rCellsFromC) == 2
            % 1 in current maps to two in reverse
            % try to find a segment that should be turned on in current
            % frame, exit regNum loop, make time - 1 and relink
            
            % The two in reverse map to regNum only
            twoInRMapToCOnly = numel(data_r.regs.map.f{rCellsFromC(1)}) == 1 && data_r.regs.map.f{rCellsFromC(1)}==regNum && ...
                numel(data_r.regs.map.f{rCellsFromC(2)}) == 1 && data_r.regs.map.f{rCellsFromC(2)}==regNum;
            
            if debug_flag
                imshow(cat(3,0.5*ag(data_c.phase), 0.7*ag(data_c.regs.regs_label==regNum),...
                    ag((data_r.regs.regs_label==rCellsFromC(1)) + (data_r.regs.regs_label==rCellsFromC(2)))));
                keyboard;
            end
            
            
            if twoInRMapToCOnly & ~ignoreError
                [data_c,success] = missingSeg2to1 (data_c,regNum,data_r,rCellsFromC,CONST);
            else
                success = false;
            end
            
            if success % segment found
                data_c.regs.error.r(regNum) = 0;
                data_c.regs.error.label{regNum} = ['Frame: ', num2str(time),...
                    ', reg: ', num2str(regNum),'. Segment added to fix 2 to 1 error'];
                
                if verbose
                    disp([header, 'ErRes: ', data_c.regs.error.label{regNum}]);
                end
                if debug_flag
                    imshow(cat(3,ag(data_c.regs.regs_label == regNum)+0.5*ag(data_c.phase),...
                        ag(data_r.regs.regs_label == rCellsFromC(1)),...
                        ag(data_r.regs.regs_label == rCellsFromC(2))));
                    keyboard;
                end
                resetRegions = true;
            else
                % ERROR NOT FIXED : link to the one with the best score
                [data_c,data_r] = mapToBestOfTwo (data_c, regNum, data_r, rCellsFromC, time, verbose,header);
            end
        else
            data_c.regs.error.label{regNum} = ['Frame: ', num2str(time),...
                ', reg: ', num2str(regNum),'. Error not fixed'];
            
            if verbose
                disp([header, 'ErRes: ', data_c.regs.error.label{regNum}]);
            end
            if debug_flag
                intDisplay (data_r,rCellsFromC,data_c,regNum);
                keyboard;
            end
            
        end
        
    end
end
%intDisplay (data_c,regToDelete,data_f,[]);
[data_c] = deleteRegions( data_c,regToDelete);

end



function intDisplay (data_c,regC,data_f,regF)
% intDisplay : displays linking
% reg : maskF
% green : maskC
% blue : all cell masks  in c


maskC = data_c.regs.regs_label*0;
for c = 1 : numel(regC)
    if ~isnan(regC(c))
        maskC = maskC + (data_c.regs.regs_label == regC(c))>0;
    end
end

if ~isempty (data_f)
    maskF = data_f.regs.regs_label*0;
    if isempty(regF)
        disp('nothing')
        imshow (cat(3,0*ag(maskF),ag(maskC),ag(data_c.mask_cell)));
    else
        for f = 1 : numel(regF)
            if ~isnan(regF(f))
                maskF = maskF + (data_f.regs.regs_label == regF(f))>0;
            end
        end
        imshow (cat(3,ag(maskF),ag(maskC),ag(data_c.mask_cell)));
    end
end
end




function [ data_c, data_r, cell_count ] = createDivision (data_c,data_r,mother,sister1,sister2, cell_count, time, header, verbose)
global SCORE_LIMIT_MOTHER
global SCORE_LIMIT_DAUGHTER


errorM  = (data_r.regs.scoreRaw(mother) < SCORE_LIMIT_MOTHER );
errorD1 = (data_c.regs.scoreRaw(sister1) < SCORE_LIMIT_DAUGHTER);
errorD2 = (data_c.regs.scoreRaw(sister2) < SCORE_LIMIT_DAUGHTER);

% if debug_flag && ~data_c.regs.ID(sister1)
%     figure(1);
%     imshow(cat(3,ag(data_c.phase), ag(ag(data_c.regs.regs_label==sister2) +ag(data_c.regs.regs_label==sister1)),ag(data_r.regs.regs_label==mother)));
%     keyboard;
% end

if ~(errorM || errorD1 || errorD2)
    % good scores for mother and daughters
    % sets ehist to 0 (no error) and stat0 to 1 (successful division)
    data_c.regs.error.label{sister1} = (['Frame: ', num2str(time),...
        ', reg: ', num2str(sister1),' and ', num2str(sister2),' . good cell division from mother reg', num2str(mother),'. [L1,L2,Sc] = [',...
        num2str(data_c.regs.L1(sister1),2),', ',num2str(data_c.regs.L2(sister1),2),...
        ', ',num2str(data_c.regs.scoreRaw(sister1),2),'].']);
    if verbose
        disp([header, 'ErRes: ', data_c.regs.error.label{sister1}] );
    end
    data_r.regs.error.r(mother) = 0;
    data_c.regs.error.r(sister1) = 0;
    data_c.regs.error.r(sister2) = 0;
    [data_c, data_r, cell_count] = markDivisionEvent( ...
        data_c, sister1, data_r, mother, time, 0, sister2, cell_count);
    
else
    % bad scores for mother or daughters
    % sets ehist to 1 ( error) and stat0 to 0 (non successful division)
    errorStat = 1;
    %data_c.regs.error.r(sister1) = 1;
    data_r.regs.error.r(mother) = 0;
    data_c.regs.error.r(sister1) = 0;
    data_c.regs.error.r(sister2) = 0;
    
    data_c.regs.error.label{sister1} = (['Frame: ', num2str(time),...
        ', reg: ', num2str(sister1),' and ', num2str(sister2),...
        '. 1 -> 2 mapping  from mother reg', num2str(mother),', but not good cell [sm,sd1,sd2,slim] = [',...
        num2str(data_r.regs.scoreRaw(mother),2),', ',...
        num2str(data_c.regs.scoreRaw(sister1),2),', ',...
        num2str(data_c.regs.scoreRaw(sister2),2)]);
    
    if verbose
        disp([header, 'ErRes: ', data_c.regs.error.label{sister1}] );
    end
    [data_c, data_r, cell_count] = markDivisionEvent( ...
        data_c, sister1, data_r, mother, time, errorStat, sister2, cell_count);
    
end
end


function result = hasNoFwMapping (data_c,regNum)
result = isempty(data_c.regs.map.f{regNum});
end


function [data_c,data_r] = mapToBestOfTwo (data_c, regNum, data_r, mapCR, time, verbose,header)
% maps to best from two forward

cost1 = data_c.regs.cost.r(regNum,mapCR(1));
cost2 = data_c.regs.cost.r(regNum,mapCR(2));

if cost1<cost2 || isnan(cost2)
    data_c.regs.error.r(regNum) = 2;
    errorStat = 1;
    data_c.regs.error.label{regNum} = ['Frame: ', num2str(time),...
        ', reg: ', num2str(regNum),'. Map to minimum cost'];
    
    if verbose
        disp([header, 'ErRes: ', data_c.regs.error.label{regNum}]);
    end
    [data_c, data_r] = continueCellLine(data_c, regNum, data_r, mapCR(1), time, errorStat);
    
else
    errorStat = 1;
    data_c.regs.error.r(regNum) = 2;
    data_c.regs.error.label{regNum} = ['Frame: ', num2str(time),...
        ', reg: ', num2str(regNum),'. Map to minimum cost'];
    
    if verbose
        disp([header, 'ErRes: ', data_c.regs.error.label{regNum}]);
    end
    [data_c, data_r] = continueCellLine(data_c, regNum, data_r, mapCR(2), time, errorStat);
    
end
end


function [data_c,data_r,cell_count,resetRegions,idsOfModRegions] = mapBestOfTwo ...
    (data_c, mapRC, data_r, mapCR, time, verbose, cell_count,header)
% maps to best from two forward
global regToDelete
global REMOVE_STRAY
resetRegions = 0;
[~,minInd] = min (data_c.regs.dA.r(mapRC));
keeper = mapRC(minInd);
remove = mapRC(mapRC~=keeper);
[data_c, data_r] = continueCellLine( data_c, keeper, data_r, mapCR, time, 0);
data_c.regs.revmap.r{mapCR} = keeper;


data_c.regs.error.r(remove) = 1;
idsOfModRegions = [remove;keeper];
if REMOVE_STRAY && hasNoFwMapping(data_c,remove)
     data_c.regs.error.label{remove} = (['Frame: ', num2str(time),...
        ', reg: ', num2str(remove),' was not the best match for ', num2str(mapCR),' and was deleted.' num2str(keeper) , ' was.']);
    if verbose
        disp([header, 'ErRes: ', data_c.regs.error.label{remove}] );
    end
    regToDelete = [regToDelete;remove];
    resetRegions = true;
else
    [data_c,cell_count] = createNewCell (data_c, remove, time, cell_count);
    data_c.regs.error.label{remove} = (['Frame: ', num2str(time),...
        ', reg: ', num2str(remove),' was not the best match for ', num2str(mapCR),' made into a new cell.']);
    if verbose
        disp([header, 'ErRes: ', data_c.regs.error.label{remove}] );
    end
end
end