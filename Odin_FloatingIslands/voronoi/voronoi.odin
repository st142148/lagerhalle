package voronoi

import rl "vendor:raylib"
import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:math/rand"
import "core:image"
import "core:image/png"

Type :: enum {
    DEFAULT,
    SOIL,
    ROCK,
}

Status :: enum {
    TBD,
    ISLAND,
    ABOVE,
    SIDECUT,
    FALLOFF,
}

V_Point :: struct {
    pos : [2]int,
    rad : int,
    type: Type,
    status : Status,
}

Landscape :: struct {
    heightmap : []int,
    mini, maxi, left, right, avg : int,

    circle_ctr       : [2]int,
    circle_ctr_rad   : f32,
    circle_ctr_rad_V : f32,
}

gen_voronoi :: proc(island : [][]u8, points : [dynamic]V_Point) {
    l := len(island)
    p_id := 255 / len(points)
    fmt.println(len(points))
    for x in 0..<l {
        for y in 0..<l {
            point := 0
            min_distance := len(island)+len(island[0])
            for i in 0..<len(points) {
                distance := calc_distance_manhattan([2]int{x, y}, points[i].pos) - points[i].rad
                //distance := calc_distance_euclidean([2]f32{f32(x), f32(y)-f32(abs(points[i].pos.x - x))*0.5}, [2]f32{f32(points[i].pos.x), f32(points[i].pos.y)}) - f32(points[i].rad)
/*                if i % 5 == 0 {
                    distance = int(calc_distance_sdf_box([2]f32{f32(points[i].pos.x - x), f32(points[i].pos.y - y)}, [2]f32{50.0, 30.0}))
                    distance = distance < 0 ? -1000 : 1000
                }
*/                if int(distance) <= min_distance {
                    point = i
                    min_distance = int(distance)
                } 
            }
            //fmt.println([2]int{x, y}, points[point].pos, point)
            island[x][y] = u8(point) //u8(f32(point) * f32(p_id))
        }
    }
}

cut_island_circle :: proc(landscape: ^Landscape, points: [dynamic]V_Point) {
    using landscape
    using math
    //CALC CIRCLE CENTER
    fmt.println("############")
    a := [2]int {left, heightmap[left]}
    b := [2]int {right, heightmap[right]}
    c := [2]int {right, a.y + (a.y - b.y)}

    //https://www.geeksforgeeks.org/minimum-enclosing-circle-set-1/
    bx  := b.x - a.x // == cx
    by  := b.y - a.y // == cy when pow
    cy  := c.y - a.y
    bbx := bx * bx
    bby := by * by
    BC  := bbx + bby
    D   := bx * cy - by * bx
    
    circle_ctr_rad = f32((cy - by) * BC) / f32(2 * D)
    circle_ctr_rad_V = (circle_ctr_rad + 0) * f32(max(heightmap[left], heightmap[right])) / f32(mini)
    circle_ctr = heightmap[left] > heightmap[right] ? {a.x + int(circle_ctr_rad), a.y} : {b.x - int(circle_ctr_rad), b.y}
    
    for p, i in points {
        if p.status == .TBD {
            distance := calc_distance_euclidean({f32(p.pos.x), f32(p.pos.y)}, {f32(circle_ctr.x), f32(circle_ctr.y)})
            rel := [2]f32{f32(p.pos.x) - f32(circle_ctr.x), f32(p.pos.y) - f32(circle_ctr.y)}
            distance = ( (rel.x * rel.x) / (circle_ctr_rad * circle_ctr_rad))  + ((rel.y * rel.y) / (circle_ctr_rad_V * circle_ctr_rad_V)) 

            points[i].status = distance < circle_ctr_rad ? .ISLAND : .FALLOFF
            points[i].status = distance <= 1.0 ? .ISLAND : .FALLOFF
        }
        if points[i].status != .ISLAND {
            points[i].rad = 3
        } else {
            points[i].rad = 10
        }
    }
}

start :: proc() {
    fmt.println("Voronoi")

    width : i32 = 600
    height : i32 = 600

    landscape : Landscape

    island := make([][]u8, width)
    defer delete(island)
    for i in 0..<len(island) {
        island[i] = make([]u8, height)
  //      defer delete(island[i])
    }
    points := make([dynamic]V_Point, 0, 400)//int(width / 10 * height / 10))
    defer delete(points)
    landscape.heightmap = make([]int, width)
    defer delete(landscape.heightmap)

    //gen_points_random(points, 0, int(width-1))
    gen_points_grid(&points, int(width), int(width) / 16, int(width) / 16)
    gen_points_grid(&points, int(width), int(width) / 8, int(width) / 8)
    gen_voronoi(island, points)

    //PARAMETER
    ground_thickness := 5
    ground_color := rl.Color{017, 124, 028, 255}

    draw_points := true

    bg_opacity : u8 = 100
    
        heightmap_change := false
        ground_drawing := false
        reload_texture := true

    rl.InitWindow(width, height, "voronoi island test")

    fmt.println("enairtn")
    voronoi_target := rl.GenImageColor(width, height, rl.BLUE)
    render_target := rl.LoadTextureFromImage(voronoi_target)//rl.LoadRenderTexture(width, height)

    rl.SetTargetFPS(60)

    for (!rl.WindowShouldClose()) {
        // INPUT
        if rl.IsKeyPressed(rl.KeyboardKey.R) {
            delete(points)
            points = make([dynamic]V_Point, 0, 100)//int(width / 20 * height / 20))
            //gen_points_random(points, 0, int(width - 1))
            gen_points_grid(&points, int(width), int(width) / 16, int(width) / 16)
            gen_points_grid(&points, int(width), int(width) / 8, int(width) / 8)
            gen_voronoi(island, points)
            reload_texture = true
            heightmap_change = true
        }
        if rl.IsMouseButtonDown(rl.MouseButton.LEFT) {
            if ground_drawing == false {
                for _, i in landscape.heightmap {
                    landscape.heightmap[i] = 0
                }
                ground_drawing = true
            }
            m_pos := rl.GetMousePosition()
            m_delta := rl.GetMouseDelta()
            y_delta := int(m_delta.y / m_delta.x)
            for i in 0..<int(m_delta.x) {
                if int(m_pos.x - m_delta.x) >= 0 && int(m_pos.x) < int(width) {
                    landscape.heightmap[int(m_pos.x) - i] = int(height) - int(m_pos.y) - y_delta
                }
            }
            //reload_texture = true
        } else if rl.IsMouseButtonReleased(rl.MouseButton.LEFT) {
            ground_drawing = false
            heightmap_change = true
            reload_texture = true
        }

        mw_delta := int(rl.GetMouseWheelMove())
        if mw_delta != 0 {
            fmt.println("INPUT MouseWheel: ", mw_delta)
            if mw_delta < 0 do mw_delta = -10
            else do mw_delta = 10

            for _, i in landscape.heightmap {
                if landscape.heightmap[i] > 0 do landscape.heightmap[i] = min(int(height - 1), max(0, landscape.heightmap[i] + mw_delta))
            }
            heightmap_change = true
            reload_texture = true
        }

        // REGEN ISLAND
        if heightmap_change {
            //rough cut
            for p, i in points {
                fmt.println(i, p)
                hm := landscape.heightmap[p.pos.x]
                if hm == 0 do points[i].status = .SIDECUT
                else if hm < p.pos.y do points[i].status = .ABOVE
                else do points[i].status = .TBD
            }
            //calc circle center
            using landscape
            mini = int(height)
            maxi = 0
            for p, i in heightmap {
                if p > 0 {
                    left = i
                    break
                }
            }
            sum := 0
            for i := left; i < len(heightmap); i += 1 {
                if heightmap[i] == 0 {
                    right = i - 1
                    break
                }
                if heightmap[i] < mini do mini = heightmap[i]
                if heightmap[i] > maxi do maxi = heightmap[i]
                sum += heightmap[i]
            }
            avg = sum / (right - left)

            fmt.println(mini, maxi, left, right, avg)
            cut_island_circle(&landscape, points)

            heightmap_change = false
        }

        // REDRAW
        if reload_texture {
            rl.ImageClearBackground(&voronoi_target, rl.BLUE)
            //Voronoi
            using landscape
            for x in 0..<len(island) {
                for y in 0..<len(island[0]) {
                    point := points[island[x][y]]
                    color : rl.Color = rl.BLUE
                    #partial switch point.status {
                        case .ISLAND:   {
                                            if y < heightmap[x] || point.pos.x < left || point.pos.x > right do color = rl.Color{island[x][y], 0, 0, 255}
                                            //else                do color = rl.Color{150, 150, island[x][y], 255}
                                        }
                        /*case .ABOVE:    {
                                            if y > heightmap[x] do color = rl.BLUE //color = rl.Color{150, 150, island[x][y], 255}
                                            else                do color = rl.Color{island[x][y], 0, 0, 255}
                                        }
                        case .SIDECUT:  color = rl.Color{100, 100, island[x][y], 255}
                        case .FALLOFF:  color = rl.Color{000, 050, island[x][y], 255}*/
                    }
                    rl.ImageDrawPixel(&voronoi_target, i32(x), i32(y), color)
                }
            }
            //Voronoi centers
            if draw_points {
                for p, i in points {
                    rl.ImageDrawCircle(&voronoi_target, i32(p.pos.x), i32(p.pos.y), i32(p.rad), rl.Color{56, 244, 238, 255})
                    rl.ImageDrawPixel(&voronoi_target, i32(p.pos.x), i32(p.pos.y), rl.Color{0, 0, 100, 255})
                }
            }
            //Heightmap
            for p, i in landscape.heightmap {
                if p > 0 {
                    if points[island[i][p]].status == .ISLAND || points[island[i][p]].status == .ABOVE { 
                        rl.ImageDrawCircle(&voronoi_target, i32(i), i32(p), i32(ground_thickness), ground_color)
                    }
                }
            }
            rl.ImageDrawCircle(&voronoi_target, i32(landscape.circle_ctr.x), i32(landscape.circle_ctr.y), i32(landscape.circle_ctr_rad), rl.WHITE)

            rl.UnloadTexture(render_target)
            render_target = rl.LoadTextureFromImage(voronoi_target)//rl.LoadRenderTexture(width, height)
            reload_texture = false
        }

        rl.BeginDrawing()
        rl.ClearBackground(rl.RAYWHITE)

        rl.DrawTextureRec(render_target, rl.Rectangle{0, 0, f32(render_target.width), f32(-render_target.height)}, rl.Vector2 {0, 0}, rl.WHITE)

        rl.DrawFPS(10, 10)
        rl.EndDrawing()
    }

    rl.CloseWindow()
}
