# lua_redis_restore
A Lua example to backup and restore redis in lua

Require LuaRocks libs:
 - serpent
 - redis

Script
----------- 
###### Permissions:
```bash
chmod +x redis_restore.lua
```

------------
###### Execute:
```lua
./redis_restore.lua backup search_keys_query(optional) name_file_to_write_on_it(optional)
./redis_restore.lua restore name_file_to_write_on_it(optional)
```

Library
----------- 
###### Library example:
```lua
local redire = require 'redis_restore_lib'
local backup_ok = redire.backup("our_bananas", "bananas_file") // our_bananas is the search query
if backup_ok then
 print("Our bananas from Redis are backed up!")
else
 print("Our bananas from Redis aren't backed up :(")
end

local restore_ok = redire.restore("bananas_file")
if restore_ok then
 print("Our bananas from Redis are restored!")
else
 print("Our bananas from Redis aren't restored :(")
end
```
