-- This script is querying ConQuest PACS in order to cmove data to DICOM proxy cache
-- a specific DICOM series is restricted via QueryString parameters
-- the summary of cached data is reported in JSON format

-- UseCases:
-- should be deployed on DICOM proxy

local patientid = CGI('PatientID');
local studyuid = CGI('StudyUID');
local seriesuid = CGI('SeriesUID');
local filescount = CGI('FilesCount');

-- Functions declaration

function isempty(s)
    return s == nil or s == '';
end

-- Local DB query to determine whether series images are in cache already
function querydbimages()
    local imaget;

    if not isempty(patientid) and patientid ~= '*' then
        if not isempty(studyuid) and studyuid ~= '*' then
            if not isempty(seriesuid) and seriesuid ~= '*' then
                local images = dbquery('dicomimages', 'objectfile,sopinstanc', 'seriesinst = \'' .. seriesuid .. '\'');

                if #images > 0 then
                    imaget = {};
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

-- Remote PACS query to determine whether series images exists in remote node
function queryallimages(fromPacs)
    local images, imaget, q;

    if not isempty(patientid) and patientid ~= '*' then
        if not isempty(studyuid) and studyuid ~= '*' then
            if not isempty(seriesuid) and seriesuid ~= '*' then

                q = newdicomobject();

                q.PatientID = patientid;
                q.StudyInstanceUID = studyuid;
                q.SeriesInstanceUID = seriesuid;

                images = dicomquery(fromPacs, 'IMAGE', q);

                imaget = {};
                for i = 0, #images-1 do
                    imaget[i+1] = {};
                    imaget[i+1].SOPInstanceUID = images[i].SOPInstanceUID;
                end
            end
        end
    end

    return imaget;
end

-- CMove DICOM series from remote PACS node to local PACS cache
function moveseries(fromPacs)
    local m;

    if source == '(local)' then
        s = servercommand('get_param:MyACRNema');
    else
        s = source;
    end

    if not isempty(patientid) and patientid ~= '*' then
        if not isempty(studyuid) and studyuid ~= '*' then
            if not isempty(seriesuid) and seriesuid ~= '*' then
                m = newdicomobject();
                m.PatientID = patientid;
                m.StudyInstanceUID = studyuid;
                m.SeriesInstanceUID = seriesuid;
                m.QueryRetrieveLevel = 'SERIES';

                -- last parameter '0' is StudyRoot ('1' is PatientRoot)
                dicommove(fromPacs, s, m, 0);
                return true;
            end
        end
    end

    return false;
end

-- RESPONSE
print('Content-type: application/json\n');

-- TODO: ideally this would be readable from config of DICOM proxy
local nodes = {'RPBPacs1', 'RPBPacs2'};

local images = querydbimages();
local count = 0;

if images ~= nil then
    count = #images;
end

-- There is not so many images in the cache as it should be
if not isempty(filescount) and count < tonumber(filescount) then

    -- Check the availability of images on remote PACS nodes
    for i = 0, #nodes-1 do
        remote = queryallimages(nodes[i+1]);

        -- CMove the DICOM series from remote node to local cache
        if remote ~= nil then
            if #remote > 0 then
                if moveseries(nodes[i+1]) then
                    -- Refresh the number of cached images for DICOM series
                    images = querydbimages();
                end
            end
        end
    end
end

if images ~= nil then
    count = #images;
else
    count = 0;
end

print([[ { "FoundFilesCount": ]] .. count .. [[ } ]]);
