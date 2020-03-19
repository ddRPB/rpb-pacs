-- This script is querying ConQuest PACS in order to retrieve
-- DICOM Series instance restricted via QueryString parameters
-- and move all patient data to different AE title

-- UseCases:
-- should be deployed on DICOM proxy (clinical/research) or DICOM data (clinical/research) nodes

local patientid = CGI('PatientID');
local studyuid = CGI('StudyUID');
local seriesuid = CGI('SeriesUID');
local aet = CGI('AET');

-- Functions declaration

-- Check for valid not empty string
function isempty(s)
    return s == nil or s == '';
end

-- Get source AET
function getsource()
    if source == '(local)' then
        return servercommand('get_param:MyACRNema');
    else
        return source;
    end
end

-- Get AET nodes
function getnodes()
    -- TODO: ideally this would be readable from config of DICOM proxy
    -- Lua has a method get_amap(index) that returns the list
    --for i = 0, #get_amap(index) do
    --    print(get_amap(i));
    --end
    return {};
end

-- Local DB query to determine whether series images are in this node already
function querydbimages(patientId, studyUid, seriesUid)
    local imaget = {};

    if not isempty(patientId) and patientId ~= '*' then
        if not isempty(studyUid) and studyUid ~= '*' then
            if not isempty(seriesUid) and seriesUid ~= '*' then
                local images = dbquery('dicomimages', 'objectfile,sopinstanc', 'seriesinst = \'' .. seriesUid .. '\'');

                if images ~= nil and #images > 0 then
                    for i = 1, #images do
                        imaget[i] = {};
                        imaget[i].ObjectFile = images[i][1];
                        imaget[i].SOPInstanceUID = images[i][2];
                    end
                end
            end
        end
    end

    return imaget;
end

-- Remote PACS query to determine whether series images exists in remote node/nodes
function queryimages(fromPacs, patientId, studyUid, seriesUid)
    local images, imaget, q;

    if not isempty(fromPacs) then
        if not isempty(patientId) and patientId ~= '*' then
            if not isempty(studyUid) and studyUid ~= '*' then
                if not isempty(seriesUid) and seriesUid ~= '*' then

                    q = newdicomobject();

                    q.PatientID = patientId;
                    q.StudyInstanceUID = studyUid;
                    q.SeriesInstanceUID = seriesUid;
                    q.SOPInstanceUID = '';

                    images = dicomquery(fromPacs, 'IMAGE', q);

                    imaget = {};
                    for i = 0, #images-1 do
                        imaget[i+1] = {};
                        imaget[i+1].SOPInstanceUID = images[i].SOPInstanceUID;
                    end
                end
            end
        end
    end

    return imaget;
end

-- CMove DICOM series from remote PACS node to specified AET
function moveseries(fromPacs, patientId, studyUid, seriesUid, toPacs)
    local m;

    if not isempty(patientId) and patientId ~= '*' then
        if not isempty(studyUid) and studyUid ~= '*' then
            if not isempty(seriesUid) and seriesUid ~= '*' then
                if not isempty(fromPacs) and not isempty(toPacs) then

                    m = newdicomobject();
                    m.PatientID = patientId;
                    m.StudyInstanceUID = studyUid;
                    m.SeriesInstanceUID = seriesUid;
                    m.QueryRetrieveLevel = 'SERIES';

                    -- last parameter '0' is StudyRoot ('1' is PatientRoot)
                    --print([[ { "MoveStatus": [ ]]);
                    dicommove(fromPacs, toPacs, m, 0);
                    --dicommove(s, aet, m, 0, 'print([[ "]] .. Global.StatusString .. [[", ]])');
                    --print([[ "end" ] } ]]);

                    return true;
                end
            end
        end
    end

    return false;
end;

-- RESPONSE

print('Content-type: application/json\n');

local s = getsource();
local nodes = getnodes();

-- Try maximum 5 times to fetch everything from nodes to cache
local seriesIsCached = false;
local timeout = 5;
for k = 1, timeout do
    virtualImages = queryimages(s, patientid, studyuid, seriesuid);
    localImages =  querydbimages(patientid, studyuid, seriesuid);

    -- Number are matching continue with move to final destination
    if #localImages == #virtualImages then
        seriesIsCached = true;
        break;
    else
        -- Numbers are not matching collect study from nodes
        for i = 0, #nodes-1 do
            -- Probe if the node stores any series images
            nodeImages = queryimages(nodes[i+1], patientid, studyuid, seriesuid);
            if (nodeImages ~= nil and #nodeImages > 0) then
                moveseries(nodes[i+1], patientid, studyuid, seriesuid, s)
            end
        end
    end
end

-- Move from this node to final destination AET
if seriesIsCached then
    moveseries(s, patientid, studyuid, seriesuid, aet);
    print([[ { "MovedSeriesCount": ]] .. 1 .. [[ } ]]);
else
    print([[ { "MovedSeriesCount": ]] .. 0 .. [[ } ]]);
end
