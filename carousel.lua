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
        {text = "Option 1", r = 255, g = 100, b = 100},
        {text = "Option 2", r = 100, g = 255, b = 100},
        {text = "Option 3", r = 100, g = 100, b = 255},
        {text = "Option 4", r = 255, g = 255, b = 100},
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
        background = "#1e1e1e",
        primary = "#2d2d2d",
        secondary = "#3d3d3d",
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
    local centerX = canvasWidth / 2
    local centerY = canvasHeight / 2
    local radius = math.min(canvasWidth, canvasHeight) / 2 - 50

    if #state.options == 0 then
        return
    end

    local theme = themes[state.currentTheme]
    local angleStep = (2 * math.pi) / #state.options

    -- Draw wheel sectors
    for i, option in ipairs(state.options) do
        local startAngle = (i - 1) * angleStep + math.rad(state.currentAngle)
        local endAngle = i * angleStep + math.rad(state.currentAngle)
        local midAngle = (startAngle + endAngle) / 2

        -- Blend option color with theme accent
        local accentR, accentG, accentB = hexToRGBA(theme.accent)
        local r, g, b = blendColors(option.r, option.g, option.b, accentR, accentG, accentB, 0.2)

        -- Draw sector (simplified - would need arc support)
        -- For now, draw as circles to represent options
        local optionX = centerX + math.cos(midAngle) * (radius * 0.7)
        local optionY = centerY + math.sin(midAngle) * (radius * 0.7)

        canvas.fill(r, g, b)
        canvas.circle("fill", optionX, optionY, 40)

        -- Draw text
        canvas.fill(255, 255, 255)
        canvas.setFontSize(16)
        canvas.print(option.text, optionX - 20, optionY - 8)
    end

    -- Draw center circle
    canvas.fill(hexToRGBA(theme.primary))
    canvas.circle("fill", centerX, centerY, 50)

    -- Draw pointer
    canvas.fill(255, 0, 0)
    local pointerPoints = {
        {x = centerX + radius + 10, y = centerY},
        {x = centerX + radius - 10, y = centerY - 15},
        {x = centerX + radius - 10, y = centerY + 15},
    }
    canvas.polygon("fill", pointerPoints)
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
    width = "900px",
    height = "700px",
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
            height = "640px",
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
                        },

                        -- Options list
                        UI.Column {
                            gap = 5,
                            children = {
                                -- Would dynamically create option items here
                            },
                        },
                    },
                },

                -- Canvas panel
                UI.Column {
                    width = "580px",
                    height = "100%",
                    gap = 10,
                    alignItems = "center",
                    children = {
                        -- Canvas
                        UI.Canvas {
                            width = 600,
                            height = 500,
                            background = theme.secondary,
                            onDraw = function()
                                drawCarousel(600, 500)
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
                            onClick = spinWheel,
                        },
                    },
                },
            },
        },
    },
}

-- ============================================================================
-- Return App
-- ============================================================================

return {
    root = root,
    window = {
        width = 900,
        height = 700,
        title = "Decision Wheel"
    }
}
