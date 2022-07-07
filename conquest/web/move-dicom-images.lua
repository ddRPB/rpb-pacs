-- This script is querying ConQuest PACS in order to retrieve
-- DICOM SOP instance restricted via QueryString parameters
-- and move all patient data to different AE title

-- UseCases:
-- should be deployed on DICOM proxy (clinical/research) or DICOM data (clinical/research) nodes

local patientid = CGI('PatientID')
local studyuid = CGI('StudyUID');
local seriesuid = CGI('SeriesUID');
local sopuid = CGI('SopUID');
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

-- Local DB query to determine whether SOP image is stored in this node already
function querydbimages(patientId, studyUid, seriesUid, sopUid)
    local imaget = {};

    if not isempty(patientId) and patientId ~= '*' then
        if not isempty(studyUid) and studyUid ~= '*' then
            if not isempty(seriesUid) and seriesUid ~= '*' then
                if not isempty(sopUid) and sopUid ~= '*' then
                    local images = dbquery('dicomimages', 'objectfile,sopinstanc', 'sopinstanc = \'' .. sopUid .. '\'');

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
    end

    return imaget;
end

-- Remote PACS query to determine whether SOP image exists in remote node/nodes
function queryimages(fromPacs, patientId, studyUid, seriesUid, sopUid)
    local images, imaget, q;

    if not isempty(fromPacs) then
        if not isempty(patientId) and patientId ~= '*' then
            if not isempty(studyUid) and studyUid ~= '*' then
                if not isempty(seriesUid) and seriesUid ~= '*' then
                    if not isempty(sopUid) and sopUid ~= '*' then

                        q = newdicomobject();

                        q.PatientID = patientId;
                        q.StudyInstanceUID = studyUid;
                        q.SeriesInstanceUID = seriesUid;
                        q.SOPInstanceUID = sopUid;

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
    end

    return imaget;
end

-- CMove DICOM SOP image from remote PACS node to specified AET
function moveimages(fromPacs, patientId, studyUid, seriesUid, sopUid, toPacs)
    local m;

    if not isempty(patientId) and patientId ~= '*' then
        if not isempty(studyUid) and studyUid ~= '*' then
            if not isempty(seriesUid) and seriesUid ~= '*' then
                if not isempty(sopUid) and sopUid ~= '*' then
                    if not isempty(fromPacs) and not isempty(toPacs) then

                        m = newdicomobject();
                        m.PatientID = patientId;
                        m.StudyInstanceUID = studyUid;
                        m.SeriesInstanceUID = seriesUid;
                        m.SOPInstanceUID = sopUid;
                        m.QueryRetrieveLevel = 'IMAGES';

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
    end

    return false;
end;

-- RESPONSE

print('Content-type: application/json\n');

local s = getsource();
local nodes = getnodes();

-- Try maximum 5 times to fetch everything from nodes to cache
local sopIsCached = false;
local timeout = 5;
for k = 1, timeout do
    virtualImages = queryimages(s, patientid, studyuid, seriesuid, sopuid);
    localImages =  querydbimages(patientid, studyuid, seriesuid, sopuid);

    -- Number are matching continue with move to final destination
    if #localImages == #virtualImages then
        sopIsCached = true;
        break;
    else
        -- Numbers are not matching collect study from nodes
        for i = 0, #nodes-1 do
            -- Probe if the node stores any series images
            nodeImages = queryimages(nodes[i+1], patientid, studyuid, seriesuid, sopuid);
            if (nodeImages ~= nil and #nodeImages > 0) then
                moveimages(nodes[i+1], patientid, studyuid, seriesuid, sopuid, s)
            end
        end
    end
end

-- Move from this node to final destination AET
if sopIsCached then
    moveimages(s, patientid, studyuid, seriesuid, sopuid, aet);
    print([[ { "MovedImagesCount": ]] .. 1 .. [[ } ]]);
else
    print([[ { "MovedImagesCount": ]] .. 0 .. [[ } ]]);
end