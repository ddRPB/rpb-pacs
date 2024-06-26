-- This script is querying ConQuest PACS in order to find and delete
-- DICOM Image data from the PACS

-- UseCases:
-- should be deployed on DICOM proxy and data nodes

local patientid = CGI('PatientID');
local sopuid = CGI('SopUID');

-- Functions declaration

-- Check for valid not empty string
function isempty(s)
    return s == nil or s == '';
end

-- Local DB query to determine whether images are in database
function querydbimages(patientId, sopUid)
    local imaget = {};

    if not isempty(patientId) and patientId ~= '*' then
        if not isempty(sopUid) and sopUid ~= '*' then
            local images = dbquery('dicomimages', 'imagepat,sopinstanc', 'imagepat = \'' .. patientId .. '\'' .. 'and sopinstanc = \'' .. sopUid .. '\'');

            if images ~= nil and #images > 0 then
                for i = 1, #images do
                    imaget[i] = {};
                    imaget[i].PatientID = images[i][1];
                    imaget[i].SOPInstanceUID = images[i][2];
                end
            end
        end
    end

    return imaget;
end

function deleteImage(id, uid)
    servercommand('deleteimage:'..id..':'..uid..'');
    return true;
end

print('Content-type: application/json\n');

local images = querydbimages(patientid, sopuid);

local count = 0;
local deleted = 0;

if images ~= nil then
    count = #images;
    for i = 1, #images do
        if deleteImage(images[i].PatientID, images[i].SOPInstanceUID) then
            deleted = deleted + 1;
        end
    end
end

print([[ { "FoundImagesCount": ]] .. count .. [[, "DeletedImagesCount": ]] .. deleted .. [[ } ]]);
