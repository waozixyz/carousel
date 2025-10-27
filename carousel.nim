import ../kryon/src/kryon
import std/[math, tables, json, os, random, strutils]

# Constants
const
  MAX_OPTIONS = 20
  CAROUSEL_FILE = "~/Documents/quest/carousel.json"

# Data structures
type
  Theme = object
    name: string
    background: string
    primary: string
    secondary: string
    text: string
    accent: string

  CarouselOption = object
    text: string
    r, g, b: uint8

  CarouselData = object
    options: seq[CarouselOption]
    currentAngle: float

# Global state
var
  options: seq[CarouselOption] = @[]
  currentAngle: float = -90.0
  isSpinning: bool = false
  spinSpeed: float = 0.0
  inputText: string = ""
  isEditMode: bool = false
  editIndex: int = -1
  currentThemeIndex: int = 0

# Theme definitions
let themes = @[
  Theme(
    name: "Dark",
    background: "#1a1a1a",
    primary: "#2d2d2d",
    secondary: "#3d3d3d",
    text: "#ffffff",
    accent: "#4a90e2"
  ),
  Theme(
    name: "Light",
    background: "#f5f5f5",
    primary: "#ffffff",
    secondary: "#e0e0e0",
    text: "#333333",
    accent: "#2196f3"
  ),
  Theme(
    name: "Ocean",
    background: "#0d1b2a",
    primary: "#1b263b",
    secondary: "#415a77",
    text: "#e0e1dd",
    accent: "#778da9"
  )
]

proc getCurrentTheme(): Theme =
  themes[currentThemeIndex]

# Generate random color for options
proc generateRandomColor(): tuple[r, g, b: uint8] =
  result.r = uint8(rand(50..255))
  result.g = uint8(rand(50..255))
  result.b = uint8(rand(50..255))

# Save options to JSON file
proc saveOptions() =
  let filePath = expandTilde(CAROUSEL_FILE)
  let dir = parentDir(filePath)

  if not dirExists(dir):
    createDir(dir)

  var optionsArray = newJArray()
  for opt in options:
    optionsArray.add(%* {
      "text": opt.text,
      "r": opt.r,
      "g": opt.g,
      "b": opt.b
    })

  let jsonNode = %* {
    "options": optionsArray,
    "currentAngle": currentAngle
  }

  try:
    writeFile(filePath, jsonNode.pretty())
  except:
    echo "Error saving carousel: ", getCurrentExceptionMsg()

# Load options from JSON file
proc loadOptions() =
  let filePath = expandTilde(CAROUSEL_FILE)

  if not fileExists(filePath):
    # Create default options
    let color1 = generateRandomColor()
    let color2 = generateRandomColor()
    let color3 = generateRandomColor()
    options = @[
      CarouselOption(text: "Option 1", r: color1.r, g: color1.g, b: color1.b),
      CarouselOption(text: "Option 2", r: color2.r, g: color2.g, b: color2.b),
      CarouselOption(text: "Option 3", r: color3.r, g: color3.g, b: color3.b)
    ]
    return

  try:
    let jsonContent = readFile(filePath)
    let jsonNode = parseJson(jsonContent)

    options = @[]
    for optNode in jsonNode["options"]:
      options.add(CarouselOption(
        text: optNode["text"].getStr(),
        r: uint8(optNode["r"].getInt()),
        g: uint8(optNode["g"].getInt()),
        b: uint8(optNode["b"].getInt())
      ))

    if jsonNode.hasKey("currentAngle"):
      currentAngle = jsonNode["currentAngle"].getFloat()
  except:
    echo "Error loading carousel: ", getCurrentExceptionMsg()
    let color1 = generateRandomColor()
    options = @[CarouselOption(text: "Option 1", r: color1.r, g: color1.g, b: color1.b)]

# Get sector angle
proc getSectorAngle(): float =
  if options.len == 0:
    return 0.0
  360.0 / options.len.float

# Update spinning animation
proc updateSpin() =
  if not isSpinning:
    return

  if spinSpeed > 1.0:
    currentAngle += spinSpeed
    spinSpeed *= 0.97
  else:
    # Snap to nearest sector
    let sectorAngle = getSectorAngle()
    let halfSectorAngle = sectorAngle / 2.0

    let normalizedAngle = currentAngle + halfSectorAngle
    let sector = floor(normalizedAngle / sectorAngle)
    let targetAngle = (sector * sectorAngle) - halfSectorAngle

    var angleDiff = targetAngle - currentAngle
    if angleDiff > 180.0: angleDiff -= 360.0
    if angleDiff < -180.0: angleDiff += 360.0

    let moveSpeed = angleDiff * 0.1
    currentAngle += moveSpeed

    if abs(moveSpeed) < 0.01:
      isSpinning = false
      currentAngle = targetAngle
      spinSpeed = 0.0
      saveOptions()

  # Normalize angle
  while currentAngle >= 360.0: currentAngle -= 360.0
  while currentAngle < 0.0: currentAngle += 360.0

# Draw the carousel wheel
proc drawCarousel(ctx: DrawingContext, width, height: float) =
  if options.len == 0:
    return

  let theme = getCurrentTheme()
  let centerX = width / 2.0
  let centerY = height / 2.0
  let radius = min(width, height) * 0.4
  let sectorAngle = getSectorAngle()

  # Draw sectors
  for i in 0..<options.len:
    let startAngle = currentAngle + i.float * sectorAngle - 90.0
    let endAngle = startAngle + sectorAngle

    # Convert to radians for arc drawing
    let startRad = startAngle * PI / 180.0
    let endRad = endAngle * PI / 180.0

    # Blend option color with theme
    let opt = options[i]
    let blendedR = (opt.r.int + parseHexInt(theme.accent[1..2])) div 2
    let blendedG = (opt.g.int + parseHexInt(theme.accent[3..4])) div 2
    let blendedB = (opt.b.int + parseHexInt(theme.accent[5..6])) div 2

    ctx.fillStyle = rgba(blendedR.uint8, blendedG.uint8, blendedB.uint8, 255)

    # Draw sector using arc
    ctx.beginPath()
    ctx.moveTo(centerX, centerY)
    ctx.arc(centerX, centerY, radius, startRad, endRad)
    ctx.closePath()
    ctx.fill()

    # Draw sector outline
    ctx.strokeStyle = rgba(0, 0, 0, 100)
    ctx.lineWidth = 2.0
    ctx.beginPath()
    ctx.moveTo(centerX, centerY)
    ctx.arc(centerX, centerY, radius, startRad, endRad)
    ctx.closePath()
    ctx.stroke()

  # Draw pointer triangle
  let accentColor = theme.accent
  let accentR = parseHexInt(accentColor[1..2]).uint8
  let accentG = parseHexInt(accentColor[3..4]).uint8
  let accentB = parseHexInt(accentColor[5..6]).uint8

  ctx.fillStyle = rgba(accentR, accentG, accentB, 255)
  ctx.beginPath()
  ctx.moveTo(centerX, centerY - radius - 20)
  ctx.lineTo(centerX - 10, centerY - radius)
  ctx.lineTo(centerX + 10, centerY - radius)
  ctx.closePath()
  ctx.fill()

# Add new option
proc addOption() =
  if options.len >= MAX_OPTIONS:
    return

  if inputText.len == 0:
    return

  if isEditMode and editIndex >= 0 and editIndex < options.len:
    # Edit existing
    options[editIndex].text = inputText
    isEditMode = false
    editIndex = -1
  else:
    # Add new
    let color = generateRandomColor()
    options.add(CarouselOption(text: inputText, r: color.r, g: color.g, b: color.b))

  inputText = ""
  saveOptions()

# Delete option
proc deleteOption(index: int) =
  if index >= 0 and index < options.len:
    options.delete(index)
    saveOptions()

# Edit option
proc editOption(index: int) =
  if index >= 0 and index < options.len:
    inputText = options[index].text
    isEditMode = true
    editIndex = index
    echo isEditMode

# Spin the wheel
proc spinWheel() =
  if options.len == 0:
    return

  isSpinning = true
  spinSpeed = 20.0 + rand(10.0)
  # Don't save here - save when spin completes

# Clear all options
proc clearAllOptions() =
  options = @[]
  isSpinning = false
  spinSpeed = 0.0
  currentAngle = -90.0
  saveOptions()

# Initialize
randomize()
loadOptions()

# Main application
let app = kryonApp:
  Header:
    width = 900
    height = 700
    title = "Carousel"

  Body:
    backgroundColor = getCurrentTheme().background


    Text:
      text = "Decision Wheel"
      fontSize = 32
      color = getCurrentTheme().text

    Row:
      gap = 10
      alignItems = "center"
      Text:
        text = "Theme:"
        fontSize = 16
        color = getCurrentTheme().text

      for i in 0..<themes.len:
        Button:
          text = themes[i].name
          onClick = proc() = currentThemeIndex = i
          backgroundColor = if i == currentThemeIndex: getCurrentTheme().accent else: getCurrentTheme().secondary
          textColor = getCurrentTheme().text
          width = 80
          height = 30
          fontSize = 14

    # Left side - Options list
    Column:
      width = 350
      gap = 10
      backgroundColor = getCurrentTheme().primary

      for i in 0..<options.len:
        Row:
          gap = 10
          alignItems = "center"

          Text:
            text = $(i + 1) & ". " & options[i].text
            fontSize = 16
            color = getCurrentTheme().text
            width = 180

          Button:
            text = "Edit"
            onClick = editOption(i)
            backgroundColor = getCurrentTheme().accent
            textColor = getCurrentTheme().text
            width = 60
            height = 25
            fontSize = 12

          Button:
            text = "Delete"
            onClick = deleteOption(i)
            backgroundColor = "#d32f2f"
            textColor = "#ffffff"
            width = 60
            height = 25
            fontSize = 12

      Spacer()
      
      Text:
        echo isEditMode
        text = if isEditMode: "Editing option..." else: "Add new option"
        fontSize = 14
        color = getCurrentTheme().text

      Input:
        value = inputText
        onTextChange = proc(text: string) = inputText = text
        onSubmit = proc() = addOption()
        fontSize = 16
        color = getCurrentTheme().text
        backgroundColor = getCurrentTheme().secondary
        width = 350
        height = 40

      Button:
        text = if isEditMode: "Save Edit" else: "Add Option"
        onClick = proc() = addOption()
        backgroundColor = getCurrentTheme().accent
        textColor = getCurrentTheme().text
        width = 350
        height = 40
        fontSize = 16