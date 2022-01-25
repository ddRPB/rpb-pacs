-- This script is querying ConQuest PACS in order to find and delete
-- DICOM Patient data from the PACS

-- UseCases:
-- should be deployed on DICOM data (clinical/research) nodes

local patientid = CGI('PatientID');

-- Functions declaration

-- Check for valid not empty string
function isempty(s)
    return s == nil or s == '';
end

-- Local DB query to determine whether patients are in database
function querydbpatients(patientId)
    local patientst = {};

    if not isempty(patientId) and patientId ~= '*' then
        local patients = dbquery('dicompatients', 'patientid', 'patientid = \'' .. patientId .. '\'');

        if patients ~= nil and #patients > 0 then
            for i = 1, #patients do
                patientst[i] = {};
                patientst[i].PatientID = patients[i][1];
            end
        end
    end

    return patientst;
end

function deletePatient(patients)
    for i = 1, #patients do
        servercommand('deletepatient:'..patients[i].PatientID..'');
        return true;
    end

    return false;
end

-- RESPONSE

print('Content-type: application/json\n');

local patients = querydbpatients(patientid);

local count = 0;
local deleted = 0;

if patients ~= nil then
    count = #patients;
    if deletePatient(patients) then
        deleted = deleted + 1;
    end
end

print([[ { "FoundPatientsCount": ]] .. count .. [[, "DeletedPatientsCount": ]] .. deleted .. [[ } ]]);
