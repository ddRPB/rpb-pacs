-- This script is querying ConQuest PACS in order to retrieve
-- DICOM Study instance restricted via QueryString parameters
-- and move all patient data to different AE title

-- UseCases:
-- should be deployed on DICOM data (clinical/research) nodes

local patientid = CGI('PatientID');
local studyuid = CGI('StudyUID');
local aet = CGI('AET');

-- Functions declaration

function isempty(s)
    return s == nil or s == '';
end

function movestudy()
    local m, s;

    if source == '(local)' then
        s = servercommand('get_param:MyACRNema');
    else
        s = source;
    end

    if not isempty(patientid) and patientid ~= '*' then
        if not isempty(studyuid) and studyuid ~= '*' then
            if not isempty(aet) then

                m = newdicomobject();
                m.PatientID = patientid;
                m.StudyInstanceUID = studyuid;
                m.QueryRetrieveLevel = 'STUDY';

                -- last parameter '0' is StudyRoot ('1' is PatientRoot)
                dicommove(s, aet, m, 0);

                return true;
            end
        end
    end

    return false;
end;

-- RESPONSE

print('Content-type: application/json\n');

movestudy();
