-- This script is querying ConQuest PACS in order to retrieve
-- DICOM Patient instance restricted via QueryString parameters
-- and move all patient data to different AE title

-- UseCases:
-- should be deployed on DICOM proxy (clinical/research) or DICOM data (clinical/research) nodes

local patientid = CGI('PatientID');
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

-- Local DB query to determine whether patient studies are in this node already
function querydbstudies(patientId)
    local studiest = {};

    if not isempty(patientId) and patientId ~= '*' then
        local studies = dbquery('dicomstudies', 'studyinsta', 'patientid = \'' .. patientId .. '\'');

        if studies ~= nil and #studies > 0 then
            for i = 1, #studies do
                studiest[i] = {};
                studiest[i].StudyInstanceUID = studies[i][1];
            end
        end
    end

    return studiest;
end

-- Local DB query to determine whether study series are in this node already
function querydbseries(patientId, studyUid)
    local seriest = {};

    if not isempty(patientId) and patientId ~= '*' then
        if not isempty(studyUid) and studyUid ~= '*' then
            local series = dbquery('dicomseries', 'seriesinst', 'studyinsta = \'' .. studyUid .. '\'');

            if series ~= nil and #series > 0 then
                for i = 1, #series do
                    seriest[i] = {};
                    seriest[i].SeriesInstanceUID = series[i][1];
                end
            end
        end
    end

    return seriest;
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

-- Local DB query to determine whether study series images are in this node already
function querydbpatientimages(patientId, localStudies)
    local localSopCount = 0;
    if localStudies ~= nil then
        for i = 1, #localStudies do
            localSeries = querydbseries(patientId, localStudies[i].StudyInstanceUID);
            if localSeries ~= nil then
                for j = 1, #localSeries do
                    localImages = querydbimages(patientId,  localStudies[i].StudyInstanceUID, localSeries[j].SeriesInstanceUID);
                    localSopCount = localSopCount + #localImages;
                end
            end
        end
    end

    return localSopCount;
end

-- Remote PACS query to determine whether patient studies exists in remote node/nodes
function querystudies(fromPacs, patientId)
    local studies, studiest, q;

    if not isempty(fromPacs) then
        if not isempty(patientId) and patientId ~= '*' then

            q = newdicomobject();

            q.PatientID = patientId;
            q.StudyInstanceUID = '';

            studies = dicomquery(fromPacs, 'STUDY', q);

            studiest = {};
            if #studies > 0 then
                for i = 0, #studies-1 do
                    studiest[i+1] = {};
                    studiest[i+1].PatientID = studies[i].PatientID;
                    studiest[i+1].StudyInstanceUID = studies[i].StudyInstanceUID;
                end
            end
        end
    end

    return studiest;
end

-- Remote PACS query to determine whether study series exists in remote node/nodes
function queryseries(fromPacs, patientId, studyUid)
    local series, seriest, q;

    if not isempty(fromPacs) then
        if not isempty(patientId) and patientId ~= '*' then
            if not isempty(studyUid) and studyUid ~= '*' then

                q = newdicomobject();

                q.PatientID = patientId;
                q.StudyInstanceUID = studyUid;
                q.SeriesInstanceUID = '';

                series = dicomquery(fromPacs, 'SERIES', q);

                seriest = {};
                for i = 0, #series-1 do
                    seriest[i+1] = {};
                    seriest[i+1].SeriesInstanceUID = series[i].SeriesInstanceUID;
                end
            end
        end
    end

    return seriest;
end

-- Remote PACS query to determine whether series images exists in remote node/nodes
function queryimages(fromPacs, patientId, studyUid, seriesUid)
    local images, imaget, q;

    if not isempty(fromPacs) then
        if not isempty(patientId) and patientId ~= '*' then
            if studyUid ~= '*' then
                if seriesUid ~= '*' then

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

-- CMove DICOM patient from remote PACS node to specified AET
function movepatient(fromPacs, patientId, toPacs)
    local m;

    -- Check if the query parameters are setup
    if not isempty(patientId) and patientId ~= '*' then
        if not isempty(fromPacs) and not isempty(toPacs) then

            m = newdicomobject();
            m.PatientID = patientId;
            m.QueryRetrieveLevel = 'PATIENT'

            -- Move to aet
            -- last parameter '1' is PatientRoot ('0' is StudyRoot)
            --print([[ { "MoveStatus": [ ]]);
            dicommove(fromPacs, toPacs, m, 1);
            --dicommove(s, aet, m, 1, 'print([[ "]] .. Global.StatusString .. [[", ]])');
            --print([[ "end" ] } ]]);

            return true;
        end
    end

    return false;
end

-- RESPONSE

print('Content-type: application/json\n');

local s = getsource();
local nodes = getnodes();

-- Try maximum 5 times to fetch everything from nodes to cache
local patientIsCached = false;
local timeout = 5;
for k = 1, timeout do
    virtualStudies = querystudies(s, patientid);
    -- Wildcard * is not allowed in InstanceUIDs but empty string is
    virtualImages = queryimages(s, patientid, '', '');

    localStudies = querydbstudies(patientid);
    localSopCount = querydbpatientimages(patientid, localStudies);

    -- Number are matching continue with move to final destination
    if #localStudies == #virtualStudies and localSopCount == #virtualImages then
        patientIsCached = true;
        break;
    else
        -- Numbers are not matching collect patient from nodes
        for i = 0, #nodes-1 do
            -- Probe if the node stores any patient studies
            nodeStudies = querystudies(nodes[i+1], patientid);
            if (nodeStudies ~= nil and #nodeStudies > 0) then
                movepatient(nodes[i+1], patientid, s)
            end
        end
    end
end

-- Move from this node to final destination AET
if patientIsCached then
    movepatient(s, patientid, aet);
    print([[ { "MovedPatientsCount": ]] .. 1 .. [[ } ]]);
else
    print([[ { "MovedPatientsCount": ]] .. 0 .. [[ } ]]);
end
