-- This script is querying ConQuest PACS in order to cmove data to DICOM proxy cache
-- a specific DICOM study is restricted via QueryString parameters
-- the summary of cached data is reported in JSON format

-- UseCases:
-- should be deployed on DICOM proxy

local patientid = CGI('PatientID');
local studyuid = CGI('StudyUID');
local seriescount = CGI('SeriesCount');

-- Functions declaration

function isempty(s)
    return s == nil or s == '';
end

-- Local DB query to determine whether study series are in cache already
function querydbseries()
    local seriest;
    
    if not isempty(patientid) and patientid ~= '*' then
        if not isempty(studyuid) and studyuid ~= '*' then
            local series = dbquery('dicomseries', 'seriesinst', 'studyinsta = \'' .. studyuid .. '\'');

            if #series > 0 then
                seriest = {};
                for i = 1, #series do
                    seriest[i] = {};
                    seriest[i].SeriesInstanceUID = series[i][1];
                end
            end
        end
    end
    
    return seriest;
end

-- Remote PACS query to determine whether study series exists in remote node
function queryallseries(fromPacs)
    local series, seriest, q;

    if not isempty(patientid) and patientid ~= '*' then
        if not isempty(studyuid) and studyuid ~= '*' then

            q = newdicomobject();

            q.PatientID = patientid;
            q.StudyInstanceUID = studyuid;

            series = dicomquery(fromPacs, 'SERIES', q);

            seriest = {};
            for i = 0, #series-1 do
                seriest[i+1] = {};
                seriest[i+1].SeriesInstanceUID = series[i].SeriesInstanceUID;
            end
        end
    end

    return seriest;
end

-- CMove DICOM study from remote PACS node to local PACS cache
function movestudy(fromPacs)
    local m;

    if source == '(local)' then
        s = servercommand('get_param:MyACRNema');
    else
        s = source;
    end

    if not isempty(patientid) and patientid ~= '*' then
        if not isempty(studyuid) and studyuid ~= '*' then
            m = newdicomobject();
            m.PatientID = patientid;
            m.StudyInstanceUID = studyuid;
            m.QueryRetrieveLevel = 'STUDY';

            -- last parameter '0' is StudyRoot ('1' is PatientRoot)
            dicommove(fromPacs, s, m, 0);
            return true;
        end
    end

    return false;
end

-- RESPONSE
print('Content-type: application/json\n');

-- TODO: ideally this would be readable from config of DICOM proxy
local nodes = {'RPBPacs1', 'RPBPacs2'};

local series = querydbseries();
local count = 0;

if series ~= nil then
    count = #series;
end

-- There is not so many series in the cache as it should be
if not isempty(seriescount) and count < tonumber(seriescount) then
    -- Check the availability of series on remote PACS nodes
    for i = 0, #nodes-1 do
        remote = queryallseries(nodes[i+1]);
        
        -- CMove the DICOM study from remote node to local cache
        if remote ~= nil then
            if #remote > 0 then
                if movestudy(nodes[i+1]) then
                    -- Refresh the number of cached images for DICOM series
                    series = querydbseries();
                end
            end
        end
    end
end

if series ~= nil then
    count = #series;
else
    count = 0;
end

print([[ { "FoundSeriesCount": ]] .. count .. [[ } ]]);
