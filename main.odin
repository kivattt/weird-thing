package main

import "core:math"
import "core:c/libc"
import "core:strings"
import "core:sort"
import "core:time"
import "core:fmt"
import rl "vendor:raylib"
import rlgl "vendor:raylib/rlgl"

WIDTH :: 1280
HEIGHT :: 720

POINT_RADIUS :: 30.0

font: rl.Font
FONT_SIZE :: 40

Point :: struct {
	x: f32,
	y: f32,
}

Rect :: struct {
	x: f32,
	y: f32,
	w: f32,
	h: f32,
}

are_rectangles_overlapping :: proc(r1, r2: Rect) -> bool {
	r1 := r1
	r2 := r2
	if r1.w > r2.w {
		r1Copy := r1
		r1 = r2
		r2 = r1Copy
	}
	xOverlap := (r1.x >= r2.x && r1.x <= r2.x+r2.w) || (r1.x+r1.w >= r2.x && r1.x+r1.w <= r2.x+r2.w)
	yOverlap := (r1.y >= r2.y && r1.y <= r2.y+r2.h) || (r1.y+r1.h >= r2.y && r1.y+r1.h <= r2.y+r2.h)

	return xOverlap && yOverlap
}

draw_points :: proc(points: ^[dynamic]Point, selectedPointIndices: map[int]bool, selecting: bool) {
	for point, i in points {
		//color := rl.Color{0x61, 0xef, 0xff, 200}
		color := rl.Color{0x54, 0xa0, 0xa0, 200}
		if selecting && selectedPointIndices[i] {
			//color = {0x44, 0x44, 0xff, 255}
			color = {0x9d, 0xff, 0xff, 255}
		}
		rl.DrawCircle(i32(point.x), i32(point.y), POINT_RADIUS, color)
		rl.DrawTextEx(font, fmt.caprint(i), {point.x - 9, point.y - 18}, FONT_SIZE, 0, {0,0,0,255})
	}
}

PointAndLength :: struct {
	pointIndex: int,
	length: f32,
}

closest_points_sorted :: proc(points: ^[dynamic]Point, index: int) -> [dynamic]PointAndLength {
	if len(points) < 2 {
		panic("Less than two points")
	}

	pointX := points[index].x
	pointY := points[index].y

	out := make([dynamic]PointAndLength, len(points) - 1)
	j := 0
	for point, i in points {
		if i == index do continue

		out[j] = PointAndLength{
			pointIndex = i,
			length = math.hypot_f32(point.x - pointX, point.y - pointY),
		}
		j += 1
	}

	sort.quick_sort_proc(out[:], proc(a, b: PointAndLength) -> int {
		if a.length == b.length do return 0
		if a.length < b.length do return -1
		return 1
	})

	return out
}

draw_closest_points_text :: proc(points: ^[dynamic]Point, hoveredIndex: int) {
	if len(points) < 2 do return

	x: f32 = 0
	y: f32 = 100
	for _, i in points {
		closestPoints := closest_points_sorted(points, i)

		closestPointsStringBuilder := strings.builder_make()
		for e in closestPoints {
			strings.write_int(&closestPointsStringBuilder, e.pointIndex)
		}
		rl.DrawTextEx(font, fmt.caprint(i, " ", strings.to_string(closestPointsStringBuilder)), {x, y}, FONT_SIZE, 0, {255,255,255,255})
		y += 30

		delete(closestPoints)
	}
}

RGB :: struct {
	r, g, b: f32
}
hsv_to_rgb :: proc(h, s, v: f32) -> RGB {
	h := h

	if h > 360 {
		h = libc.fmod(h, 360)
	}

	hh, p, q, t, ff : f32
	i: i64

	out := RGB{0,0,0}

	if s <= 0.0 {
		out.r = v
		out.g = v
		out.b = v
		return out
	}

	hh = h
	if hh >= 360 do hh = 0.0
	hh /= 60
	i = i64(hh)
	ff = hh - f32(i)
	p = v * (1.0 - s)
	q = v * (1.0 - (s * ff))
	t = v * (1.0 - (s * (1.0 - ff)))

	switch i {
		case 0:
			out.r = v
			out.g = t
			out.b = p
		case 1:
			out.r = q
			out.g = v
			out.b = p
		case 2:
			out.r = p
			out.g = v
			out.b = t
		case 3:
			out.r = p
			out.g = q
			out.b = v
		case 4:
			out.r = t
			out.g = p
			out.b = v
		case:
			out.r = v
			out.g = p
			out.b = q
	}

	return out
}

draw_radius_circles :: proc(points: ^[dynamic]Point) {
	for a, i in points {
		for b, j in points {
			if j == i do continue

			radius := math.hypot_f32(a.x - b.x, a.y - b.y)
			hue := f32(i * 50 + 200)
			color := hsv_to_rgb(hue, 1.0, 1.0)
			color.r *= 255
			color.g *= 255
			color.b *= 255
			opacity: u8 = 100
			rl.DrawCircleLines(i32(a.x), i32(a.y), radius, {u8(color.r), u8(color.g), u8(color.b), opacity})
		}
	}
}

rect_from_start_end :: proc(start, end: rl.Vector2) -> Rect {
	minX := min(start.x, end.x)
	maxX := max(start.x, end.x)

	minY := min(start.y, end.y)
	maxY := max(start.y, end.y)

	return Rect{
		x = minX,
		y = minY,
		w = maxX - minX,
		h = maxY - minY,
	}
}

draw_selecting_area :: proc(start, end: rl.Vector2) {
	r := rect_from_start_end(start, end)
	rl.DrawRectangle(i32(r.x), i32(r.y), i32(r.w), i32(r.h), {0, 0xae, 255, 80})
}

main :: proc() {
	rl.SetConfigFlags({.WINDOW_RESIZABLE})
	rl.InitWindow(WIDTH, HEIGHT, "ui test")
	defer rl.CloseWindow()
	rl.SetTargetFPS(120)

	font = rl.LoadFontEx("JetBrainsMono-Regular.ttf", FONT_SIZE, nil, 0)

	points := make([dynamic]Point)
	pointsOld := make([dynamic]Point)

	leftClick := false
	lastClick := false
	lastPressTime: time.Time
	lastPressPosition: rl.Vector2

	selectingArea := false
	selectingAreaStart: rl.Vector2
	selectedArea := false
	selectedPointIndices := make(map[int]bool)

	selectedAreaMoveStartPos := [2]f32{-1, -1} // rl.Vector2
	selectedAreaBboxStartPos := Rect{}
	selectedAreaBbox := Rect{}

	rl.InitAudioDevice()
	hitmarker := rl.LoadSound("hitmarker.wav")

	selectedPointIndex := -1

	find_hovered_point :: proc(points: ^[dynamic]Point, x, y: f32) -> int {
		for point, i in points {
			distance := math.hypot_f32(point.x - x, point.y - y)
			if distance < POINT_RADIUS {
				return i
			}
		}

		return -1
	}

	for !rl.WindowShouldClose() {
		rl.ClearBackground({24,24,25,255})

		get_selected_area_bbox :: proc(points: [dynamic]Point, selectedPointIndices: map[int]bool) -> Rect {
			if len(points) == 0 || len(selectedPointIndices) == 0 {
				return Rect{}
			}

			// FIXME: Where is F32_MAX ???
			minX: f32 = 999999999
			minY: f32 = 999999999
			maxX: f32 = 0
			maxY: f32 = 0

			for index in selectedPointIndices {
				point := points[index]
				minX = min(minX, point.x - POINT_RADIUS - 5)
				minY = min(minY, point.y - POINT_RADIUS - 5)

				maxX = max(maxX, point.x + POINT_RADIUS + 5)
				maxY = max(maxY, point.y + POINT_RADIUS + 5)
			}

			return Rect{
				x = minX,
				y = minY,
				w = maxX - minX,
				h = maxY - minY,
			}
		}

		if !selectedArea {
			selectedAreaBbox = get_selected_area_bbox(points, selectedPointIndices)
		}

		mousePos := rl.GetMousePosition()
		mouseX := mousePos[0]
		mouseY := mousePos[1]

		leftClick = rl.IsMouseButtonDown(.LEFT)
		rightClick := rl.IsMouseButtonDown(.RIGHT)

		if selectedArea {
			mouseRect := Rect{
				mouseX,
				mouseY,
				1,
				1,
			}
			if !are_rectangles_overlapping(mouseRect, selectedAreaBbox) && (rightClick || (leftClick && !lastClick)) {
				// Cancelling selected area
				{
					selectedArea = false
					clear_map(&selectedPointIndices)
				}
				selectedAreaMoveStartPos = [2]f32{-1, -1} // Reset
			} else if leftClick {
				// Moving the selected area
				//if selectedAreaMoveStartPos == ([2]f32{-1, -1}) { // Compiler bug? Need parentheses surrounding right value
				if !lastClick { // Compiler bug? Need parentheses surrounding right value
					selectedAreaMoveStartPos = mousePos
					selectedAreaBboxStartPos = selectedAreaBbox

					resize(&pointsOld, len(points))
					copy_slice(pointsOld[:], points[:])
				}

				diffX := mousePos.x - selectedAreaMoveStartPos.x
				diffY := mousePos.y - selectedAreaMoveStartPos.y

				selectedAreaBbox.x = selectedAreaBboxStartPos.x + diffX
				selectedAreaBbox.y = selectedAreaBboxStartPos.y + diffY

				for index in selectedPointIndices {
					points[index].x = pointsOld[index].x + diffX
					points[index].y = pointsOld[index].y + diffY
				}
			} else if rl.IsKeyDown(.DELETE) {
				selectedPointIndicesSorted := make([dynamic]int)
				for index in selectedPointIndices {
					append(&selectedPointIndicesSorted, index)
				}

				// Remove in reverse order so we can remove in-place
				sort.quick_sort(selectedPointIndicesSorted[:])
				for i := len(selectedPointIndicesSorted) - 1; i >= 0; i -= 1 {
					index := selectedPointIndicesSorted[i]
					remove_range(&points, index, index+1)
				}

				clear(&pointsOld)

				// Cancelling selected area
				{
					selectedArea = false
					clear_map(&selectedPointIndices)
				}
				selectedAreaMoveStartPos = [2]f32{-1, -1} // Reset
			}
		} else {
			if rightClick {
				{
					selectedArea = false
					clear_map(&selectedPointIndices)
				}

				hovered := find_hovered_point(&points, mouseX, mouseY)
				if hovered != -1 {
					remove_range(&points, hovered, hovered+1)
				}
			} else if leftClick {
				{
					selectedArea = false
					clear_map(&selectedPointIndices)
				}

				if !lastClick && time.since(lastPressTime) < 300 * time.Millisecond {
					append(&points, Point{mouseX, mouseY})
					lastPressTime = time.unix(0, 0) // reset
					rl.PlaySound(hitmarker)
				} else if !lastClick {
					lastPressTime = time.now()
					lastPressPosition = mousePos

					if selectedPointIndex == -1 {
						selectedPointIndex = find_hovered_point(&points, mouseX, mouseY)
						if selectedPointIndex == -1 {
							selectingArea = true
							selectingAreaStart = mousePos
						}
					}
				} else {
					if selectedPointIndex != -1 {
						points[selectedPointIndex].x = mouseX
						points[selectedPointIndex].y = mouseY
					}
				}
			} else {
				selectedPointIndex = -1
			}
		}

		if !leftClick {
			selectingArea = false
			if len(selectedPointIndices) > 0 {
				selectedArea = true
			}
		}

		if selectingArea {
			set_selected_points :: proc(selectedPointIndices: ^map[int]bool, points: [dynamic]Point, start, end: rl.Vector2) {
				//clear_map(selectedPointIndices)

				for point, i in points {
					pointRect := Rect{
						x = point.x - POINT_RADIUS,
						y = point.y - POINT_RADIUS,
						w = 2 * POINT_RADIUS,
						h = 2 * POINT_RADIUS,
					}

					selectedRect := rect_from_start_end(start, end)

					if are_rectangles_overlapping(pointRect, selectedRect) {
						selectedPointIndices[i] = true
					}
				}
			}
			set_selected_points(&selectedPointIndices, points, selectingAreaStart, mousePos)
		}

		lastClick = leftClick

		draw_radius_circles(&points)
		draw_points(&points, selectedPointIndices, selectingArea)
		draw_closest_points_text(&points, selectedPointIndex)
		if selectingArea {
			draw_selecting_area(selectingAreaStart, mousePos)
		} else if selectedArea {
			draw_selected_area :: proc(bbox: Rect) {
				rl.DrawRectangleLines(i32(bbox.x), i32(bbox.y), i32(bbox.w), i32(bbox.h), {255,255,255,255})
				rl.DrawRectangle(i32(bbox.x), i32(bbox.y), i32(bbox.w), i32(bbox.h), {255,255,255,60})
			}
			draw_selected_area(selectedAreaBbox)
		}

		rl.DrawFPS(10, 10)

		rl.EndDrawing()
	}
}
