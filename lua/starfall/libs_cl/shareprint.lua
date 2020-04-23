local hasAccess = SF.Permissions.hasAccess
local checkluatype = SF.CheckLuaType
local dgetmeta = debug.getmetatable

local printBlue = Color( 151, 211, 255 )

-- Combo of MsgC and MsgN, message color with newline
local function MsgCN( ... )
    local data = { ... }
    table.insert( data, "\n" )
    MsgC( unpack( data ) )
end

-- Work out which function to use based on instance permissions. If can't do either, return nil
local function getPrintFunc( instance )
    if hasAccess( instance, nil, "print.chat" ) then
        return chat.AddText
    elseif hasAccess( instance, nil, "print.console" ) then
        return MsgCN
    end
end

-- Remove colors from data, prepend normal print blue
local function noColors( data )
    local out = {}
    for k, v in ipairs( data ) do
        if not IsColor( v ) then
            table.insert( out, v )
        end
    end
    table.insert( out, 1, printBlue )
    return out
end

SF.Permissions.registerPrivilege( "print.chat", "Print chat", "Allows the starfall to print to your chat (and by extension, your console)", { client = { default = 1 } } )
SF.Permissions.registerPrivilege( "print.console", "Print console", "Allows the starfall to print to your console", { client = { default = 1 } } )
SF.Permissions.registerPrivilege( "print.screen", "Print in color", "Allows the starfall to print to the center of your screen", { client = { default = 1 } } )
SF.Permissions.registerPrivilege( "print.color", "Print in color", "Allows the starfall to print in color where it is allowed", { client = { default = 1 } } )

return function( instance )

    local builtins_library = instance.env
    local col_meta = instance.Types.Color

    -- Following 2 functions taken ( + modified/cleaned ) from starfallEx github, https://github.com/thegrb93/StarfallEx/blob/master/lua/starfall/libs_sh/builtins.lua#L853
    -- They made them local, so this was my only option
    local function printTableX( t, indent, alreadyprinted, printFunc )
        if next( t ) then
            for k, v in builtins_library.pairs( t ) do
                if SF.GetType( v ) == "table" and not alreadyprinted[v] then
                    alreadyprinted[v] = true
                    local s = string.rep( "\t", indent ) .. tostring( k ) .. ":"
                    printFunc( printBlue, s )
                    printTableX( v, indent + 1, alreadyprinted )
                else
                    local s = string.rep( "\t", indent ) .. tostring( k ) .. "\t=\t" .. tostring( v )
                    printFunc( printBlue, s )
                end
            end
        else
            local s = string.rep( "\t", indent ) .. "{}"
            printFunc( printBlue, s )
        end
    end

    local function argsToChat( ... )
        local n = select( "#", ... )
        local input = { ... }
        local output = {}
        local color = false
        for i = 1, n do
            local val = input[i]
            local add
            if dgetmeta( val ) == col_meta then
                color = true
                add = Color( val[1], val[2], val[3] )
            else
                add = tostring( val )
            end
            output[i] = add
        end
        -- Combine the strings with tabs
        local processed = {}
        if not color then processed[1] = printBlue end
        local i = 1
        while i <= n do
            if isstring( output[i] ) then
                local j = i + 1
                while j <= n and isstring( output[j] ) do
                    j = j + 1
                end
                if i == ( j - 1 ) then
                    processed[#processed + 1] = output[i]
                else
                    processed[#processed + 1] = table.concat( { unpack( output, i, j ) }, "\t" )
                end
                i = j
            else
                processed[#processed + 1] = output[i]
                i = i + 1
            end
        end
        return processed
    end

    -- player:PrintMessage types to permission map
    local printMessagePermMap = {
        [HUD_PRINTNOTIFY] = "print.console",
        [HUD_PRINTCONSOLE] = "print.console",
        [HUD_PRINTTALK] = "print.chat",
        [HUD_PRINTCENTER] = "print.screen",
    }

    -- Delay until after builtins are loaded, so we can overwrite them
    instance:AddHook( "initialize", function()
        -- Note, these functions do not use SF.Permissions.check, as that would cause them to error on missing permission.
        -- We silently return if you can't print, a print shouldn't throw an error.

        --- Prints a message to your chat, console, or the center of your screen.
        -- @param mtype How the message should be displayed. See http://wiki.garrysmod.com/page/Enums/HUD
        -- @param text The message text.
        function builtins_library.printMessage( mtype, text )
            checkluatype( text, TYPE_STRING )

            -- Find out what permission we need
            local perm = printMessagePermMap[mtype]
            if not perm then return end
            -- Ensure we have it
            if not hasAccess( instance, nil, perm ) then return end

            instance.player:PrintMessage( mtype, text )
        end

        function builtins_library.print( ... )
            -- Work out what function to use to print
            local printFunc = getPrintFunc( instance )
            if not printFunc then return end

            -- Remove colour if it's not enabled
            local data = argsToChat( ... )
            if not hasAccess( instance, nil, "print.color" ) then
                data = noColors( data )
            end
            printFunc( unpack( data ) )
        end

        function builtins_library.printTable( tbl )
            local printFunc = getPrintFunc( instance )
            if not printFunc then return end
            checkluatype( tbl, TYPE_TABLE )

            printTableX( tbl, 0, { [tbl] = true }, printFunc )
        end
    end )
end
