-- This script is querying ConQuest PACS in order to retrieve
-- DICOM patient/study data restricted via QueryString parameters
-- the data is reported in JSON format

-- UseCases:
-- query all (*) patients with all studies
-- query one patient with all studies
-- query one patient with one study

local patientid = CGI('PatientID');
local studyuid = CGI('StudyUID');

-- Functions declaration

function isempty(s)
    return s == nil or s == '';
end

local hex_to_char = function(x)
    return string.char(tonumber(x, 16))
end

local parameterdecode = function(parameter)
    if parameter == nil then
        return
    end
    parameter = parameter:gsub("+", " ")
    parameter = parameter:gsub("%%(%x%x)", hex_to_char)
    return parameter
end

function queryallstudies()
    local studies, studiest, q, s;

    if source == '(local)' then
        s = servercommand('get_param:MyACRNema');
    else
        s = source;
    end

    if not isempty(patientid) then

        -- convert returned DDO (userdata) to table; needed to allow table.sort
        studiest = {};
        i = 0;
        for pid in string.gmatch(parameterdecode(patientid), '([^,]+)') do
            q = newdicomobject();
            q.PatientID = pid;
            q.Sex = '';
            q.PatientBirthDate = '';

            if not isempty(studyuid) then
                q.StudyInstanceUID = studyuid;
            else
                q.StudyInstanceUID = '';
            end

            q.StudyDescription = '';
            q.StudyDate = '';
            q.StudyTime = '';

            studies = dicomquery(s, 'STUDY', q);
            for j = 0, #studies-1 do
                studiest[i+j+1] = {};
                studiest[i+j+1].PatientID        = studies[j].PatientID;
                studiest[i+j+1].Sex              = studies[j].Sex;
                studiest[i+j+1].PatientBirthDate = studies[j].PatientBirthDate;
                studiest[i+j+1].StudyInstanceUID = studies[j].StudyInstanceUID;
                studiest[i+j+1].StudyDescription = studies[j].StudyDescription;
                studiest[i+j+1].StudyDate        = studies[j].StudyDate;
                studiest[i+j+1].StudyTime        = studies[j].StudyTime;
            end

            i = i + 1;
        end
    end

    return studiest;
end

-- RESPONSE

print('Content-type: application/json\n');

local studies = queryallstudies();

print([[{ "Patients": [ ]]); -- start of json obj, start of patients collection

if studies ~= nil then

    table.sort(studies, function(a, b) return a.PatientID < b.PatientID end);

    for i = 1, #studies do

        if isempty(studies[i].Sex) then
            studies[i].Sex = 'O';
        end

        if isempty(studies[i].PatientBirthDate) then
            studies[i].PatientBirthDate = '19000101';
        end

        if isempty(studies[i].StudyDate) then
            studies[i].StudyDate = 'Unknown';
        end

        -- Determine whether it is first patient or next patient in a list (split necessary)
        local split = (i == 1) or (studies[i-1].PatientID ~= studies[i].PatientID);

        -- If it is a next patient
        if split and i~=1 then
            print([[ ] } , ]]); -- end of study collection if next exist, end of patient object if next exist, next patient can be created
        end

        -- If  it is first patient or next patient in a list
        if split then

            -- DICOM Patient json object
            print([[ { "PatientID": "]] .. studies[i].PatientID .. [[", ]]); -- begin of study object
            print([[ "Sex": "]] .. studies[i].Sex .. [[", ]]);
            print([[ "PatientBirthDate": "]] .. studies[i].PatientBirthDate .. [[", ]]);

            print ([[ "Studies" : [ ]]); -- begin of studies collection
        end

        -- DICOM study json collection
        print([[ { "StudyInstanceUID" : "]] ..studies[i].StudyInstanceUID .. [[", ]]); -- begin of study object

        if not isempty(studies[i].StudyDescription) then
            -- Percentage sign is a special character in lua, that is why I need to mask it
            maskedDescription = string.gsub(studies[i].StudyDescription, "%%", "%%%%");
            print([[ "StudyDescription": "]] .. maskedDescription .. [[", ]]);
        end

        if not isempty(studies[i].StudyDate) then
            print([[ "StudyDate": "]] .. studies[i].StudyDate .. [[", ]]);
        end

        if not isempty(studies[i].StudyTime) then
            print([[ "StudyTime": "]] .. studies[i].StudyTime .. [["]]);
        end

        print([[ } ]]) -- end of study object

        if i ~= #studies then
            if studies[i+1].PatientID == studies[i].PatientID then
                print([[, ]]); -- there will be nex study object
            end
        end
    end

    if #studies > 0 then
        print([[ ] } ]]); -- end of studies collection and end of patient object
    end
end

print([[ ] } ]]); -- end of patients collection and end of json obj
