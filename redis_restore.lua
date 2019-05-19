#!/usr/bin/env lua
require 'redis'
local serpent = require 'serpent'
local function get_lua_script_name()
    local info = debug.getinfo(1,'S');
    return info.source:match("@(%S+%.?l?u?a?)")
end
local redis = Redis.connect()
local lua_script_name = get_lua_script_name()
if not arg[1] then
    local msg = lua_script_name..": usage:\n\t"
    msg = msg .. lua_script_name.." backup search_query name_file_to_write\n\t"
    msg = msg .. lua_script_name.." restore name_file_to_write"
    print(msg)
    os.exit(0)
elseif arg[1] == "backup" then
    local search_query = arg[2]
    local file_write = arg[3]
    local file, to_print, value, field, field_text, type_key, data_search, data_array
    local table_data = {}
    if not search_query then
        search_query = ""
    end
    if not file_write then
        file_write = "dump.lua"
    else
        if not file_write:match("$%.lua") then
            file_write = file_write..".lua"
        end
    end
    data_search = redis:keys("*"..search_query.."*")
    if #data_search == 0 then
        io.stderr:write(lua_script_name..": search query doesn't have results.")
        os.exit(1)
    end
    for k,key in pairs(data_search) do
        type_key = redis:type(key)
        value = ""
        field = nil
        field_text = ""
        if type_key == "list" then
            value = redis:lrange(key, 0, -1)
            value_save = value
            value = serpent.block(table_data, {comment=false})
        elseif type_key == "string" then
            value = redis:get(key)
            value_save = value
        elseif type_key == "hash" then
            field = redis:hkeys(key)[1]
            value = redis:hget(key, field)
            value_save = value
            field_text = "\n\tfield "..field
        elseif type_key == "set" then
            value = redis:smembers(key)
            value_save = value
            value = serpent.block(table_data, {comment=false})
        end
        if field then
            table.insert(table_data, {
                key = key,
                value = value_save,
                field = field,
                type = type_key
            })
        else
            table.insert(table_data, {
                key = key,
                value = value_save,
                type = type_key
            })
        end
        to_print = string.format("Backing key %s\n\ttype %s"..field_text.."\n\tvalue %s\n", key, type_key, value)
        print(to_print)
    end
    file = io.open(file_write, 'w+')
    data_array = serpent.block(table_data, {comment=false, name = '_'})
    file:write(data_array)
    file:close()
elseif arg[1] == "restore" then
    local file_restore = arg[3]
    local dump_file, time_in_start
    local data_key, total = 0
    if not file_restore then
        file_restore = "dump"
    else
        file_restore = file_restore:gsub("%.lua$", "")
    end
    dump_file = loadfile(file_restore..".lua")
    if not dump_file then
        io.stderr:write(lua_script_name..": not found file "..file_restore..".lua")
        os.exit(1)
    end
    dump_file = dump_file()
    time_in_start = os.time()
    for index, key in pairs(dump_file) do
        data_key = serpent.block(key, {comment=false})
        if key.type == "list" then
            for k,value in pairs(key.value) do
                redis:lpush(key.key, value)
            end
        elseif key.type == "string" then
            redis:set(key.key, key.value)
        elseif key.type == "hash" then
            redis:hset(key.key, key.field, key.value)
        elseif key.type == "set" then
            for k,value in pairs(key.value) do
                redis:sadd(key.key, value)
            end
        end
        total = index
    end
    local time_elapsed = os.difftime(os.time(), time_in_start)
    print("Restore completed. "..total.." keys restored in "..time_elapsed.." seconds.")
end
