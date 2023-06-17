--- === XcodeVimTricks ===
---
--- Tricks for Vim Mode in Xcode
---

local obj = {}
obj.__index = obj

-- Metadata
obj.name = "XcodeVimTricks"
obj.version = "0.0.2"
obj.author = "Ezhik <i@ezhik.me>"

function p(v) print(hs.inspect.inspect(v)) end

-- i hate this
-- the bar is semi-transparent too, making everything worse.
local modeColors = {
    normal = {
        { -- light mode
            blue = 0.91372549019608,
            green = 0.90980392156863,
            red = 0.90980392156863
        },
        { -- dark mode
            blue = 0.25490196078431,
            green = 0.23137254901961,
            red = 0.21960784313725
        },
    },
    visual = {
        { -- light mode
            blue = 0.92941176470588,
            green = 0.90196078431373,
            red = 0.80392156862745
        },
        { -- dark mode
            blue = 0.37647058823529,
            green = 0.32941176470588,
            red = 0.21176470588235
        },
    },
    insert = {
        { -- light mode
            blue = 0.96078431372549,
            green = 0.79607843137255,
            red = 0.90588235294118
        },
        { -- dark mode
            blue = 0.40392156862745,
            green = 0.20392156862745,
            red = 0.30980392156863
        },
    }
}
-- nasty approximate color comparison
function approxEq(a, b)
    return math.abs((a - b) * 1000) < 50
end
function colorApproxEqual(c1, c2)
    return approxEq(c1.red, c2.red) and approxEq(c1.green, c2.green) and approxEq(c1.blue, c2.blue)
end

-- this button is used as the hint to locate the Vim mode in the debug bar (which is not visible in AX ;_;)
-- there can be multiple buttons so i'm using this instead of the bar itself
local breakpointsButton = nil
function locateBreakpointsButton()
    local ax = hs.axuielement.windowElement(hs.window.focusedWindow())
    ax:elementSearch(function(msg, results)
            breakpointsButton = results[1]
        end,
        function(el)
            -- this most likely does not work if Xcode is not in English
            return (el.AXDescription == "Breakpoints" or el.AXIdentifier == "Execution") and el.AXParent.AXDescription == "debug bar"
        end,
        { count = 1 }
    )
end

local vimModeCache = nil
function getVimMode()
    if vimModeCache ~= nil then
        -- p(vimModeCache)
        return vimModeCache
    end
    local window = hs.window.focusedWindow()

    -- no breakpoint button yet, disable tricks until it exists but also don't set cache
    if breakpointsButton == nil then
        return "insert"
    end
    local bf = breakpointsButton.AXFrame

    local xf = window:frame()
    -- p(bf)
    -- p(xf)
    -- p(f)

    -- yes this seriously determines the current mode by taking a screenshot and comparing a pixel
    local snapshot = window:snapshot()
    local scale = snapshot:size().w / xf.w -- need to account for retina

    local f = {
        x = (bf.x - xf.x + bf.w + 12) * scale,
        y = (bf.y - xf.y + bf.h // 2) * scale,
    }
    cc = snapshot:colorAt(f)
    -- p(cc)

    for mode, colors in pairs(modeColors) do
        for _, mc in pairs(colors) do
            if colorApproxEqual(mc, cc) then
                vimModeCache = mode
                -- p(mode)
                return mode
            end
        end
    end

    -- we shouldn't ever be here but if we are we were unable to figure out the mode so just pretend we're in insert mode to disable all tricks
    return "insert"
end

local keys = {}
local keyCount = 0

local lastVisualRange = nil

local systemElement = hs.axuielement.systemWideElement()

local escKey = hs.keycodes.map.escape

local wf = hs.window.filter.new():setAppFilter("Xcode", { focused = true })
local et = hs.eventtap.new({hs.eventtap.event.types.keyDown, hs.eventtap.event.types.mouseMoved, hs.eventtap.event.types.gesture, hs.eventtap.event.types.scrollWheel}, function(ev)
    local currentElement = systemElement.AXFocusedUIElement
    -- p(currentElement:allAttributeValues())

    -- only activate if in the actual vim-mode source code editor
    -- this most likely does not work if Xcode is not in English
    if currentElement ~= nil and currentElement.AXDescription == "Source Editor" then
        -- p(getVimMode())
        -- p(currentElement:allAttributeValues())
        keyCount = keyCount + 1

        local mask = false -- set this to true to mask a keypress
        c = ev:getCharacters()
        keycode = ev:getKeyCode()

        -- here the actual remapping is handled. all keymaps are recursive,
        -- so sending a keystroke from here will end up getting handled here again.
        -- to prevent getting stuck in a loop, the keys table stores the last two keypresses
        -- so they can be checked against to actually send keystrokes to Xcode
        -- that's enough for all my mappings

        -- not a keypress, clear out the mode cache just in case
        -- for example selecting in normal mode triggers visual mode
        if c == nil then
            vimModeCache = nil
            return false
        -- using f/F to search or r to replace one character clears out the cache and skips tricks
        elseif (keys[1] == "f" or keys[1] == "F" or keys[1] == "r") and getVimMode() ~= "insert" then
            keys = {}
            return false

        -- tricks below this point

        -- y -> "*y except if given a register
        elseif c == "y" and keys[1] ~= "y" and keys[2] ~= '"' and getVimMode() ~= "insert" then
            hs.eventtap.keyStrokes('"*y')
            return true
        -- Y -> y$
        elseif c == "Y" and getVimMode() == "normal" then
            hs.eventtap.keyStrokes('"*y$')
            return true
        -- p -> "*p except if given a register
        elseif (c == "p" or c == "P") and keys[2] ~= '"' and getVimMode() ~= "insert" then
            hs.eventtap.keyStrokes('"*' .. c)
            return true
        -- U -> <C-R>
        elseif c == "U" and getVimMode() == "normal" then
            hs.eventtap.keyStroke({"ctrl"}, "r", 50)
            return true
        -- j/k -> gj/gk except if given a number
        elseif (c == "j" or c == "k") and keys[1] ~= "g" and tonumber(keys[1]) == nil and getVimMode() ~= "insert" then
            hs.eventtap.keyStrokes("g" .. c)
            return true
        -- : in normal mode
        elseif c == ":" and keys[1] ~= ":" and getVimMode() == "normal" then
            mask = true
        -- handle :?
        elseif keys[1] == ":" and getVimMode() == "normal" then
            -- :: beeps
            if c == ":" then
                keys = {} -- reset state
                return false
            -- :? is masked
            else
                mask = true
            end
        -- :%s opens search and replace
        elseif c == "s" and keys[1] == "%" and keys[2] == ":" and getVimMode() == "normal" then
            hs.eventtap.keyStroke({"cmd", "alt"}, "f", 50)
            mask = true
        -- handle :?<CR>
        elseif c == "\r" and keys[2] == ":" and getVimMode() == "normal" then
            -- :w<CR> saves
            if keys[1] == "w" then
                hs.eventtap.keyStroke({"cmd"}, "s", 50)
            -- beep otherwise by sending ::
            else
                hs.eventtap.keyStrokes("::")
            end
            mask = true
        -- gv selects last selection, doesn't work when selecting with the mouse
        -- can i make this not beep?
        elseif c == "v" and keys[1] == "g" and lastVisualRange ~= nil and getVimMode() == "normal" then
            lastVisualRange.length = lastVisualRange.length - 1 -- the range expands by 1 when enabling visual mode
            currentElement.AXSelectedTextRange = lastVisualRange
            hs.eventtap.keyStroke({}, "v", 50) -- send a v that won't get eaten by g
        else
            -- p({c, keys, getVimMode()})
        end

        -- cache keypress
        keys[2] = keys[1]
        keys[1] = c

        -- save visual mode range
        if getVimMode() == "visual" then
            lastVisualRange = currentElement.AXSelectedTextRange
        end


        -- clear cached vim mode on escape key or every 50 keypresses or when not in insert mode
        if keycode == escKey or keyCount % 50 == 0 or getVimMode() ~= "insert" then
            vimModeCache = nil
        end

        return mask
    else
        vimModeCache = nil
    end
end)

--- XcodeVim:start()
--- Method
--- Start XcodeVim
---
--- Parameters:
---  * None
function obj:start()
    local w = hs.window.focusedWindow()
    local a
    if w then
        a = w:application()
    end
    if a and a:name() == "Xcode" then
        et:start()
    end

    wf:subscribe(hs.window.filter.windowFocused, function(window, name, ev)
        if name == "Xcode" and window:subrole() == "AXStandardWindow" then
            et:start()
            locateBreakpointsButton()
        else
            et:stop()
            keys = {}
            vimModeCache = nil
        end
    end)

    return self
end

return obj
