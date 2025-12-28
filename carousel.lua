-- Decision Wheel Carousel
-- A spinning wheel app built with Kryon and Canvas plugin

local UI = require("kryon.dsl")
local Reactive = require("kryon.reactive")
local canvas = require("canvas")

-- ============================================================================
-- App State
-- ============================================================================

local state = {
    options = {
        {text = "Meditation", r = 100, g = 180, b = 255},  -- Blue
        {text = "Push ups", r = 255, g = 100, b = 100},    -- Red
        {text = "Jogging", r = 100, g = 255, b = 100},     -- Green
    },
    currentAngle = 0,
    spinSpeed = 0,
    isSpinning = false,
    inputText = "",
    editIndex = -1,
    currentTheme = 1,
}

local themes = {
    {
        name = "Dark",
        background = "#0a0a0a",
        primary = "#151515",
        secondary = "#202020",
        text = "#ffffff",
        accent = "#4a9eff",
    },
    {
        name = "Light",
        background = "#f0f0f0",
        primary = "#ffffff",
        secondary = "#e0e0e0",
        text = "#000000",
        accent = "#4a9eff",
    },
    {
        name = "Ocean",
        background = "#0a192f",
        primary = "#112240",
        secondary = "#1d3557",
        text = "#8892b0",
        accent = "#64ffda",
    },
}

-- ============================================================================
-- Utility Functions
-- ============================================================================

local function colorToRGBA(r, g, b, a)
    a = a or 255
    return bit.lshift(r, 24) + bit.lshift(g, 16) + bit.lshift(b, 8) + a
end

local function hexToRGBA(hex)
    hex = hex:gsub("#", "")
    local r = tonumber(hex:sub(1, 2), 16)
    local g = tonumber(hex:sub(3, 4), 16)
    local b = tonumber(hex:sub(5, 6), 16)
    local a = 255
    if #hex == 8 then
        a = tonumber(hex:sub(7, 8), 16)
    end
    return colorToRGBA(r, g, b, a)
end

local function blendColors(r1, g1, b1, r2, g2, b2, blend)
    local r = math.floor(r1 * (1 - blend) + r2 * blend)
    local g = math.floor(g1 * (1 - blend) + g2 * blend)
    local b = math.floor(b1 * (1 - blend) + b2 * blend)
    return r, g, b
end

-- ============================================================================
-- Carousel Drawing
-- ============================================================================

local function drawCarousel(canvasWidth, canvasHeight)
    print(string.format("[CAROUSEL] drawCarousel called: width=%d height=%d, options=%d", canvasWidth, canvasHeight, #state.options))

    -- CRITICAL: Reset transform matrix to identity at start of each frame
    -- Without this, transforms accumulate across frames causing rightward drift
    canvas.origin()

    local theme = themes[state.currentTheme]

    -- Clear canvas with background color
    local bgHex = theme.secondary:gsub("#", "")
    local bgR = tonumber(bgHex:sub(1, 2), 16)
    local bgG = tonumber(bgHex:sub(3, 4), 16)
    local bgB = tonumber(bgHex:sub(5, 6), 16)
    canvas.clear(bgR, bgG, bgB, 255)

    local centerX = canvasWidth / 2
    local centerY = canvasHeight / 2
    -- Use 80px padding to ensure wheel fits comfortably with even spacing
    local radius = math.min(canvasWidth, canvasHeight) / 2 - 80
    print(string.format("[CAROUSEL] Center: (%.1f, %.1f), Radius: %.1f", centerX, centerY, radius))

    if #state.options == 0 then
        print("[CAROUSEL] No options to draw")
        return
    end
    local angleStep = (2 * math.pi) / #state.options
    local currentAngleRad = math.rad(state.currentAngle)

    -- Draw wheel sectors as pie chart
    for i, option in ipairs(state.options) do
        local startAngle = (i - 1) * angleStep + currentAngleRad - math.pi / 2
        local endAngle = i * angleStep + currentAngleRad - math.pi / 2

        -- Blend option color with theme accent for visual appeal
        local accentR, accentG, accentB = 0x4a, 0x9e, 0xff  -- Default blue accent
        if theme.accent then
            local accentHex = theme.accent:gsub("#", "")
            accentR = tonumber(accentHex:sub(1, 2), 16) or accentR
            accentG = tonumber(accentHex:sub(3, 4), 16) or accentG
            accentB = tonumber(accentHex:sub(5, 6), 16) or accentB
        end

        local r, g, b = blendColors(option.r, option.g, option.b, accentR, accentG, accentB, 0.2)

        -- Draw pie sector as polygon (arc doesn't support fill mode)
        canvas.fill(r, g, b)

        -- Create polygon vertices for pie sector
        local vertices = {centerX, centerY}  -- Start at center
        local numSegments = 32
        for j = 0, numSegments do
            local angle = startAngle + (endAngle - startAngle) * (j / numSegments)
            local px = centerX + math.cos(angle) * radius
            local py = centerY + math.sin(angle) * radius
            table.insert(vertices, px)
            table.insert(vertices, py)
        end
        canvas.polygon("fill", vertices)

        -- Draw text on sector
        local midAngle = (startAngle + endAngle) / 2
        local textRadius = radius * 0.6
        local textX = centerX + math.cos(midAngle) * textRadius
        local textY = centerY + math.sin(midAngle) * textRadius

        -- Measure text to center it properly
        local textWidth = canvas.getTextWidth(option.text)
        local textHeight = canvas.getTextHeight()

        -- Save transform state
        canvas.push()

        -- Move to text position
        canvas.translate(textX, textY)

        -- Rotate text to align with sector (optional - makes it more readable)
        canvas.rotate(midAngle + math.pi / 2)

        -- Draw centered text
        canvas.fill(255, 255, 255)
        canvas.print(option.text, -textWidth / 2, -textHeight / 2)

        -- Restore transform state
        canvas.pop()
    end

    -- Draw center circle
    if theme.primary then
        local hexColor = theme.primary:gsub("#", "")
        local pr = tonumber(hexColor:sub(1, 2), 16) or 45
        local pg = tonumber(hexColor:sub(3, 4), 16) or 45
        local pb = tonumber(hexColor:sub(5, 6), 16) or 45
        canvas.fill(pr, pg, pb)
    else
        canvas.fill(45, 45, 45)
    end
    canvas.circle("fill", centerX, centerY, 50)

    -- Draw pointer triangle at top
    canvas.fill(255, 0, 0)
    local pointerY = centerY - radius - 10
    canvas.polygon("fill", {
        centerX, pointerY - 10,
        centerX - 10, pointerY + 10,
        centerX + 10, pointerY + 10
    })
end

-- ============================================================================
-- Spin Logic
-- ============================================================================

local function spinWheel()
    if state.isSpinning then
        return
    end

    state.isSpinning = true
    state.spinSpeed = math.random(20, 40)
end

local function updateSpin(deltaTime)
    if not state.isSpinning then
        return
    end

    state.currentAngle = state.currentAngle + state.spinSpeed
    state.spinSpeed = state.spinSpeed * 0.97

    if state.spinSpeed < 0.1 then
        state.isSpinning = false
        state.spinSpeed = 0

        -- Snap to nearest option
        local angleStep = 360 / #state.options
        local normalizedAngle = state.currentAngle % 360
        local nearestIndex = math.floor((normalizedAngle + angleStep / 2) / angleStep) + 1
        state.currentAngle = (nearestIndex - 1) * angleStep
    end
end

-- ============================================================================
-- Options Management
-- ============================================================================

local function addOption()
    if state.inputText ~= "" then
        local r = math.random(100, 255)
        local g = math.random(100, 255)
        local b = math.random(100, 255)

        if state.editIndex >= 0 then
            state.options[state.editIndex].text = state.inputText
            state.editIndex = -1
        else
            table.insert(state.options, {text = state.inputText, r = r, g = g, b = b})
        end

        state.inputText = ""
    end
end

local function deleteOption(index)
    if #state.options > 1 then
        table.remove(state.options, index)
    end
end

local function editOption(index)
    state.inputText = state.options[index].text
    state.editIndex = index
end

-- ============================================================================
-- UI Construction
-- ============================================================================

local theme = themes[state.currentTheme]

local root = UI.Column {
    width = "1200px",
    height = "900px",
    background = theme.background,
    windowTitle = "Decision Wheel",
    children = {
        -- Header
        UI.Container {
            width = "100%",
            height = "60px",
            background = theme.primary,
            padding = "10px",
            children = {
                UI.Text {
                    text = "Decision Wheel",
                    fontSize = 32,
                    color = theme.text,
                },
            },
        },

        -- Main content
        UI.Row {
            width = "100%",
            height = "840px",
            gap = 20,
            padding = "20px",
            children = {
                -- Options panel
                UI.Column {
                    width = "300px",
                    height = "100%",
                    gap = 10,
                    background = theme.primary,
                    padding = "15px",
                    children = {
                        UI.Text {
                            text = "Options",
                            fontSize = 20,
                            color = theme.text,
                        },

                        -- Input field
                        UI.Input {
                            placeholder = "Enter option...",
                            value = state.inputText,
                            onChange = function(value)
                                state.inputText = value
                            end,
                        },

                        -- Add button
                        UI.Button {
                            text = state.editIndex >= 0 and "Update" or "Add Option",
                            onClick = addOption,
                            background = theme.accent,
                            color = "#ffffff",
                            padding = 10,
                            width = "100%",
                        },

                        -- Options list
                        UI.Column {
                            gap = 5,
                            children = {
                                -- Option 1: Meditation
                                UI.Row {
                                    width = "100%",
                                    gap = 5,
                                    padding = "8px",
                                    background = "#2a2a2a",
                                    children = {
                                        UI.Text {
                                            text = "Meditation",
                                            color = theme.text,
                                            fontSize = 14,
                                        },
                                    },
                                },

                                -- Option 2: Push ups
                                UI.Row {
                                    width = "100%",
                                    gap = 5,
                                    padding = "8px",
                                    background = "#2a2a2a",
                                    children = {
                                        UI.Text {
                                            text = "Push ups",
                                            color = theme.text,
                                            fontSize = 14,
                                        },
                                    },
                                },

                                -- Option 3: Jogging
                                UI.Row {
                                    width = "100%",
                                    gap = 5,
                                    padding = "8px",
                                    background = "#2a2a2a",
                                    children = {
                                        UI.Text {
                                            text = "Jogging",
                                            color = theme.text,
                                            fontSize = 14,
                                        },
                                    },
                                },
                            },
                        },
                    },
                },

                -- Canvas panel
                UI.Column {
                    width = "850px",
                    height = "100%",
                    gap = 10,
                    alignItems = "center",
                    children = {
                        -- Canvas
                        UI.Canvas {
                            width = 800,
                            height = 700,
                            background = theme.secondary,
                            onDraw = function()
                                print("[carousel] Canvas onDraw called")
                                drawCarousel(800, 700)
                            end,
                            onUpdate = function(dt)
                                updateSpin(dt)
                            end,
                        },

                        -- Spin button
                        UI.Button {
                            text = "SPIN!",
                            width = "200px",
                            height = "50px",
                            fontSize = 24,
                            background = theme.accent,
                            color = "#ffffff",
                            onClick = spinWheel,
                        },
                    },
                },
            },
        },
    },
}

-- ============================================================================
-- Run App
-- ============================================================================

-- Create app configuration
local app = {
    root = root,
    window = {
        width = 1200,
        height = 900,
        title = "Decision Wheel"
    }
}

return app
