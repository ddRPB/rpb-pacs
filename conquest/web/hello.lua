-- This script is querying ConQuest PACS in order to dummy test PACS API

-- Helper functions declaration

function isempty(s)
    return s == nil or s == '';
end

-- RESPONSE

print('Content-type: text/plain\n');

if source == '(local)' then
    s = servercommand('get_param:MyACRNema');
else
    s = source;
end

if not isempty(s) then
    response = servercommand('echo:'..s);
end

if not isempty(s) then
    template = s..' is UP';
    if response == template then
        print(s .. [[ says: pong]]);
    else
        print(s .. [[ says: error]]);
    end
else
    print('PACS says: error');
end
