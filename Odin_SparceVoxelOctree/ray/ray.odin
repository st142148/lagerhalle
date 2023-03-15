package ray

import "core:fmt"
import "core:math/linalg"
import "core:math"
import "core:mem"

import "../oct"

Vec3 :: linalg.Vector3f32;
RGB :: [3]u8;

WIDTH :: 500;
HEIGHT :: 500;

CAM_POS := Vec3{3.5, 3.0, 1.5};

Ray :: struct {
    pos : Vec3,
    dir : Vec3,
    pxl : [2]int,
    contr : f32,
}

Plane :: struct {
    pos : Vec3,
    normal : Vec3,
    clr : RGB,
}

gen_rays :: proc(ray_queue: ^[dynamic]Ray) {
    u : Vec3 = {1, 0, 0};
    v : Vec3 = {0, 1, 0};
    up : Vec3 = {0, 1, 0};
    w : Vec3 = {0, 0, -1};

    d : f32 = 4.0;
    l : f32 = -2.0;
    r : f32 = 2.0;
    t : f32 = 2.0;
    b : f32 = -2.0;

    step_v := (r-l)/f32(WIDTH);
    step_h := (t-b)/f32(HEIGHT);

    for y in 0..<HEIGHT {
        for x in 0..<WIDTH {
            append(ray_queue, Ray{CAM_POS, linalg.normalize(Vec3{d, l+step_v*f32(x), t-step_h*f32(y)}), {x, y}, 1.0});
        }
    }
}

remove_excess_rays :: proc(ray_queue: ^[dynamic]Ray){

}


render :: proc(fBuffer : [dynamic]u8, ray_queue: ^[dynamic]Ray, tree : ^oct.Oct, lvl : byte) {
    index := 0;

    ray : Ray;

    ray_dir_forward : bool = true;

    for index < len(ray_queue) {
        ray = ray_queue[index];
        index += 1;
        i : int = (WIDTH * ray.pxl[1] + ray.pxl[0]) * 3;

        ok, clr, t := oct.traverse(tree, lvl, ray.pos, ray.pos + ray.dir);

        if ok {
            fBuffer[i] = u8(clr.x);
            fBuffer[i+1] = u8(clr.y);
            fBuffer[i+2] = u8(clr.z);
        } else {
            fBuffer[i] = 10;
            fBuffer[i+1] = 0;
            fBuffer[i+2] = 20;
        }
    }
}

render_threaded :: proc "c" (thread_data : ^rawptr) -> i32 {

    Thread_Data :: struct {
        fBuffer     : ^[dynamic]u8,
        ray_queue   : ^[dynamic]Ray,
        tree        : ^oct.Oct,
        lvl         : byte,
        idx         : byte,
    };

    td := transmute(^Thread_Data)thread_data;

    //index := 0;

    ray : Ray;

    ray_dir_forward : bool = true;

    for index in int(td.idx)  * WIDTH ..< (int(td.idx) + 1)  * WIDTH {
        ray = td.ray_queue[index];
        //index += 1;
        i : int = (WIDTH * ray.pxl[1] + ray.pxl[0]) * 3;

        ok, clr, t := oct.traverse(td.tree, td.lvl, ray.pos, ray.pos + ray.dir);

        if ok {
            /*
            tclr : u8 = 255 - u8(((t > 5.0 ? 5.0 : t) < 0.0 ? 0.0 : t) / 5.0 * 255.0);
            td.fBuffer[i] = u8(tclr);
            td.fBuffer[i+1] = u8(tclr);
            td.fBuffer[i+2] = u8(tclr);
            */
            td.fBuffer[i] = u8(clr.z);
            td.fBuffer[i+1] = u8(clr.y);
            td.fBuffer[i+2] = u8(clr.x);
            
        } else {
            td.fBuffer[i] = 10;
            td.fBuffer[i+1] = 0;
            td.fBuffer[i+2] = 20;
        }
    }
    return 0;
}
