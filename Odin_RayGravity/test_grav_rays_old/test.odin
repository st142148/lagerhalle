package test

import "core:fmt"
import "./odin-stb/stbi"
import "./grav"


main :: proc(){
    ray_queue := make([dynamic]grav.Ray);
    defer delete(ray_queue);

    grav.gen_rays(&ray_queue);

    fBuffer := make([dynamic]u8, f32(grav.WIDTH*grav.HEIGHT*3), f32(grav.WIDTH*grav.HEIGHT*3));
    defer delete(fBuffer);

    grav.render(fBuffer, &ray_queue);

    stbi.write_png("fbuffer.png", grav.WIDTH, grav.HEIGHT, 3, 
                    fBuffer[0:grav.WIDTH*grav.HEIGHT*3], 3*grav.WIDTH);
}