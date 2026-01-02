#!/usr/bin/env python3
"""
Claude_Like_NoPain EA - MEGA Dokumentacia
Jeden velky detailny diagram + kompletny popis
"""

from reportlab.lib.pagesizes import A4, landscape, A3
from reportlab.lib.units import cm, mm
from reportlab.lib.colors import HexColor, black, white
from reportlab.pdfgen import canvas
import math

# Colors
BLUE = HexColor('#2563eb')
DARK_BLUE = HexColor('#1e40af')
GREEN = HexColor('#16a34a')
DARK_GREEN = HexColor('#166534')
RED = HexColor('#dc2626')
DARK_RED = HexColor('#991b1b')
ORANGE = HexColor('#ea580c')
PURPLE = HexColor('#9333ea')
CYAN = HexColor('#0891b2')
PINK = HexColor('#db2777')
GRAY = HexColor('#6b7280')
DARK_GRAY = HexColor('#374151')
LIGHT_BLUE = HexColor('#dbeafe')
LIGHT_GREEN = HexColor('#dcfce7')
LIGHT_RED = HexColor('#fee2e2')
LIGHT_ORANGE = HexColor('#ffedd5')
LIGHT_PURPLE = HexColor('#f3e8ff')
LIGHT_CYAN = HexColor('#cffafe')
LIGHT_PINK = HexColor('#fce7f3')
LIGHT_GRAY = HexColor('#f3f4f6')
YELLOW = HexColor('#eab308')
LIGHT_YELLOW = HexColor('#fef9c3')

def draw_box(c, x, y, w, h, text, fill_color, text_color=black, border_color=None, corner=5, font_size=9, bold=True):
    """Draw a rounded rectangle with text"""
    c.setFillColor(fill_color)
    if border_color:
        c.setStrokeColor(border_color)
        c.setLineWidth(1.5)
    else:
        c.setStrokeColor(DARK_GRAY)
        c.setLineWidth(0.5)
    c.roundRect(x, y, w, h, corner, fill=1, stroke=1)
    c.setFillColor(text_color)
    if bold:
        c.setFont("Helvetica-Bold", font_size)
    else:
        c.setFont("Helvetica", font_size)

    lines = text.split('\n')
    line_height = font_size + 2
    total_height = len(lines) * line_height
    start_y = y + h/2 + total_height/2 - line_height/2 - 1

    for i, line in enumerate(lines):
        c.drawCentredString(x + w/2, start_y - i*line_height, line)

def draw_diamond(c, x, y, w, h, text, fill_color, border_color=None):
    """Draw a diamond shape for decisions"""
    c.setFillColor(fill_color)
    if border_color:
        c.setStrokeColor(border_color)
        c.setLineWidth(1.5)
    else:
        c.setStrokeColor(DARK_GRAY)
        c.setLineWidth(0.5)
    path = c.beginPath()
    path.moveTo(x + w/2, y + h)
    path.lineTo(x + w, y + h/2)
    path.lineTo(x + w/2, y)
    path.lineTo(x, y + h/2)
    path.close()
    c.drawPath(path, fill=1, stroke=1)

    c.setFillColor(black)
    c.setFont("Helvetica-Bold", 7)
    lines = text.split('\n')
    line_height = 9
    start_y = y + h/2 + (len(lines)-1)*line_height/2
    for i, line in enumerate(lines):
        c.drawCentredString(x + w/2, start_y - i*line_height, line)

def draw_arrow(c, x1, y1, x2, y2, label="", color=GRAY, dashed=False, line_width=1.5):
    """Draw an arrow between two points"""
    c.setStrokeColor(color)
    c.setLineWidth(line_width)
    if dashed:
        c.setDash([4, 4])
    else:
        c.setDash([])
    c.line(x1, y1, x2, y2)

    angle = math.atan2(y2-y1, x2-x1)
    arrow_len = 7
    c.line(x2, y2, x2 - arrow_len*math.cos(angle-0.4), y2 - arrow_len*math.sin(angle-0.4))
    c.line(x2, y2, x2 - arrow_len*math.cos(angle+0.4), y2 - arrow_len*math.sin(angle+0.4))
    c.setDash([])

    if label:
        c.setFont("Helvetica-Bold", 7)
        c.setFillColor(color)
        mid_x = (x1 + x2) / 2
        mid_y = (y1 + y2) / 2
        c.drawString(mid_x + 3, mid_y + 2, label)

def draw_connector(c, points, color=GRAY, dashed=False):
    """Draw connected lines through multiple points"""
    c.setStrokeColor(color)
    c.setLineWidth(1.5)
    if dashed:
        c.setDash([4, 4])
    for i in range(len(points) - 1):
        c.line(points[i][0], points[i][1], points[i+1][0], points[i+1][1])
    c.setDash([])

def draw_section_box(c, x, y, w, h, title, color):
    """Draw a section container box"""
    c.setFillColor(color)
    c.setStrokeColor(color)
    c.setLineWidth(2)
    c.roundRect(x, y, w, h, 8, fill=0, stroke=1)

    # Title background
    title_w = len(title) * 5 + 20
    c.setFillColor(color)
    c.rect(x + 10, y + h - 8, title_w, 16, fill=1, stroke=0)

    c.setFillColor(white)
    c.setFont("Helvetica-Bold", 9)
    c.drawString(x + 15, y + h - 3, title)

def create_mega_diagram(c, width, height):
    """Create the mega diagram with all functions"""

    # Title
    c.setFillColor(DARK_BLUE)
    c.setFont("Helvetica-Bold", 24)
    c.drawCentredString(width/2, height - 1.5*cm, "CLAUDE_LIKE_NOPAIN EA v4.30 - KOMPLETNY VYVOJOVY DIAGRAM")

    c.setFont("Helvetica", 11)
    c.setFillColor(GRAY)
    c.drawCentredString(width/2, height - 2.1*cm, "MTF Analysis | Trailing Stop | Spread Filter | Breakeven | AUDCAD Grid Trading")

    # =========================================================================
    # SECTION 1: LIFECYCLE (top left)
    # =========================================================================
    sec1_x = 1*cm
    sec1_y = height - 10*cm
    sec1_w = 8*cm
    sec1_h = 7*cm

    draw_section_box(c, sec1_x, sec1_y, sec1_w, sec1_h, "ZIVOTNY CYKLUS", DARK_BLUE)

    # OnInit
    box_y = sec1_y + sec1_h - 1.5*cm
    draw_box(c, sec1_x + 0.5*cm, box_y, 3*cm, 1*cm, "OnInit()", DARK_BLUE, white, font_size=10)

    # OnInit sub-items
    init_items = [
        ("SymbolSelect", "AUDCAD"),
        ("trade.Set*()", "Magic, Dev"),
        ("iRSI()", "Handle"),
        ("ArrayResize", "Grid[]"),
    ]
    item_y = box_y - 0.3*cm
    for name, desc in init_items:
        item_y -= 0.7*cm
        draw_box(c, sec1_x + 0.8*cm, item_y, 2.5*cm, 0.6*cm, name, LIGHT_BLUE, font_size=6)
        c.setFont("Helvetica", 6)
        c.setFillColor(GRAY)
        c.drawString(sec1_x + 3.5*cm, item_y + 0.2*cm, desc)

    # OnTick
    draw_box(c, sec1_x + 4.2*cm, box_y, 3*cm, 1*cm, "OnTick()", PURPLE, white, font_size=10)
    c.setFont("Helvetica", 7)
    c.setFillColor(GRAY)
    c.drawString(sec1_x + 4.4*cm, box_y - 0.4*cm, "Kazdy tick")
    c.drawString(sec1_x + 4.4*cm, box_y - 0.7*cm, "Hlavna slucka")

    # OnDeinit
    draw_box(c, sec1_x + 4.2*cm, sec1_y + 0.5*cm, 3*cm, 1*cm, "OnDeinit()", DARK_GRAY, white, font_size=10)
    c.setFont("Helvetica", 6)
    c.setFillColor(GRAY)
    c.drawString(sec1_x + 4.4*cm, sec1_y + 0.2*cm, "Uvolni RSI, notifikuj")

    # Arrow from OnInit to OnTick
    draw_arrow(c, sec1_x + 3.5*cm, box_y + 0.5*cm, sec1_x + 4.2*cm, box_y + 0.5*cm, "", DARK_BLUE)

    # Arrow from OnTick to OnDeinit
    draw_arrow(c, sec1_x + 5.7*cm, box_y - 0.1*cm, sec1_x + 5.7*cm, sec1_y + 1.5*cm, "", GRAY, dashed=True)

    # =========================================================================
    # SECTION 2: MAIN ONTICK FLOW (center)
    # =========================================================================
    sec2_x = 10*cm
    sec2_y = height - 18*cm
    sec2_w = 10*cm
    sec2_h = 15*cm

    draw_section_box(c, sec2_x, sec2_y, sec2_w, sec2_h, "HLAVNY TOK OnTick()", PURPLE)

    flow_x = sec2_x + sec2_w/2 - 1.5*cm
    flow_y = sec2_y + sec2_h - 1.8*cm

    # Monitoring block
    draw_box(c, flow_x - 0.5*cm, flow_y, 4*cm, 0.8*cm, "MONITORING CHECKS", LIGHT_PURPLE, font_size=7)
    flow_y -= 1.2*cm
    draw_arrow(c, flow_x + 1.5*cm, flow_y + 1.2*cm, flow_x + 1.5*cm, flow_y + 0.8*cm, "", PURPLE)

    # IsTradingTime
    draw_diamond(c, flow_x - 0.3*cm, flow_y - 0.5*cm, 3.6*cm, 1.3*cm, "IsTradingTime()?\nPo-Pia 0-23h", LIGHT_ORANGE)

    # NO -> return
    c.setFont("Helvetica-Bold", 6)
    c.setFillColor(RED)
    c.drawString(flow_x + 3.5*cm, flow_y + 0.2*cm, "NIE")
    draw_arrow(c, flow_x + 3.3*cm, flow_y + 0.15*cm, flow_x + 4.2*cm, flow_y + 0.15*cm, "", RED)
    draw_box(c, flow_x + 4.2*cm, flow_y - 0.1*cm, 1.3*cm, 0.5*cm, "return", GRAY, white, font_size=6)

    flow_y -= 1.8*cm
    c.setFillColor(GREEN)
    c.drawString(flow_x + 1.3*cm, flow_y + 1.5*cm, "ANO")
    draw_arrow(c, flow_x + 1.5*cm, flow_y + 1.3*cm, flow_x + 1.5*cm, flow_y + 0.8*cm, "", GREEN)

    # CheckDrawdown
    draw_diamond(c, flow_x - 0.3*cm, flow_y - 0.5*cm, 3.6*cm, 1.3*cm, "CheckDrawdown()\n>= 15%?", LIGHT_RED)

    # YES -> close all DD
    c.setFont("Helvetica-Bold", 6)
    c.setFillColor(RED)
    c.drawString(flow_x + 3.5*cm, flow_y + 0.2*cm, "ANO!")
    draw_arrow(c, flow_x + 3.3*cm, flow_y + 0.15*cm, flow_x + 4.2*cm, flow_y + 0.15*cm, "", RED)
    draw_box(c, flow_x + 4.2*cm, flow_y - 0.2*cm, 1.8*cm, 0.7*cm, "CloseAll\n(DD)", RED, white, font_size=6)

    flow_y -= 1.6*cm
    c.setFillColor(GREEN)
    c.drawString(flow_x + 1.3*cm, flow_y + 1.3*cm, "NIE")
    draw_arrow(c, flow_x + 1.5*cm, flow_y + 1.1*cm, flow_x + 1.5*cm, flow_y + 0.7*cm, "", GREEN)

    # UpdateGridInfo
    draw_box(c, flow_x, flow_y, 3*cm, 0.7*cm, "UpdateGridInfo()", LIGHT_CYAN, font_size=7)

    flow_y -= 1.3*cm
    draw_arrow(c, flow_x + 1.5*cm, flow_y + 1.3*cm, flow_x + 1.5*cm, flow_y + 0.8*cm, "", GRAY)

    # CheckTotalProfit
    draw_diamond(c, flow_x - 0.3*cm, flow_y - 0.5*cm, 3.6*cm, 1.3*cm, "CheckTotalProfit()\n>= 0.8%?", LIGHT_GREEN)

    # YES -> close all TP
    c.setFont("Helvetica-Bold", 6)
    c.setFillColor(GREEN)
    c.drawString(flow_x + 3.5*cm, flow_y + 0.2*cm, "ANO!")
    draw_arrow(c, flow_x + 3.3*cm, flow_y + 0.15*cm, flow_x + 4.2*cm, flow_y + 0.15*cm, "", GREEN)
    draw_box(c, flow_x + 4.2*cm, flow_y - 0.2*cm, 1.8*cm, 0.7*cm, "CloseAll\n(TP)", GREEN, white, font_size=6)

    flow_y -= 1.8*cm
    c.setFillColor(GRAY)
    c.drawString(flow_x + 1.3*cm, flow_y + 1.5*cm, "NIE")
    draw_arrow(c, flow_x + 1.5*cm, flow_y + 1.3*cm, flow_x + 1.5*cm, flow_y + 0.8*cm, "", GRAY)

    # Has positions?
    draw_diamond(c, flow_x - 0.3*cm, flow_y - 0.5*cm, 3.6*cm, 1.3*cm, "Existuju\npozicie?", LIGHT_BLUE)

    # NO -> GetSignal
    c.setFont("Helvetica-Bold", 6)
    c.setFillColor(ORANGE)
    c.drawString(flow_x - 1.5*cm, flow_y + 0.2*cm, "NIE")
    draw_arrow(c, flow_x - 0.3*cm, flow_y + 0.15*cm, flow_x - 1.2*cm, flow_y + 0.15*cm, "", ORANGE)
    draw_box(c, flow_x - 3.2*cm, flow_y - 0.3*cm, 2*cm, 0.9*cm, "GetSignal()\nRSI", ORANGE, white, font_size=7)

    # YES -> ManageGrid
    c.setFillColor(BLUE)
    c.drawString(flow_x + 3.5*cm, flow_y + 0.2*cm, "ANO")
    draw_arrow(c, flow_x + 3.3*cm, flow_y + 0.15*cm, flow_x + 4.2*cm, flow_y + 0.15*cm, "", BLUE)
    draw_box(c, flow_x + 4.2*cm, flow_y - 0.3*cm, 2.2*cm, 0.9*cm, "ManageGrid()\nPridaj level", BLUE, white, font_size=7)

    # From GetSignal to OpenGridPosition
    draw_arrow(c, flow_x - 2.2*cm, flow_y - 0.3*cm, flow_x - 2.2*cm, flow_y - 1.2*cm, "", ORANGE)
    draw_box(c, flow_x - 3.6*cm, flow_y - 2*cm, 2.8*cm, 0.8*cm, "OpenGridPosition()\nLevel 0", GREEN, white, font_size=7)

    # =========================================================================
    # SECTION 3: SIGNAL LOGIC (left) - with MTF
    # =========================================================================
    sec3_x = 1*cm
    sec3_y = height - 18*cm
    sec3_w = 8*cm
    sec3_h = 7.5*cm

    draw_section_box(c, sec3_x, sec3_y, sec3_w, sec3_h, "SIGNALOVA LOGIKA + MTF", ORANGE)

    sig_y = sec3_y + sec3_h - 1.3*cm

    # GetSignal detail
    draw_box(c, sec3_x + 0.4*cm, sig_y, 2.5*cm, 0.65*cm, "GetSignal()", ORANGE, white, font_size=8)

    # MTF Analysis box - right side
    draw_box(c, sec3_x + 4.5*cm, sig_y + 0.3*cm, 3.2*cm, 1.8*cm, "MTF ANALYZA\nD1 + H4 + H1\nTrend filter", PURPLE, white, font_size=6)
    c.setFont("Helvetica", 5)
    c.setFillColor(GRAY)
    c.drawString(sec3_x + 4.6*cm, sig_y - 0.1*cm, "RSI>55=UP, <45=DOWN")

    # RSI check
    sig_y -= 1.1*cm
    draw_arrow(c, sec3_x + 1.65*cm, sig_y + 1.1*cm, sec3_x + 1.65*cm, sig_y + 0.65*cm, "", ORANGE)
    draw_box(c, sec3_x + 0.4*cm, sig_y, 2.5*cm, 0.55*cm, "CopyBuffer(RSI)", LIGHT_ORANGE, font_size=6)

    # BUY condition
    sig_y -= 0.9*cm
    draw_arrow(c, sec3_x + 1.65*cm, sig_y + 0.9*cm, sec3_x + 1.65*cm, sig_y + 0.65*cm, "", GRAY)
    draw_diamond(c, sec3_x + 0.2*cm, sig_y - 0.25*cm, 2.9*cm, 0.9*cm, "RSI<35?", LIGHT_GREEN, GREEN)

    c.setFont("Helvetica-Bold", 6)
    c.setFillColor(GREEN)
    c.drawString(sec3_x + 3.3*cm, sig_y + 0.2*cm, "ANO")
    draw_arrow(c, sec3_x + 3.1*cm, sig_y + 0.15*cm, sec3_x + 3.7*cm, sig_y + 0.15*cm, "", GREEN)
    draw_box(c, sec3_x + 3.7*cm, sig_y - 0.05*cm, 2*cm, 0.5*cm, "BUY", GREEN, white, font_size=6)

    # SELL condition
    sig_y -= 1.1*cm
    c.setFillColor(GRAY)
    c.setFont("Helvetica-Bold", 6)
    c.drawString(sec3_x + 1.4*cm, sig_y + 0.85*cm, "NIE")
    draw_arrow(c, sec3_x + 1.65*cm, sig_y + 0.7*cm, sec3_x + 1.65*cm, sig_y + 0.6*cm, "", GRAY)
    draw_diamond(c, sec3_x + 0.2*cm, sig_y - 0.25*cm, 2.9*cm, 0.9*cm, "RSI>65?", LIGHT_RED, RED)

    c.setFont("Helvetica-Bold", 6)
    c.setFillColor(RED)
    c.drawString(sec3_x + 3.3*cm, sig_y + 0.2*cm, "ANO")
    draw_arrow(c, sec3_x + 3.1*cm, sig_y + 0.15*cm, sec3_x + 3.7*cm, sig_y + 0.15*cm, "", RED)
    draw_box(c, sec3_x + 3.7*cm, sig_y - 0.05*cm, 2*cm, 0.5*cm, "SELL", RED, white, font_size=6)

    # No signal
    sig_y -= 1*cm
    c.setFillColor(GRAY)
    c.setFont("Helvetica-Bold", 6)
    c.drawString(sec3_x + 1.4*cm, sig_y + 0.75*cm, "NIE")
    draw_arrow(c, sec3_x + 1.65*cm, sig_y + 0.6*cm, sec3_x + 1.65*cm, sig_y + 0.45*cm, "", GRAY)
    draw_box(c, sec3_x + 0.6*cm, sig_y - 0.15*cm, 2.1*cm, 0.5*cm, "return 0", GRAY, white, font_size=6)

    # =========================================================================
    # SECTION 4: GRID MANAGEMENT (right) - moved up
    # =========================================================================
    sec4_x = 21*cm
    sec4_y = height - 10.5*cm
    sec4_w = 8*cm
    sec4_h = 7.5*cm

    draw_section_box(c, sec4_x, sec4_y, sec4_w, sec4_h, "GRID MANAGEMENT", BLUE)

    grid_y = sec4_y + sec4_h - 1.5*cm

    # ManageGrid
    draw_box(c, sec4_x + 0.5*cm, grid_y, 3.5*cm, 0.8*cm, "ManageGrid()", BLUE, white, font_size=9)

    # BUY grid check
    grid_y -= 1.2*cm
    draw_arrow(c, sec4_x + 2.25*cm, grid_y + 1.2*cm, sec4_x + 2.25*cm, grid_y + 0.7*cm, "", BLUE)
    draw_diamond(c, sec4_x + 0.3*cm, grid_y - 0.4*cm, 4*cm, 1.1*cm, "buyLevels > 0\n& < maxLevels?", LIGHT_GREEN)

    c.setFont("Helvetica-Bold", 6)
    c.setFillColor(GREEN)
    c.drawString(sec4_x + 4.5*cm, grid_y + 0.2*cm, "ANO")
    draw_arrow(c, sec4_x + 4.3*cm, grid_y + 0.1*cm, sec4_x + 5*cm, grid_y + 0.1*cm, "", GREEN)

    # Find lowest buy
    draw_box(c, sec4_x + 5*cm, grid_y - 0.1*cm, 2.5*cm, 0.5*cm, "Najdi lowest", LIGHT_BLUE, font_size=6)

    grid_y -= 1.5*cm
    draw_diamond(c, sec4_x + 4.5*cm, grid_y, 3*cm, 0.9*cm, "ASK <=\nlowest-25pip?", LIGHT_ORANGE)

    c.setFillColor(GREEN)
    c.drawString(sec4_x + 7.6*cm, grid_y + 0.5*cm, "ANO")
    draw_arrow(c, sec4_x + 7.5*cm, grid_y + 0.45*cm, sec4_x + 7.5*cm, grid_y - 0.3*cm, "", GREEN)
    draw_box(c, sec4_x + 6.2*cm, grid_y - 0.9*cm, 2.5*cm, 0.6*cm, "OpenBUY\n+1 level", GREEN, white, font_size=6)

    # SELL grid (simplified)
    grid_y -= 1.8*cm
    c.setFillColor(GRAY)
    c.drawString(sec4_x + 2*cm, grid_y + 1.5*cm, "NIE")
    draw_arrow(c, sec4_x + 2.25*cm, grid_y + 1.3*cm, sec4_x + 2.25*cm, grid_y + 0.7*cm, "", GRAY)
    draw_diamond(c, sec4_x + 0.3*cm, grid_y - 0.4*cm, 4*cm, 1.1*cm, "sellLevels > 0\n& < maxLevels?", LIGHT_RED)

    c.setFillColor(RED)
    c.drawString(sec4_x + 4.5*cm, grid_y + 0.2*cm, "ANO")
    draw_box(c, sec4_x + 5*cm, grid_y - 0.1*cm, 2.5*cm, 0.5*cm, "Najdi highest", LIGHT_RED, font_size=6)

    grid_y -= 1.5*cm
    draw_diamond(c, sec4_x + 4.5*cm, grid_y, 3*cm, 0.9*cm, "BID >=\nhigh+25pip?", LIGHT_ORANGE)

    c.setFillColor(RED)
    c.drawString(sec4_x + 7.6*cm, grid_y + 0.5*cm, "ANO")
    draw_arrow(c, sec4_x + 7.5*cm, grid_y + 0.45*cm, sec4_x + 7.5*cm, grid_y - 0.3*cm, "", RED)
    draw_box(c, sec4_x + 6.2*cm, grid_y - 0.9*cm, 2.5*cm, 0.6*cm, "OpenSELL\n+1 level", RED, white, font_size=6)

    # =========================================================================
    # SECTION 5: LOT CALCULATION (bottom left)
    # =========================================================================
    sec5_x = 1*cm
    sec5_y = 1*cm
    sec5_w = 12*cm
    sec5_h = 6*cm

    draw_section_box(c, sec5_x, sec5_y, sec5_w, sec5_h, "AUTO LOT VYPOCET - CalculateLotSize()", DARK_GREEN)

    # Formula
    c.setFillColor(LIGHT_GREEN)
    c.roundRect(sec5_x + 0.3*cm, sec5_y + sec5_h - 2.5*cm, 11.4*cm, 1.8*cm, 5, fill=1, stroke=0)

    c.setFillColor(DARK_GREEN)
    c.setFont("Helvetica-Bold", 11)
    c.drawCentredString(sec5_x + 6*cm, sec5_y + sec5_h - 1.2*cm, "baseLot = (balance × risk%) ÷ (maxDDPips × pipValue × multiplierSum)")

    c.setFont("Helvetica", 8)
    c.setFillColor(black)
    c.drawString(sec5_x + 0.5*cm, sec5_y + sec5_h - 2.2*cm, "lot pre level N = baseLot × (1.3 ^ N)")

    # Variables
    vars_y = sec5_y + sec5_h - 3*cm
    var_items = [
        ("balance", "Aktualny zostatok"),
        ("risk%", "2% (default)"),
        ("maxDDPips", "25 × 7 = 175"),
        ("pipValue", "~$7.50 AUDCAD"),
        ("multiplierSum", "1+1.3+1.69+...=17.59"),
    ]

    x = sec5_x + 0.5*cm
    for var, val in var_items:
        draw_box(c, x, vars_y, 2.2*cm, 0.6*cm, var, CYAN, white, font_size=7)
        c.setFont("Helvetica", 6)
        c.setFillColor(GRAY)
        c.drawCentredString(x + 1.1*cm, vars_y - 0.3*cm, val)
        x += 2.4*cm

    # Lot progression table
    table_y = sec5_y + 1.5*cm
    c.setFont("Helvetica-Bold", 8)
    c.setFillColor(DARK_GRAY)
    c.drawString(sec5_x + 0.5*cm, table_y + 0.8*cm, "Priklad progresia ($5000 ucet):")

    levels = ["L0", "L1", "L2", "L3", "L4", "L5", "L6"]
    lots = ["0.08", "0.10", "0.13", "0.17", "0.22", "0.29", "0.38"]

    x = sec5_x + 0.5*cm
    for i, (lvl, lot) in enumerate(zip(levels, lots)):
        color = GREEN if i < 3 else (ORANGE if i < 5 else RED)
        draw_box(c, x, table_y, 1.4*cm, 0.7*cm, f"{lvl}\n{lot}", color, white, font_size=7)
        x += 1.55*cm

    # =========================================================================
    # SECTION 6: MONITORING (bottom center)
    # =========================================================================
    sec6_x = 14*cm
    sec6_y = 1*cm
    sec6_w = 7*cm
    sec6_h = 6*cm

    draw_section_box(c, sec6_x, sec6_y, sec6_w, sec6_h, "MONITORING SYSTEM", PURPLE)

    # Central hub
    hub_x = sec6_x + 3.5*cm
    hub_y = sec6_y + sec6_h - 2.5*cm
    draw_box(c, hub_x - 1.5*cm, hub_y, 3*cm, 0.8*cm, "SendNotification_All()", PURPLE, white, font_size=7)

    # Three outputs
    outputs = [
        ("SendDiscord()", BLUE, -2.5*cm),
        ("SendPush()", GREEN, 0),
        ("SendEmail()", ORANGE, 2.5*cm),
    ]

    out_y = hub_y - 1.5*cm
    for name, color, offset in outputs:
        draw_arrow(c, hub_x, hub_y, hub_x + offset, out_y + 0.6*cm, "", color)
        draw_box(c, hub_x + offset - 1.2*cm, out_y, 2.4*cm, 0.6*cm, name, color, white, font_size=6)

    # Input triggers
    triggers = [
        ("CheckHeartbeat", "1x/hod"),
        ("CheckDailyReport", "23:00"),
        ("CheckDrawdownAlert", ">10%"),
        ("NotifyTradeOpen", "Obchod"),
        ("NotifyTradeClose", "Profit"),
    ]

    trig_y = sec6_y + 0.5*cm
    trig_x = sec6_x + 0.3*cm
    for name, desc in triggers:
        draw_box(c, trig_x, trig_y, 2.8*cm, 0.5*cm, name, LIGHT_PURPLE, font_size=5)
        c.setFont("Helvetica", 5)
        c.setFillColor(GRAY)
        c.drawString(trig_x + 2.9*cm, trig_y + 0.15*cm, desc)
        trig_y += 0.55*cm

    # =========================================================================
    # SECTION 7: POSITION CLOSING (bottom right) - repositioned
    # =========================================================================
    sec7_x = 22*cm
    sec7_y = 1*cm
    sec7_w = 7*cm
    sec7_h = 5*cm

    draw_section_box(c, sec7_x, sec7_y, sec7_w, sec7_h, "ZATVARANIE POZICII", RED)

    # CloseAllPositions
    close_y = sec7_y + sec7_h - 1.3*cm
    draw_box(c, sec7_x + 0.5*cm, close_y, 3.5*cm, 0.7*cm, "CloseAllPositions()", RED, white, font_size=7)

    # Reasons - compact
    close_y -= 0.5*cm
    c.setFont("Helvetica-Bold", 6)
    c.setFillColor(DARK_RED)
    c.drawString(sec7_x + 0.5*cm, close_y, "Dovody zatvorenia:")

    reasons = [
        ("Target Profit", GREEN, "0.8%"),
        ("Max DD %", RED, "15%"),
        ("Equity $", ORANGE, "$ limit"),
        ("Breakeven", CYAN, "SL hit"),
    ]

    close_y -= 0.1*cm
    for name, color, desc in reasons:
        close_y -= 0.45*cm
        draw_box(c, sec7_x + 0.5*cm, close_y, 1.8*cm, 0.4*cm, name, color, white, font_size=5)
        c.setFont("Helvetica", 5)
        c.setFillColor(GRAY)
        c.drawString(sec7_x + 2.5*cm, close_y + 0.1*cm, desc)

    # =========================================================================
    # SECTION 8: NEW PROTECTIONS (v4.30) - above closing
    # =========================================================================
    sec8_x = 21*cm
    sec8_y = 6.5*cm
    sec8_w = 8*cm
    sec8_h = 6*cm

    draw_section_box(c, sec8_x, sec8_y, sec8_w, sec8_h, "OCHRANA v4.30", CYAN)

    prot_y = sec8_y + sec8_h - 1.5*cm

    # Spread Filter
    draw_box(c, sec8_x + 0.4*cm, prot_y, 2.3*cm, 0.7*cm, "CheckSpread()", CYAN, white, font_size=7)
    c.setFont("Helvetica", 5)
    c.setFillColor(GRAY)
    c.drawString(sec8_x + 2.9*cm, prot_y + 0.35*cm, "Max 3 pips")
    c.drawString(sec8_x + 2.9*cm, prot_y + 0.1*cm, "Blokuje obchod")

    # Equity Protection
    prot_y -= 1*cm
    draw_box(c, sec8_x + 0.4*cm, prot_y, 2.3*cm, 0.7*cm, "CheckEquity()", ORANGE, white, font_size=7)
    c.setFont("Helvetica", 5)
    c.setFillColor(GRAY)
    c.drawString(sec8_x + 2.9*cm, prot_y + 0.35*cm, "Max $ strata")
    c.drawString(sec8_x + 2.9*cm, prot_y + 0.1*cm, "Absolutna ochrana")

    # Breakeven
    prot_y -= 1*cm
    draw_box(c, sec8_x + 0.4*cm, prot_y, 2.5*cm, 0.7*cm, "ManageBreakeven()", GREEN, white, font_size=7)
    c.setFont("Helvetica", 5)
    c.setFillColor(GRAY)
    c.drawString(sec8_x + 3.1*cm, prot_y + 0.35*cm, "+10 pips profit")
    c.drawString(sec8_x + 3.1*cm, prot_y + 0.1*cm, "SL -> Entry+2")

    # Trailing Stop
    prot_y -= 1*cm
    draw_box(c, sec8_x + 0.4*cm, prot_y, 2.3*cm, 0.7*cm, "TrailingStop()", PURPLE, white, font_size=7)
    c.setFont("Helvetica", 5)
    c.setFillColor(GRAY)
    c.drawString(sec8_x + 2.9*cm, prot_y + 0.35*cm, "50 pips trail")
    c.drawString(sec8_x + 2.9*cm, prot_y + 0.1*cm, "Step 10 pips")

    # Dynamic TP
    prot_y -= 1*cm
    draw_box(c, sec8_x + 0.4*cm, prot_y, 2.3*cm, 0.7*cm, "Dynamic TP", DARK_GREEN, white, font_size=7)
    c.setFont("Helvetica", 5)
    c.setFillColor(GRAY)
    c.drawString(sec8_x + 2.9*cm, prot_y + 0.35*cm, "ATR(14) based")
    c.drawString(sec8_x + 2.9*cm, prot_y + 0.1*cm, "Min 10, Max 50")

    # =========================================================================
    # CONNECTING ARROWS BETWEEN SECTIONS
    # =========================================================================

    # OnTick to main flow
    draw_arrow(c, sec1_x + 5.7*cm, sec1_y, sec2_x + sec2_w/2, sec2_y + sec2_h, "", PURPLE, line_width=2)

    # Main flow to Signal
    draw_connector(c, [
        (sec2_x, sec2_y + 2*cm),
        (sec3_x + sec3_w, sec3_y + sec3_h/2),
    ], ORANGE)

    # Main flow to Grid
    draw_connector(c, [
        (sec2_x + sec2_w, sec2_y + 2*cm),
        (sec4_x, sec4_y + sec4_h/2),
    ], BLUE)

    # Grid/Signal to OpenPosition -> Lot calculation
    draw_connector(c, [
        (sec3_x + 3*cm, sec3_y),
        (sec3_x + 3*cm, sec5_y + sec5_h),
    ], GREEN, dashed=True)

    draw_connector(c, [
        (sec4_x + 2*cm, sec4_y),
        (sec5_x + sec5_w - 2*cm, sec5_y + sec5_h),
    ], GREEN, dashed=True)

    # =========================================================================
    # LEGEND
    # =========================================================================
    leg_x = 21*cm
    leg_y = height - 3*cm

    c.setFont("Helvetica-Bold", 9)
    c.setFillColor(black)
    c.drawString(leg_x, leg_y + 0.5*cm, "LEGENDA:")

    legend_items = [
        ("Proces", DARK_BLUE),
        ("Rozhodnutie", LIGHT_ORANGE),
        ("BUY signal", GREEN),
        ("SELL signal", RED),
        ("Monitoring", PURPLE),
        ("Grid mgmt", BLUE),
    ]

    for i, (name, color) in enumerate(legend_items):
        row = i // 2
        col = i % 2
        x = leg_x + col * 3.5*cm
        y = leg_y - row * 0.6*cm
        draw_box(c, x, y, 1.2*cm, 0.5*cm, "", color)
        c.setFont("Helvetica", 7)
        c.setFillColor(black)
        c.drawString(x + 1.4*cm, y + 0.15*cm, name)

def create_page_2_detail(c, width, height):
    """Second page with detailed parameter list and explanation"""

    # Title
    c.setFillColor(DARK_BLUE)
    c.setFont("Helvetica-Bold", 18)
    c.drawCentredString(width/2, height - 1.3*cm, "DETAILNY POPIS PARAMETROV A LOGIKY v4.30")

    y = height - 2.5*cm

    # Two columns
    col1_x = 1.2*cm
    col2_x = width/2 + 0.3*cm
    col_w = width/2 - 2*cm

    # Column 1: Parameters
    c.setFillColor(DARK_BLUE)
    c.setFont("Helvetica-Bold", 10)
    c.drawString(col1_x, y, "VSTUPNE PARAMETRE")

    params = [
        ("GRID", GREEN, [
            ("InpAutoLot = true", "Auto vypocet lotu"),
            ("InpRiskPercent = 2.0", "Risk na grid seriu"),
            ("InpLotMultiplier = 1.3", "Nasobitel lotov"),
            ("InpGridStepPips = 25", "Rozostup pozicii"),
            ("InpMaxGridLevels = 7", "Max pocet urovni"),
            ("InpTotalTPPercent = 0.8", "Cielovy profit %"),
        ]),
        ("RISK", RED, [
            ("InpMaxDrawdownPct = 15", "Max DD % pre zatvorenie"),
            ("InpMaxLossAmount = 0", "Max strata v $ (0=off)"),
            ("InpMagicNumber = 2262642", "ID nasich obchodov"),
        ]),
        ("SPREAD FILTER", CYAN, [
            ("InpMaxSpreadPips = 3.0", "Max spread (0=off)"),
        ]),
        ("BREAKEVEN", DARK_GREEN, [
            ("InpUseBreakeven = true", "Aktivovat breakeven"),
            ("InpBreakevenStart = 10", "+X pips pre aktivaciu"),
            ("InpBreakevenOffset = 2", "Offset od entry"),
        ]),
        ("TRAILING STOP", PURPLE, [
            ("InpUseTrailing = true", "Pouzit trailing"),
            ("InpTrailingPips = 50", "Trail vzdialenost"),
            ("InpTrailingStep = 10", "Min krok posunu"),
        ]),
        ("DYNAMIC TP", ORANGE, [
            ("InpUseDynamicTP = true", "ATR-based TP"),
            ("InpMinTPPips = 10", "Min TP"),
            ("InpMaxTPPips = 50", "Max TP"),
        ]),
    ]

    y -= 0.6*cm
    for group, color, items in params:
        c.setFillColor(color)
        c.setFont("Helvetica-Bold", 8)
        c.drawString(col1_x, y, group)
        y -= 0.32*cm

        for param, desc in items:
            c.setFont("Courier", 6)
            c.setFillColor(DARK_GRAY)
            c.drawString(col1_x + 0.15*cm, y, param)
            c.setFont("Helvetica", 6)
            c.setFillColor(GRAY)
            c.drawString(col1_x + 4.5*cm, y, desc)
            y -= 0.3*cm
        y -= 0.2*cm

    # Continue with MTF and TIME in column 1
    more_params = [
        ("MTF ANALYZA", PURPLE, [
            ("InpUseMTF = true", "Multi-timeframe filter"),
            ("D1/H4/H1 RSI", "Trend confirmation"),
        ]),
        ("CAS", GRAY, [
            ("InpStartHour = 0", "Od hodiny"),
            ("InpEndHour = 23", "Do hodiny"),
            ("InpTradeFriday = true", "Piatok povoleny"),
        ]),
    ]

    for group, color, items in more_params:
        c.setFillColor(color)
        c.setFont("Helvetica-Bold", 8)
        c.drawString(col1_x, y, group)
        y -= 0.32*cm

        for param, desc in items:
            c.setFont("Courier", 6)
            c.setFillColor(DARK_GRAY)
            c.drawString(col1_x + 0.15*cm, y, param)
            c.setFont("Helvetica", 6)
            c.setFillColor(GRAY)
            c.drawString(col1_x + 4.5*cm, y, desc)
            y -= 0.3*cm
        y -= 0.2*cm

    # Column 2: How it works
    y2 = height - 2.5*cm
    c.setFillColor(DARK_BLUE)
    c.setFont("Helvetica-Bold", 10)
    c.drawString(col2_x, y2, "AKO TO FUNGUJE")

    y2 -= 0.6*cm

    how_it_works = [
        ("1. SIGNAL + MTF", ORANGE, [
            "RSI(14) na H1 timeframe",
            "RSI < 35 = BUY (prepredane)",
            "RSI > 65 = SELL (prekupene)",
            "MTF: D1+H4+H1 trend filter",
        ]),
        ("2. GRID OTVORENIE", GREEN, [
            "Prvy obchod = Level 0",
            "Lot vypocitany podla balance",
            "Dynamic TP podla ATR",
            "Spread check pred otvorenim",
        ]),
        ("3. GRID ROZSIRENIE", BLUE, [
            "Cena ide proti nam o 25 pips",
            "Otvorime dalsiu poziciu",
            "Lot = predosly × 1.3",
            "Max 7 urovni (ochrana)",
        ]),
        ("4. OCHRANA POZICII", CYAN, [
            "Breakeven: +10 pips -> SL=entry+2",
            "Trailing: 50 pips, step 10",
            "Max $ strata (equity ochrana)",
            "Max spread blokuje obchody",
        ]),
        ("5. ZATVORENIE", PURPLE, [
            "Celkovy profit >= 0.8% balance",
            "ALEBO drawdown >= 15%",
            "ALEBO equity $ limit",
            "Zatvori VSETKY pozicie naraz",
        ]),
    ]

    for title, color, lines in how_it_works:
        c.setFillColor(color)
        c.setFont("Helvetica-Bold", 8)
        c.drawString(col2_x, y2, title)
        y2 -= 0.35*cm

        c.setFont("Helvetica", 7)
        c.setFillColor(black)
        for line in lines:
            c.drawString(col2_x + 0.2*cm, y2, "• " + line)
            y2 -= 0.3*cm
        y2 -= 0.2*cm

    # Bottom section: Grid example
    y = min(y, y2) - 1*cm

    c.setFillColor(DARK_GREEN)
    c.setFont("Helvetica-Bold", 12)
    c.drawString(1.5*cm, y, "PRIKLAD GRID PRIEBEHU")

    y -= 0.5*cm

    # Draw price chart representation
    chart_x = 1.5*cm
    chart_w = width - 3*cm
    chart_h = 4*cm

    c.setFillColor(LIGHT_GRAY)
    c.rect(chart_x, y - chart_h, chart_w, chart_h, fill=1, stroke=1)

    # Price line (going down then up)
    c.setStrokeColor(DARK_GRAY)
    c.setLineWidth(2)

    points = [
        (0, 0.8), (0.1, 0.75), (0.15, 0.65), (0.2, 0.55),
        (0.25, 0.45), (0.3, 0.35), (0.35, 0.3), (0.4, 0.35),
        (0.45, 0.45), (0.5, 0.55), (0.55, 0.65), (0.6, 0.75),
        (0.65, 0.85), (0.7, 0.9), (0.8, 0.85), (1.0, 0.8),
    ]

    path = c.beginPath()
    for i, (px, py) in enumerate(points):
        x = chart_x + px * chart_w
        yp = y - chart_h + py * chart_h
        if i == 0:
            path.moveTo(x, yp)
        else:
            path.lineTo(x, yp)
    c.drawPath(path, fill=0, stroke=1)

    # Grid levels
    grid_levels = [
        (0.1, 0.75, "L0", "0.08", GREEN),
        (0.2, 0.55, "L1", "0.10", GREEN),
        (0.3, 0.35, "L2", "0.13", ORANGE),
        (0.35, 0.3, "L3", "0.17", ORANGE),
    ]

    for px, py, level, lot, color in grid_levels:
        x = chart_x + px * chart_w
        yp = y - chart_h + py * chart_h
        c.setFillColor(color)
        c.circle(x, yp, 5, fill=1)
        c.setFont("Helvetica-Bold", 6)
        c.setFillColor(black)
        c.drawString(x + 7, yp - 2, f"{level}: {lot}")

    # TP marker
    tp_x = chart_x + 0.65 * chart_w
    tp_y = y - chart_h + 0.85 * chart_h
    c.setFillColor(PURPLE)
    c.circle(tp_x, tp_y, 8, fill=1)
    c.setFillColor(white)
    c.setFont("Helvetica-Bold", 7)
    c.drawCentredString(tp_x, tp_y - 2, "TP")

    c.setFillColor(PURPLE)
    c.setFont("Helvetica-Bold", 8)
    c.drawString(tp_x + 12, tp_y - 3, "CLOSE ALL! Profit: +$47")

    # Labels
    c.setFont("Helvetica", 7)
    c.setFillColor(GRAY)
    c.drawString(chart_x + 0.1*chart_w, y - chart_h - 0.4*cm, "RSI<35: BUY signal")
    c.drawString(chart_x + 0.3*chart_w, y - chart_h - 0.4*cm, "Cena pada, grid sa rozsiruje")
    c.drawString(chart_x + 0.6*chart_w, y - chart_h - 0.4*cm, "Cena stupa, profit rastie")

    # Footer
    c.setFillColor(GRAY)
    c.setFont("Helvetica", 8)
    c.drawString(1.5*cm, 1*cm, "Claude_Like_NoPain EA v4.30 | MTF + Trailing + Breakeven + Spread Filter | AUDCAD")
    c.drawRightString(width - 1.5*cm, 1*cm, "github.com/PeterPecho7/NoPainGrid-EA")

def create_pdf():
    """Main function to create the PDF documentation"""
    filename = "/Users/peterpecho/Desktop/Trading robot/Claude_Like_NoPain_Documentation.pdf"

    # Use A3 landscape for the mega diagram
    page_size = landscape(A3)
    c = canvas.Canvas(filename, pagesize=page_size)
    width, height = page_size

    # Page 1: Mega diagram
    create_mega_diagram(c, width, height)
    c.showPage()

    # Page 2: Details (A4)
    c.setPageSize(A4)
    width, height = A4
    create_page_2_detail(c, width, height)

    c.save()
    print(f"PDF created: {filename}")
    print(f"Page 1: A3 Landscape - Kompletny diagram")
    print(f"Page 2: A4 Portrait - Detailny popis")

if __name__ == "__main__":
    create_pdf()
