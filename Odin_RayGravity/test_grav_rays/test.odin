package test

import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:time"

//import "shared:flagparse"

import "./sdl"
import "./odin-stb/stbi"

import "./grav"

//option_mode     := flagparse.track_flag('m', "mode",    "mode selection",   0);
//option_output   := flagparse.track_flag('o', "output",  "output file",      "fbuffer.png");
//option_threads  := flagparse.track_flag('d', "threads", "number of threads",1);
//option_width    := flagparse.track_flag('x', "width",   "output width",     800);
//option_height   := flagparse.track_flag('y', "height",  "output height",    600);

simple_frame :: proc(){
    ray_queue := make([dynamic]grav.Ray);
    defer delete(ray_queue);

    grav.gen_rays(&ray_queue);

    fBuffer := make([dynamic]u8, grav.WIDTH*grav.HEIGHT*3, grav.WIDTH*grav.HEIGHT*3);
    defer delete(fBuffer);

    start := time.now();
    grav.render(fBuffer, &ray_queue);
    end := time.now();

    fmt.println("Render time: ", time.duration_seconds(time.diff(start, end)), " seconds");

    stbi.write_png("fbuffer.png", grav.WIDTH, grav.HEIGHT, 3, 
                    fBuffer[0:grav.WIDTH*grav.HEIGHT*3], 3*grav.WIDTH);
}

live :: proc(){
    sdl.init(sdl.Init_Flags.Everything);
    window := sdl.create_window("Grav test", i32(sdl.Window_Pos.Undefined), i32(sdl.Window_Pos.Undefined), i32(grav.WIDTH), i32(grav.HEIGHT), sdl.Window_Flags(0));
    renderer := sdl.create_renderer(window, -1, sdl.Renderer_Flags(0));

    fBuffer := make([dynamic]u8, grav.WIDTH*grav.HEIGHT*3, grav.WIDTH*grav.HEIGHT*3);

    ts := time.now();
    t := ts;
    to := t;

    running := true;
    for running {
        e: sdl.Event;
        for sdl.poll_event(&e) != 0 {
            if e.type == sdl.Event_Type.Quit {
                running = false;
            }
        }

        to = t;
        t = time.now();
        td := time.diff(to, t);
        fmt.println("Frame time: ", time.duration_seconds(td), " seconds");

        sdl.set_render_draw_color(renderer, 0, 0, 0, 255);
        sdl.render_clear(renderer);
        
        s := f32(time.duration_seconds(time.diff(ts, t)));
        grav.sing.pos = {math.sin(s), math.cos(s), -7.0};

        ray_queue := make([dynamic]grav.Ray);
        grav.gen_rays(&ray_queue);

        grav.render(fBuffer, &ray_queue);
        
        surface := sdl.create_rgb_surface_from(&fBuffer[0], i32(grav.WIDTH), i32(grav.HEIGHT), 24, i32(3*grav.WIDTH), 0, 0, 0, 0);
        texture := sdl.create_texture_from_surface(renderer, surface);
        sdl.free_surface(surface);

        pos := sdl.Rect{0, 0, i32(grav.WIDTH), i32(grav.HEIGHT)};
        sdl.render_copy(renderer, texture, nil, &pos);

        sdl.render_present(renderer);

        sdl.destroy_texture(texture);
        delete(ray_queue);
    }
    delete(fBuffer);
    sdl.quit();
}

main :: proc(){
    //flagparse.USAGE_STRING = "-m mode; -o output file; -t threads";
    //flagparse.ZERO_ARG_PRINT = true;
    //flagparse.parse_all_flags();


    grav.WIDTH = 400;//option_width^;
    grav.HEIGHT = 300;//option_height^;

    //switch option_mode^ {
        //case 0:
            simple_frame();
        //case 1:
            live();
    //}
}
