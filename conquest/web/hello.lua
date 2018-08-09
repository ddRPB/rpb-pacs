-- This script is querying ConQuest PACS in order to find out whether
-- the PACS API is reachable

-- Functions declaration

-- RESPONSE

HTML('Content-type: text/plain\n\n');

msg = [[ RPB PACS says: pong ]]

HTML(msg)
