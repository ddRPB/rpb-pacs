-- This script is querying ConQuest PACS in order to dummy test PACS API

-- RESPONSE

print('Content-type: text/plain\n');

if source == '(local)' then
    s = servercommand('get_param:MyACRNema');
else
    s = source;
end

print(s .. [[ says: pong]]);
