package test

import "core:fmt"
import "ply"
import "oct"
import sdl "vendor:sdl2"
import "ray"
import "core:time"
import "core:math"

//import "shared:flagparse"


//option_mode     := flagparse.track_flag('m', "mode",    "mode selection",   0);
//option_width    := flagparse.track_flag('x', "width",   "output width",     800);
//option_height   := flagparse.track_flag('y', "height",  "output height",    600);

main :: proc () {
    /*flagparse.parse_all_flags();

    //ray.WIDTH = option_width^;
    //ray.HEIGHT = option_height^;

    switch option_mode^ {
        case 0:
            live();
        case 1:
            alg_test();
    }

*/
    alg_test_occlusion();
    //live()
}

live :: proc(){
    pc := ply.load_pointcloud("assets/chalmers laser.ply");
    defer delete(pc.points);


    tree := oct.create_oct(pc, 12);
    defer oct.delete_oct(tree);


    sdl.Init(sdl.INIT_EVERYTHING);
    window := sdl.CreateWindow("ray test", i32(sdl.WINDOWPOS_UNDEFINED), i32(sdl.WINDOWPOS_UNDEFINED), i32(ray.WIDTH), i32(ray.HEIGHT), sdl.WindowFlags{});
    renderer := sdl.CreateRenderer(window, -1, sdl.RendererFlags{});

    fBuffer := make([dynamic]u8, ray.WIDTH*ray.HEIGHT*3, ray.WIDTH*ray.HEIGHT*3);

    ts := time.now();
    t := ts;
    to := t;

    lvl : byte = 0;

    running := true;
    for running {
        e: sdl.Event;
        for sdl.PollEvent(&e) != 0 {
            if e.type == sdl.EventType.QUIT {
                running = false;
            } else if e.type == sdl.EventType.KEYDOWN {
                using sdl.Scancode;
                #partial switch e.key.keysym.scancode {
                    case RIGHT: lvl += 1;
                                if lvl > tree.lvls do lvl = tree.lvls;
                                fmt.println(lvl);

                    case LEFT:  lvl -= 1;
                                if lvl == 255 do lvl = 0;
                                fmt.println(lvl);

                    case W:     ray.CAM_POS.z += 0.5;

                    case S:     ray.CAM_POS.z -= 0.5;

                    case A:     ray.CAM_POS.x -= 0.5;

                    case D:     ray.CAM_POS.x += 0.5;

                    case Q:     ray.CAM_POS.y += 0.5;

                    case E:     ray.CAM_POS.y -= 0.5;
                }
                fmt.println("CAM:   ", ray.CAM_POS);
            }
        }

        to = t;
        t = time.now();
        td := time.diff(to, t);
        fmt.println("Frame time: ", time.duration_seconds(td), " seconds");

        sdl.SetRenderDrawColor(renderer, 0, 0, 0, 255);
        sdl.RenderClear(renderer);
        
        s := f32(time.duration_seconds(time.diff(ts, t)));

        ray_queue := make([dynamic]ray.Ray);
        ray.gen_rays(&ray_queue);

        //ray.render(fBuffer, &ray_queue, tree, lvl);
        thread_pool : [ray.HEIGHT]^sdl.Thread;
        Thread_Data :: struct {
            fBuffer     : ^[dynamic]u8,
            ray_queue   : ^[dynamic]ray.Ray,
            tree        : ^oct.Oct,
            lvl         : byte,
            idx         : byte,
        };
        thd := Thread_Data{&fBuffer, &ray_queue, &tree, lvl, 0};
        thread_data : [ray.HEIGHT]Thread_Data;
        for i in 0..<ray.HEIGHT {
            thread_data[i] = thd;
            thd.idx += 1;

            thread_pool[i] = sdl.CreateThread(transmute(sdl.ThreadFunction)ray.render_threaded, "Ray Thread", &thread_data[i]);
        
        }
        for i in 0..<ray.HEIGHT {
            sdl.WaitThread(thread_pool[i], nil);
        }



        surface := sdl.CreateRGBSurfaceFrom(&fBuffer[0], i32(ray.WIDTH), i32(ray.HEIGHT), 24, i32(3*ray.WIDTH), 0, 0, 0, 0);
        texture := sdl.CreateTextureFromSurface(renderer, surface);
        sdl.FreeSurface(surface);

        pos := sdl.Rect{0, 0, i32(ray.WIDTH), i32(ray.HEIGHT)};
        sdl.RenderCopy(renderer, texture, nil, &pos);

        sdl.RenderPresent(renderer);

        sdl.DestroyTexture(texture);
        delete(ray_queue);
    }
    delete(fBuffer);
    sdl.Quit();
}

alg_test :: proc() {
    sdl.Init(sdl.INIT_EVERYTHING);
    window := sdl.CreateWindow("ray test", i32(sdl.WINDOWPOS_UNDEFINED), i32(sdl.WINDOWPOS_UNDEFINED), i32(ray.WIDTH), i32(ray.HEIGHT), sdl.WindowFlags{});
    renderer := sdl.CreateRenderer(window, -1, sdl.RendererFlags{});

    fBuffer := make([dynamic]u8, ray.WIDTH*ray.HEIGHT*3, ray.WIDTH*ray.HEIGHT*3);

    ts := time.now();
    t := ts;
    to := t;

    POS := [2]int{0, 0};
    Q_POS := [2]int{ray.WIDTH >> 1, ray.HEIGHT >> 1};
    R : int = ray.WIDTH >> 3;
    R2 : int = R >> 1;

    running := true;
    for running {
        skip := true;
        e: sdl.Event;
        for sdl.PollEvent(&e) != 0 {
            skip = false;
            if e.type == sdl.EventType.QUIT {
                running = false;
            } else if e.type == sdl.EventType.KEYDOWN {
                //using sdl.Scancode;
                #partial switch e.key.keysym.scancode {

                    case sdl.Scancode.W:     POS.y += 10;

                    case sdl.Scancode.S:     POS.y -= 10;

                    case sdl.Scancode.A:     POS.x -= 10;

                    case sdl.Scancode.D:     POS.x += 10;

                    case sdl.Scancode.RIGHT: R += 10;

                    case sdl.Scancode.LEFT:  R -= 10;

                    case sdl.Scancode.UP: R += 1;

                    case sdl.Scancode.DOWN:  R -= 1;
                }
                fmt.println("POS:   ", POS);
            }
        }
        if skip do continue;

        to = t;
        t = time.now();
        td := time.diff(to, t);
        //fmt.println("Frame time: ", time.duration_seconds(td), " seconds");

        sdl.SetRenderDrawColor(renderer, 0, 0, 0, 255);
        sdl.RenderClear(renderer);
        
        s := f32(time.duration_seconds(time.diff(ts, t)));

        for y in 0..<ray.HEIGHT {
            for x in 0..<ray.WIDTH {
                i : int = (ray.WIDTH * (ray.HEIGHT - y - 1) + x) * 3;
                if x == POS.x && y == POS.y {
                    fBuffer[i] = 255;
                    fBuffer[i+1] = 0;
                    fBuffer[i+2] = 0;
                    continue;
                } else if x <= Q_POS.x + R && x >= Q_POS.x - R && y <= Q_POS.y + R2 && y >= Q_POS.y - R2 {
                    fBuffer[i] = 0;
                    fBuffer[i+1] = 0;
                    fBuffer[i+2] = 100;
                    continue;
                }

                r : u8 = 100;
                g : u8 = 0;
                b : u8 = 0;

                sx := (x - POS.x);
                sy := (y - POS.y);
                qx, qy : int;
                qx = Q_POS.x - POS.x;
                qy = Q_POS.y - POS.y;
                
                if sx < 0 {
                    qx = -qx;
                    sx = -sx;
                    //g = 255;
                } 
                if sy < 0 {
                    qy = -qy;
                    sy = -sy;
                    //b = 255;
                }

                if !(oct.cross_abs(sx, sy, qx, qy) < (R2 * (sx) + R * (sy)) && ((qx) > -R) && ((qy) > -R2)) {
                    fBuffer[i] = r;
                    fBuffer[i+1] = g;
                    fBuffer[i+2] = b;
                    continue;
                }
                fBuffer[i] = 255;
                fBuffer[i+1] = 255;
                fBuffer[i+2] = 255;
            }
        }


        surface := sdl.CreateRGBSurfaceFrom(&fBuffer[0], i32(ray.WIDTH), i32(ray.HEIGHT), 24, i32(3*ray.WIDTH), 0, 0, 0, 0);
        texture := sdl.CreateTextureFromSurface(renderer, surface);
        sdl.FreeSurface(surface);

        pos := sdl.Rect{0, 0, i32(ray.WIDTH), i32(ray.HEIGHT)};
        sdl.RenderCopy(renderer, texture, nil, &pos);

        sdl.RenderPresent(renderer);

        sdl.DestroyTexture(texture);
    }
    delete(fBuffer);
    sdl.Quit();
}


alg_test_occlusion :: proc() {
    sdl.Init(sdl.INIT_EVERYTHING);
    window := sdl.CreateWindow("ray test", i32(sdl.WINDOWPOS_UNDEFINED), i32(sdl.WINDOWPOS_UNDEFINED), i32(ray.WIDTH), i32(ray.HEIGHT), sdl.WindowFlags{});
    renderer := sdl.CreateRenderer(window, -1, sdl.RendererFlags{});

    fBuffer := make([dynamic]u8, ray.WIDTH*ray.HEIGHT*3, ray.WIDTH*ray.HEIGHT*3);

    ts := time.now();
    t := ts;
    to := t;

    //CAM
    POS := [2]int{ray.WIDTH >> 2, ray.HEIGHT >> 2};
    Q_POS := [2]int{ray.WIDTH >> 2, (ray.HEIGHT >> 2) * 3 - 50};
    R : int = 10;
    R2 : int = 10; //R >> 1;

    


    running := true;
    for running {
        skip := true;
        e: sdl.Event;
        for sdl.PollEvent(&e) != 0 {
            skip = false;
            if e.type == sdl.EventType.QUIT {
                running = false;
            } else if e.type == sdl.EventType.KEYDOWN {
                //using sdl.Scancode;
                #partial switch e.key.keysym.scancode {

                    case sdl.Scancode.W:     POS.y += 10;

                    case sdl.Scancode.S:     POS.y -= 10;

                    case sdl.Scancode.A:     POS.x -= 10; //Q_POS.x -= 10;

                    case sdl.Scancode.D:     POS.x += 10; //Q_POS.x += 10;

                    case sdl.Scancode.RIGHT: Q_POS.x += 10;//R += 10;

                    case sdl.Scancode.LEFT:  Q_POS.x -= 10//R -= 10;

                    case sdl.Scancode.UP:    Q_POS.y += 10;//R += 1;

                    case sdl.Scancode.DOWN:  Q_POS.y -= 10;//R -= 1;
                }
                //fmt.println("POS:   ", POS);
            }
        }
        if skip do continue;

        to = t;
        t = time.now();
        td := time.diff(to, t);
        //fmt.println("Frame time: ", time.duration_seconds(td), " seconds");

        sdl.SetRenderDrawColor(renderer, 0, 0, 0, 255);
        sdl.RenderClear(renderer);
        
        s := f32(time.duration_seconds(time.diff(ts, t)));

        texel :: struct {
            pos : [2]int,
            color : [3]u8,
            r : int,
        };

        texels : [3]texel = {
            {
                {ray.WIDTH >> 2, (ray.HEIGHT >> 2) * 3},
                {250, 0, 0},
                50,
            },
            {
                {(ray.WIDTH >> 2) * 2, (ray.HEIGHT >> 2) * 3 + 50},
                {0, 250, 0},
                10,
            },
            {
                {(ray.WIDTH >> 2) * 3, (ray.HEIGHT >> 2) * 3},
                {0, 0, 250},
                50,
            },
        };

        for y in 0..<ray.HEIGHT {
            for x in 0..<ray.WIDTH {
                i : int = (ray.WIDTH * (ray.HEIGHT - y - 1) + x) * 3;
                if x == POS.x && y == POS.y {
                    fBuffer[i] = 255;
                    fBuffer[i+1] = 0;
                    fBuffer[i+2] = 0;
                    continue;
                } else if x <= Q_POS.x + R && x >= Q_POS.x - R && y <= Q_POS.y + R2 && y >= Q_POS.y - R2 {
                    if f32(R*R) > math.pow(f32(x - Q_POS.x), 2) + math.pow(f32(y - Q_POS.y), 2){
                    fBuffer[i] = 0;
                    fBuffer[i+1] = 0;
                    fBuffer[i+2] = 100;
                    continue;
                    }
                }

                r : u8 = 100;
                g : u8 = 100;
                b : u8 = 100;

                sx := (x - POS.x);
                sy := (y - POS.y);
                qx, qy : int;
                qx = Q_POS.x - POS.x;
                qy = Q_POS.y - POS.y;
                
                if sx < 0 {
                    qx = -qx;
                    sx = -sx;
                    //g = 255;
                } 
                if sy < 0 {
                    qy = -qy;
                    sy = -sy;
                    //b = 255;
                }

                if !(oct.cross_abs(sx, sy, qx, qy)  < (R2 * (sx) + R * (sy)) && ((qx) > -R) && ((qy) > -R2)) {
                    fBuffer[i]   = b;
                    fBuffer[i+1] = g;
                    fBuffer[i+2] = r;
                    continue;
                }
                if (oct.cross_abs(sx, sy, qx, qy) <= 100 && ((qy) > -R2)) {
                    fBuffer[i]   = 0;
                    fBuffer[i+1] = 0;
                    fBuffer[i+2] = 0;
                    continue;
                }
                fBuffer[i] = 255;
                fBuffer[i+1] = 255;
                fBuffer[i+2] = 255;
            }
        }

        for texel in texels {
            for y in texel.pos.y - texel.r ..< texel.pos.y + texel.r {
                for x in texel.pos.x - texel.r ..< texel.pos.x + texel.r {
                    i : int = (ray.WIDTH * (ray.HEIGHT - y - 1) + x) * 3;
                    fBuffer[i]   = texel.color.x;
                    fBuffer[i+1] = texel.color.y;
                    fBuffer[i+2] = texel.color.z;
                }
            }
        }

        tex_sorted : [3]texel;
        if sum2(texels[0].pos - POS) <= sum2(texels[1].pos - POS) && sum2(texels[0].pos - POS) <= sum2(texels[2].pos - POS) {
            tex_sorted[0] = texels[0];
            if sum2(texels[1].pos - POS) <= sum2(texels[2].pos - POS) {
                tex_sorted[1] = texels[1];
                tex_sorted[2] = texels[2];
            } else {
                tex_sorted[1] = texels[2];
                tex_sorted[2] = texels[1];
            }
        } else if sum2(texels[1].pos - POS) <= sum2(texels[2].pos - POS) {
            tex_sorted[0] = texels[1]
            if sum2(texels[0].pos - POS) <= sum2(texels[2].pos - POS) {
                tex_sorted[1] = texels[0];
                tex_sorted[2] = texels[2];
            } else {
                tex_sorted[1] = texels[2];
                tex_sorted[2] = texels[0];
            }
        } else {
            tex_sorted[0] = texels[2];
            if sum2(texels[0].pos - POS) <= sum2(texels[1].pos - POS) {
                tex_sorted[1] = texels[0];
                tex_sorted[2] = texels[1];
            } else {
                tex_sorted[1] = texels[1];
                tex_sorted[2] = texels[0];
            }
        }

        color_blend : [3]u8;
        line_segment_mask := [100]u8{1, 1, 1, 1, 1, 1, 1, 1, 1, 1,1, 1, 1, 1, 1, 1, 1, 1, 1, 1,1, 1, 1, 1, 1, 1, 1, 1, 1, 1,1, 1, 1, 1, 1, 1, 1, 1, 1, 1,1, 1, 1, 1, 1, 1, 1, 1, 1, 1,1, 1, 1, 1, 1, 1, 1, 1, 1, 1,1, 1, 1, 1, 1, 1, 1, 1, 1, 1,1, 1, 1, 1, 1, 1, 1, 1, 1, 1,1, 1, 1, 1, 1, 1, 1, 1, 1, 1,1, 1, 1, 1, 1, 1, 1, 1, 1, 1,};
        line_segment : [100][3]u8;

        for texel in tex_sorted {
            sx := Q_POS.x - POS.x;
            sy := Q_POS.y - POS.y;
            qx := texel.pos.x - POS.x;
            qy := texel.pos.y - POS.y;
            if sx < 0 {
                qx = -qx;
                sx = -sx;
                //g = 255;
            } 
            if sy < 0 {
                qy = -qy;
                sy = -sy;
                //b = 255;
            }
            cross := oct.cross(sx, sy, qx, qy);
            w1 := ((texel.r) * (sx) + (texel.r) * (sy));
            w2 := ((R2) * (sx) + (R) * (sy)) * (abs(qx)+abs(qy))/(sx+sy);
            //w2 := int(math.sqrt(math.pow(f32(R2 * sx),2) + math.pow(f32(R * sy), 2)) * f32((abs(qx)+abs(qy))/(sx+sy)))
            //behind occlusion: && ((qx) > -R) && ((qy) > -R2);

            min_t := cross - w1;
            max_t := cross + w1;
            min_v := -w2;
            max_v := w2;

            mi := max(min_t, min_v);
            max := min(max_t, max_v);
            diff := max - mi;

            fmt.println(cross)

            //line segment
            if cross <= w1 + w2 && (qx > -(texel.r + R)) && (qy > -(texel.r + R2)){
                step := w2 * 2 / len(line_segment);
                mi += w2;
                max += w2;
                for l in 0..<len(line_segment) {
                    ls := l * step;
                    //fmt.println(mi, max, l, ls);
                    if ls >= mi && ls <= max {
                        line_segment[l] += line_segment_mask[l] * texel.color;
                        line_segment_mask[l] = 0;
                    }
                }
            }

            alpha : f32 = f32(diff)/f32(w2*2);
            //alpha : f32 = f32(w1+w2-cross)/ f32(w1+w2);
            //alpha : f32 = min(1.0, f32(f32(w2) - (f32(cross) - f32(w1)))/f32(w2));
            alpha_blend : [3]u8 = {
                u8(f32(texel.color.r) * alpha),
                u8(f32(texel.color.g) * alpha),
                u8(f32(texel.color.b) * alpha),
            };
            //if cross <= w1 + w2 && (qx > -(texel.r + R)) && (qy > -(texel.r + R2)) do color_blend += alpha_blend;
/*
            fmt.println("Texel: ", texel.color);
            fmt.println("cross: ", cross);
            fmt.println("w1:    ", w1);
            fmt.println("w2:    ", w2);
            fmt.println("%:     ", alpha);
*/
            fmt.println("################");
        }
        //fmt.println(color_blend);
        //fmt.println(line_segment);
        fmt.println("################");

        for i in 0..<len(line_segment){
            color_blend += line_segment[i] / len(line_segment);
        }

        for y in 0..< ray.HEIGHT>>2 {
            ls := f32(ray.WIDTH) / f32(len(line_segment));
            if y < ray.HEIGHT>>3 {
                for x in 0..<ray.WIDTH {
                    seg := int(f32(x) / ls);
                    i : int = (ray.WIDTH * (ray.HEIGHT - y - 1) + x) * 3;
                    fBuffer[i]   = color_blend[0];
                    fBuffer[i+1] = color_blend[1];
                    fBuffer[i+2] = color_blend[2];
                }                
            } else {
                for x in 0..<ray.WIDTH {
                    seg := int(f32(x) / ls);
                    i : int = (ray.WIDTH * (ray.HEIGHT - y - 1) + x) * 3;
                    fBuffer[i]   = line_segment[seg][0];
                    fBuffer[i+1] = line_segment[seg][1];
                    fBuffer[i+2] = line_segment[seg][2];
                }
            }
            
        }

        surface := sdl.CreateRGBSurfaceFrom(&fBuffer[0], i32(ray.WIDTH), i32(ray.HEIGHT), 24, i32(3*ray.WIDTH), 0, 0, 0, 0);
        texture := sdl.CreateTextureFromSurface(renderer, surface);
        sdl.FreeSurface(surface);

        pos := sdl.Rect{0, 0, i32(ray.WIDTH), i32(ray.HEIGHT)};
        sdl.RenderCopy(renderer, texture, nil, &pos);

        sdl.RenderPresent(renderer);

        sdl.DestroyTexture(texture);
    }
    delete(fBuffer);
    sdl.Quit();
}

sum2 :: proc (a : [2]int) -> int {
    return abs(a.x) + abs(a.y)
}
