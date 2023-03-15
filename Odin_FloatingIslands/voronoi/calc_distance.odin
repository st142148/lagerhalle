package voronoi

import "core:math/rand"
import "core:math"
import "core:math/linalg"

calc_distance_manhattan :: #force_inline proc (a,b : [2]int) -> int {
    return abs(a.x - b.x) + abs(a.y - b.y)
}

calc_distance_euclidean :: #force_inline proc (a,b : [2]f32) -> f32 {
    return math.sqrt(math.pow(a.x - b.x, 2) + math.pow(a.y - b.y, 2))
} 

calc_distance_sdf_box :: #force_inline proc (p, b: [2]f32) -> f32 {
    d := [2]f32{abs(p.x), abs(p.y)} - b
    return linalg.length([2]f32{max(d.x, 0.0), max(d.y, 0.0)}) + min(max(d.x, d.y), 0.0)
}
