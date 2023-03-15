package grav

import "core:fmt"
import "core:math/linalg"
import "core:math"

Vec3 :: linalg.Vector3;
RGB :: [3]u8;

WIDTH :: 1000;
HEIGHT :: 1000;

Ray :: struct {
    pos : Vec3,
    dir : Vec3,
    pxl : [2]int,
    contr : f32,
}

RayCache :: struct {
    Old : Ray,
    Int : Vec3,
    Angle : f32,
    New : Ray,
}

Singularity :: struct {
    pos : Vec3,
    rad : f32,
    clr : RGB,
}

Plane :: struct {
    pos : Vec3,
    normal : Vec3,
    clr : RGB,
}

// https://stackoverflow.com/a/3380723
acos :: proc(x: f32) -> f32 {
    return (-0.69813170079773212 * x * x - 0.87266462599716477) * x + 1.5707963267948966;
}

// https://developer.download.nvidia.com/cg/acos.html
acos_nv :: proc(x0: f32) -> f32 {
  negate : f32 = x0 < 0 ? 1.0 : 0.0;
  x := abs(x0);
  ret : f32 = -0.0187293;
  ret = ret * x;
  ret = ret + 0.0742610;
  ret = ret * x;
  ret = ret - 0.2121144;
  ret = ret * x;
  ret = ret + 1.5707288;
  ret = ret * math.sqrt(1.0-x);
  ret = ret - 2 * negate * ret;
  return negate * 3.14159265358979 + ret;
}

// https://stackoverflow.com/a/36387954
acos_ruud :: proc(x: f32) -> f32 {
    return math.PI/2 + (-0.939115566365855 * x + 0.9217841528914573 * x * x * x) / (1 + -1.2845906244690837 * x * x + 0.295624144969963174 * x * x * x * x);
}

gen_rays :: proc(ray_queue: ^[dynamic]Ray) {
    u : Vec3 = {1, 0, 0};
    v : Vec3 = {0, 1, 0};
    up : Vec3 = {0, 1, 0};
    w : Vec3 = {0, 0, -1};

    d : f32 = 2.0;
    l : f32 = -1.0;
    r : f32 = 1.0;
    t : f32 = 1.0;
    b : f32 = -1.0;

    for y in 0..HEIGHT-1 {
        for x in 0..WIDTH-1 {
            append(ray_queue, Ray{{0.0, 0.0, -10.0}, linalg.normalize(Vec3{l+(r-l)/f32(WIDTH)*f32(x), t-(t-b)/f32(HEIGHT)*f32(y), d}), {x, y}, 1.0});
        }
    }
}


render :: proc(fBuffer : [dynamic]u8, ray_queue: ^[dynamic]Ray) {
    index := 0;
    sing := Singularity{{0.5, 0.0, -7.0}, 0.75, {0, 0, 20}};
    plane := Plane{{0.0, 0.0, 5.0}, linalg.normalize(Vec3{0.0, 0.0, 1.0}), {0, 200, 0}};
    back_plane := Plane{{0.0, 0.0, -15.0}, linalg.normalize(Vec3{0.0, 0.0, -1.0}), {200, 0, 0}};
    right_plane := Plane{{5.0, 0.0, 0.0}, linalg.normalize(Vec3{1.0, 0.0, 0.0}), {150, 150, 0}};
    left_plane := Plane{{-5.0, 0.0, 0.0}, linalg.normalize(Vec3{-1.0, 0.0, 0.0}), {150, 0, 150}};
    top_plane := Plane{{0.0, 5.0, 0.0}, linalg.normalize(Vec3{0.0, 1.0, 0.0}), {0, 150, 150}};
    bottom_plane := Plane{{0.0, -5.0, 0.0}, linalg.normalize(Vec3{0.0, -1.0, 0.0}), {200, 200, 200}};
    ray : Ray;

    ray_cache : RayCache;
    ray_dir_forward : bool = true;

    for index < len(ray_queue) {
        //fmt.println("Rays: ", len(ray_queue));
        //fmt.println("Index: ", index, "\n");
        ray = ray_queue[index];
        index += 1;
        i : int = (WIDTH * ray.pxl[1] + ray.pxl[0]) * 3;

        if index < WIDTH*HEIGHT+1 {

            t0, t1 : f32;
            ok := false;
            l := ray.pos - sing.pos;
            a := linalg.dot(ray.dir, ray.dir);
            b := 2.0 * linalg.dot(ray.dir, l);
            c := linalg.dot(l, l) - sing.rad * sing.rad;

            discr := b * b - 4.0 * a * c;
            if discr < 0.0 {}
            else if discr == 0.0 {
                t0 = -0.5 * b / a;
                t1 = t0;
            } else {
                q : f32;
                if b > 0.0 do q = -0.5 * (b - math.sqrt(discr));
                else do q = -0.5 * (b + math.sqrt(discr));
                t0 = q / a;
                t1 = c / q;
            }

            if t0 > 0.0 {
                ok = true;
            } else if t0 < 0.0 {
                if t1 >= 0.0 {
                    t0 = t1;
                    ok = true;
                }
            }

            if ok {
                intersection := ray.pos + t0 * ray.dir;
                //theta := linalg.dot(ray.dir, linalg.normalize(sing.pos - intersection));// /linalg.length(ray.dir)*linalg.length(sing.pos - intersection);
                //theta = math.to_degrees(acos_nv(theta));

                theta := (linalg.dot(ray.dir, sing.pos-intersection))/(linalg.length(ray.dir)*linalg.length(sing.pos-intersection));
                theta = math.to_degrees(acos_nv(theta));

                //fBuffer[i] = u8(theta);

                if theta < 0.0 {
                    fBuffer[i] = sing.clr[0];
                    fBuffer[i+1] = sing.clr[1];
                    fBuffer[i+2] = sing.clr[2];
                    continue;
                } else {
                    axis := linalg.normalize(linalg.cross(ray.dir, sing.pos - intersection));

                    theta_dir : f32 = math.pow((90.0 - theta), 2) / 8100.0 * 180.0;
                    theta_pos : f32 = math.pow((90.0 - theta), 2) / 8100.0 * 360.0;
                    //theta_dir : f32 = 180.0 - (1 - (theta * theta * theta / 729000.0) * 180.0);
                    //theta_pos : f32 = 360.0 - (1 - (theta * theta * theta / 729000.0) * 360.0);
                    theta_dir = math.to_radians(theta_dir);
                    //theta_pos = math.to_radians(theta_dir);
                    quat_dir : linalg.Quaternion = linalg.quaternion_angle_axis(math.to_radians(theta_dir), axis);
                    //new_dir := linalg.mul(quat_dir, ray.dir);
                    new_dir := (math.cos(theta_dir)*ray.dir) + (math.sin(theta_dir) * linalg.cross(axis, ray.dir)) + ((1 - math.cos(theta_dir))*(linalg.dot(axis, ray.dir)*axis));
                    
                    quat_pos : linalg.Quaternion = linalg.quaternion_angle_axis(math.to_radians(theta_pos), axis);

                    new_pos := intersection - sing.pos;
                    new_pos = linalg.mul(quat_pos, new_pos);
                    //new_pos = new_pos * math.cos(theta_pos) + (linalg.cross(axis, new_pos) * math.sin(theta_pos) + axis * (linalg.dot(axis, new_pos) * (1.0 - math.cos(theta_pos))));
                    new_pos = new_pos + sing.pos + 0.001 * new_dir;

                    fBuffer[i] = u8(abs(new_dir.x + 1.0) * 100.0);
                    fBuffer[i+1] = u8(abs(new_dir.y + 1.0) * 100.0);
                    fBuffer[i+2] = u8(abs(new_dir.z + 1.0) * 100.0);

                    /*if ray_cache.New.dir.z * new_dir.z < 0.0 {
                        fmt.println("-----------------------------------------");
                        fmt.println(ray.pxl);
                        fmt.println(ray_cache);
                        ray_cache = RayCache{ray, intersection, theta, Ray{new_pos, new_dir, ray.pxl, ray.contr}};
                        fmt.println("\n", ray_cache);
                    }*/

                    ray_cache = RayCache{ray, intersection, theta, Ray{new_pos, new_dir, ray.pxl, ray.contr}};
                    append(ray_queue, Ray{new_pos, new_dir, ray.pxl, ray.contr});
                    /*if ray.pxl[1] == 200 && ray.pxl[0] == 270 {
                        //fmt.printf("%f ", theta_dir);
                        //fmt.println(ray);
                        //fmt.println("intersection: ",intersection, "axis: ", axis);
                        //fmt.println("theta: ", theta, "theta_pos: ", theta_pos, "theta_dir: ", theta_dir);
                        //fmt.println(Ray{new_pos, new_dir, ray.pxl, ray.contr}, "\n");
                        //break;
                    }*/
                    continue;
                }
            }
        }

        t: f32 = 100.0;
        denom := linalg.dot(plane.normal, ray.dir);
        if denom > math.F32_EPSILON {
            distance := ray.pos - plane.pos;
            t0 := linalg.dot(distance, plane.normal) / -denom;
        
            if t0 >= 0.0 {
                t = t0;
                intersection := ray.pos + ray.dir * t;
                chess : bool = 0 <= (math.sin(intersection[0]*4) * math.sin(intersection[1]*4)) ? true : false;
                rad := math.sqrt(intersection[0]*intersection[0]+intersection[1]*intersection[1]);
                _, fract := math.modf(t);
                if chess {
                    fBuffer[i] = u8(f32(plane.clr[0]));
                    fBuffer[i+1] = u8(f32(plane.clr[1]));
                    fBuffer[i+2] = u8(f32(plane.clr[2]));
                }else {
                    fBuffer[i] = u8(f32(plane.clr[0]) * 0.5);
                    fBuffer[i+1] = u8(f32(plane.clr[1]) * 0.5);
                    fBuffer[i+2] = u8(f32(plane.clr[2]) * 0.5);
                }
            }
        }

        denom = linalg.dot(back_plane.normal, ray.dir);
        if denom > math.F32_EPSILON {
            distance := ray.pos - back_plane.pos;
            t0 := linalg.dot(distance, back_plane.normal) / -denom;
        
            if t0 >= 0.0 && t0 < t {
                t = t0;
                intersection := ray.pos + ray.dir * t;
                chess : bool = 0 <= (math.sin(intersection[0]*2) * math.sin(intersection[1]*2)) ? true : false;
                rad := math.sqrt(intersection[0]*intersection[0]+intersection[1]*intersection[1]);
                _, fract := math.modf(t);
                if chess {
                    fBuffer[i] = u8(f32(back_plane.clr[0]));
                    fBuffer[i+1] = u8(f32(back_plane.clr[1]));
                    fBuffer[i+2] = u8(f32(back_plane.clr[2]));
                }else {
                    fBuffer[i] = u8(f32(back_plane.clr[0]) * 0.5);
                    fBuffer[i+1] = u8(f32(back_plane.clr[1]) * 0.5);
                    fBuffer[i+2] = u8(f32(back_plane.clr[2]) * 0.5);
                }
            }
        }
        denom = linalg.dot(right_plane.normal, ray.dir);
        if denom > math.F32_EPSILON {
            distance := ray.pos - right_plane.pos;
            t0 := linalg.dot(distance, right_plane.normal) / -denom;
        
            if t0 >= 0.0  && t0 < t {
                t = t0;
                intersection := ray.pos + ray.dir * t;
                chess : bool = 0 <= (math.sin(intersection[2]) * math.sin(intersection[1])) ? true : false;
                rad := math.sqrt(intersection[0]*intersection[0]+intersection[1]*intersection[1]);
                _, fract := math.modf(t);
                if chess {
                    fBuffer[i] = u8(f32(right_plane.clr[0]));
                    fBuffer[i+1] = u8(f32(right_plane.clr[1]));
                    fBuffer[i+2] = u8(f32(right_plane.clr[2]));
                }else {
                    fBuffer[i] = u8(f32(right_plane.clr[0]) * 0.5);
                    fBuffer[i+1] = u8(f32(right_plane.clr[1]) * 0.5);
                    fBuffer[i+2] = u8(f32(right_plane.clr[2]) * 0.5);
                }
            }
        }
        denom = linalg.dot(left_plane.normal, ray.dir);
        if denom > math.F32_EPSILON {
            distance := ray.pos - left_plane.pos;
            t0 := linalg.dot(distance, left_plane.normal) / -denom;
        
            if t0 >= 0.0  && t0 < t {
                t = t0;
                intersection := ray.pos + ray.dir * t;
                chess : bool = 0 <= (math.sin(intersection[2]*3) * math.sin(intersection[1]*3)) ? true : false;
                rad := math.sqrt(intersection[0]*intersection[0]+intersection[1]*intersection[1]);
                _, fract := math.modf(t);
                if chess {
                    fBuffer[i] = u8(f32(left_plane.clr[0]));
                    fBuffer[i+1] = u8(f32(left_plane.clr[1]));
                    fBuffer[i+2] = u8(f32(left_plane.clr[2]));
                }else {
                    fBuffer[i] = u8(f32(left_plane.clr[0]) * 0.5);
                    fBuffer[i+1] = u8(f32(left_plane.clr[1]) * 0.5);
                    fBuffer[i+2] = u8(f32(left_plane.clr[2]) * 0.5);
                }
            }
        }
        denom = linalg.dot(top_plane.normal, ray.dir);
        if denom > math.F32_EPSILON {
            distance := ray.pos - top_plane.pos;
            t0 := linalg.dot(distance, top_plane.normal) / -denom;
        
            if t0 >= 0.0  && t0 < t {
                t = t0;
                intersection := ray.pos + ray.dir * t;
                chess : bool = 0 <= (math.sin(intersection[0]*5) * math.sin(intersection[2]*5)) ? true : false;
                rad := math.sqrt(intersection[0]*intersection[0]+intersection[1]*intersection[1]);
                _, fract := math.modf(t);
                if chess {
                    fBuffer[i] = u8(f32(top_plane.clr[0]));
                    fBuffer[i+1] = u8(f32(top_plane.clr[1]));
                    fBuffer[i+2] = u8(f32(top_plane.clr[2]));
                }else {
                    fBuffer[i] = u8(f32(top_plane.clr[0]) * 0.5);
                    fBuffer[i+1] = u8(f32(top_plane.clr[1]) * 0.5);
                    fBuffer[i+2] = u8(f32(top_plane.clr[2]) * 0.5);
                }
            }
        }
        denom = linalg.dot(bottom_plane.normal, ray.dir);
        if denom > math.F32_EPSILON {
            distance := ray.pos - bottom_plane.pos;
            t0 := linalg.dot(distance, bottom_plane.normal) / -denom;
        
            if t0 >= 0.0  && t0 < t {
                t = t0;
                intersection := ray.pos + ray.dir * t;
                chess : bool = 0 <= (math.sin(intersection[0]*6) * math.sin(intersection[2]*6)) ? true : false;
                rad := math.sqrt(intersection[0]*intersection[0]+intersection[1]*intersection[1]);
                _, fract := math.modf(t);
                if chess {
                    fBuffer[i] = u8(f32(bottom_plane.clr[0]));
                    fBuffer[i+1] = u8(f32(bottom_plane.clr[1]));
                    fBuffer[i+2] = u8(f32(bottom_plane.clr[2]));
                }else {
                    fBuffer[i] = u8(f32(bottom_plane.clr[0]) * 0.5);
                    fBuffer[i+1] = u8(f32(bottom_plane.clr[1]) * 0.5);
                    fBuffer[i+2] = u8(f32(bottom_plane.clr[2]) * 0.5);
                }
            }
        }
    }
}
