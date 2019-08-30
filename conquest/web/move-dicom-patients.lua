-- This script is querying ConQuest PACS in order to retrieve
-- DICOM Patient instance restricted via QueryString parameters
-- and move all patient data to different AE title

-- UseCases:
-- should be deployed on DICOM data (clinical/research) nodes

local patientid = CGI('PatientID');
local aet = CGI('AET');

-- TODO: need to work on

-- Functions declaration

function isempty(s)
    return s == nil or s == '';
end

function movepatient()
    local m, s;

    if source == '(local)' then
        s = servercommand('get_param:MyACRNema');
    else
        s = source;
    end

    -- Check if the query parameters are setup
    if not isempty(patientid) and patientid ~= '*' then
        if not isempty(aet) then
            m = newdicomobject();
            m.PatientID = patientid;
            m.QueryRetrieveLevel = 'PATIENT'

            -- Move to aet
            -- last parameter '1' is PatientRoot ('0' is StudyRoot)
            dicommove(s, aet, m, 1);

            return true;
        end
    end

    return false;
end

-- RESPONSE

print('Content-type: application/json\n');

movepatient();