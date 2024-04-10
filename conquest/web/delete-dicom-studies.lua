-- This script is querying ConQuest PACS in order to find and delete
-- DICOM Study data from the PACS

-- UseCases:
-- should be deployed on DICOM proxy and data nodes

local patientid = CGI('PatientID');
local studyuid = CGI('StudyUID');

-- Functions declaration

-- Check for valid not empty string
function isempty(s)
    return s == nil or s == '';
end

-- Local DB query to determine whether studies are in database
function querydbstudies(patientId, studyUid)
    local studiest;

    if not isempty(patientId) and patientId ~= '*' then
        if not isempty(studyUid) and studyUid ~= '*' then
            local studies = dbquery('dicomstudies', 'patientid,studyinsta', ' patientid = \'' .. patientId .. '\'' .. 'and studyinsta = \'' .. studyUid .. '\'');

            if studies ~= nil and #studies > 0 then
                studiest = {};
                for i = 1, #studies do
                    studiest[i] = {};
                    studiest[i].PatientID = studies[i][1]
                    studiest[i].StudyInstanceUID = studies[i][2];
                end
            end
        end
    end

    return studiest;
end

function deleteStudy(id, uid)
    servercommand('deletestudy:'..id..':'..uid..'');
    return true;
end

-- RESPONSE

print('Content-type: application/json\n');

local studies = querydbstudies(patientid, studyuid);

local count = 0;
local deleted = 0;

if studies ~= nil then
    count = #studies;
    for i = 1, #studies do
        if deleteStudy(studies[i].PatientID, studies[i].StudyInstanceUID) then
            deleted = deleted + 1;
        end
    end
end

print([[ { "FoundStudiesCount": ]] .. count .. [[, "DeletedStudiesCount": ]] .. deleted .. [[ } ]]);
