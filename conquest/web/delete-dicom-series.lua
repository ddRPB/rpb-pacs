-- This script is querying ConQuest PACS in order to find and delete
-- DICOM Series data from the PACS

-- UseCases:
-- should be deployed on DICOM proxy and data nodes

local patientid = CGI('PatientID');
local studyuid = CGI('StudyUID');
local seriesuid = CGI('SeriesUID');

-- Functions declaration

-- Check for valid not empty string
function isempty(s)
    return s == nil or s == '';
end

-- Local DB query to determine whether series are in database
function querydbseries(patientId, studyUid, seriesUid)
    local seriest = {};

    if not isempty(patientId) and patientId ~= '*' then
        if not isempty(studyUid) and studyUid ~= '*' then
            if not isempty(seriesUid) and seriesUid ~= '*' then
                local series = dbquery('dicomseries', 'patientid,studyinsta,seriesinst', 'patientid = \'' .. patientId .. '\'' .. 'and studyinsta = \'' .. studyUid .. '\'' .. 'and seriesinst = \'' .. seriesUid .. '\'');

                if series ~= nil and #series > 0 then
                    for i = 1, #series do
                        seriest[i] = {};
                        seriest[i].PatientID = series[i][1];
                        seriest[i].StudyInstaceUID = series[i][2];
                        seriest[i].SeriesInstanceUID = series[i][3];
                    end
                end
            end
        end
    end

    return seriest;
end

function deleteSeries(id, uid)
    servercommand('deleteseries:'..id..':'..uid..'');
    return true;
end

-- RESPONSE

print('Content-type: application/json\n');

local series = querydbseries(patientid, studyuid, seriesuid);

local count = 0;
local deleted = 0;

if series ~= nil then
    count = #series;
    for i = 1, #series do
        if deleteSeries(series[i].PatientID, series[i].SeriesInstanceUID) then
            deleted = deleted + 1;
        end
    end
end

print([[ { "FoundSeriesCount": ]] .. count .. [[, "DeletedSeriesCount": ]] .. deleted .. [[ } ]]);
