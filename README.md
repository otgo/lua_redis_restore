# lua_redis_restore
A Lua example to backup and restore redis in lua

Require LuaRocks libs:
 - serpent
 - redis

----------- 
permissions:

```bash
chmod +x redis_restore.lua
```

------------
execute:

```lua
./redis_restore.lua backup search_keys_query(optional) name_file_to_write_on_it(optional)
./redis_restore.lua restore name_file_to_write_on_it(optional)
```
