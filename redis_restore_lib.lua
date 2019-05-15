require 'redis'
local serpent = require 'serpent'
local redis = Redis.connect()
local redis_tools = {}
function redis_tools.backup(search_query, file_write)
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
        return false, "search query doesn't have results."
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
    end
    file = io.open(file_write, 'w+')
    data_array = serpent.block(table_data, {comment=false, name = '_'})
    file:write(data_array)
    file:close()
    return true, "ok"
end
function redis_tools.restore(file_restore)
    local dump_file, time_in_start
    local data_key, total = 0
    if not file_restore then
        file_restore = "dump"
    else
        file_restore = file_restore:gsub("%.lua$", "")
    end
    dump_file = io.open(file_restore..".lua", "r")
    if not dump_file then
         return "file "..file_restore..".lua not found."
    end
    dump_file:close()
    dump_file = require(file_restore)
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
    return true, "Restore completed. "..total.." keys restored in "..time_elapsed.." seconds."
end
return redis_tools
