-- This script is querying ConQuest PACS in order to cmove data to DICOM proxy cache
-- a specific DICOM patient is restricted via QueryString parameters
-- the summary of cached data is reported in JSON format

-- UseCases:
-- should be deployed on DICOM proxy

local patientid = CGI('PatientID');
local studiescount = CGI('StudiesCount');

-- Functions declaration

function isempty(s)
    return s == nil or s == '';
end

-- Local DB query to determine whether patient studies are in cache already
function querydbstudies()
    local studiest;

    if not isempty(patientid) and patientid ~= '*' then
        local studies = dbquery('dicomstudies', 'studyinsta', 'patientid = \'' .. patientid .. '\'');

        if #studies > 0 then
            studiest = {};
            for i = 1, #studies do
                studiest[i] = {};
                studiest[i].StudyInstanceUID = studies[i][1];
            end
        end
    end
    
    return studiest;
end

-- Remote PACS query to determine whether patient studies exists in remote node
function queryallstudies(fromPacs)
    local studies, studiest, q;

    if not isempty(patientid) and patientid ~= '*' then

        q = newdicomobject()

        q.PatientID = patientid;
        q.StudyInstanceUID = '';

        studies = dicomquery(fromPacs, 'STUDY', q);

        studiest = {};
        for i = 0, #studies-1 do
            studiest[i+1] = {};
            studiest[i+1].StudyInstanceUID = studies[i].StudyInstanceUID;
        end
    end
    
    return studiest;
end

-- CMove DICOM patient from remote PACS node to local PACS cache
function movepatient(fromPacs)
    local m;

    if source == '(local)' then
        s = servercommand('get_param:MyACRNema');
    else
        s = source;
    end

    if not isempty(patientid) and patientid ~= '*' then
        m = newdicomobject();
        m.PatientID = patientid;
        m.QueryRetrieveLevel = 'PATIENT';

        -- last parameter '0' is StudyRoot ('1' is PatientRoot)
        dicommove(fromPacs, s, m, 1);

        return true;
    end

    return false;
end

-- RESPONSE
print('Content-type: application/json\n');

-- TODO: ideally this would be readable from config of DICOM proxy
-- Lua has a method get_amap(index) that returns the list
local nodes = {'RPBPacs1', 'RPBPacs2'};

local studies = querydbstudies();
local count = 0;

if studies ~= nil then
    count = #studies;
end

-- There is not so many series in the cache as it should be
if not isempty(studiescount) and #studies < tonumber(studiescount) then
    -- Check the availability of series on remote PACS nodes
    for i = 0, #nodes-1 do
        remote = queryallstudies(nodes[i+1]);

        -- CMove the DICOM study from remote node to local cache
        if remote ~= nil then
            if #remote > 0 then
                if movepatient(nodes[i+1]) then
                    -- Refresh the number of cached images for DICOM series
                    studies = querydbstudies();
                end
            end
        end
    end
end

if studies ~= nil then
    count = #studies;
else
    count = 0;
end

print([[ { "FoundStudiesCount": ]] .. #studies .. [[ } ]]);
