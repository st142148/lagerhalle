package voronoi

import "core:fmt"
import "core:math/rand"
import "core:math"
import "core:math/linalg"

gen_points_random :: proc(points : [dynamic]V_Point, min, max : int) {
    using rand
    for i in 0..<len(points) {
        points[i] = {{int_max(max), int_max(max)}, int_max(10), .SOIL, .TBD}
    }
}


gen_points_grid :: proc(points : ^[dynamic]V_Point, length, spacing, jitter : int) {
    using rand

    for x := 0; x < length - spacing * 2; x += spacing  {
        for y := 0; y < length - spacing * 2; y += spacing {
            append(points, V_Point{{x + (spacing / 2) + int(f32(spacing) * float32()), y + (spacing / 2) + int(f32(spacing) * float32())}, int(5.0 * float32()), .DEFAULT, .TBD})
        }
    }
}
