package tracy

import "core:fmt"
import "core:math"
import "core:math/rand"
import "../odin-stb/stbi"
import "render"
import "shared:swizzle"

main :: proc () {
	fmt.println("hello");

    render.build_hash_table_u32();
    random := rand.create(123456789);
    random2 := rand.create(1234567890);

    par := render.Particle{render.Vec3{0.0, 0.0, 0.0}, 0.025, render.RGB8{255, 0, 0}};

    particles := make([]render.Particle, 1331);
    //particles := make([]render.Object3D, 1331);

    for i in 0..<len(particles) {
        par.ctr = render.Vec3{f32(rand.float64_range(-2.0, 2.0, &random)), f32(rand.float64_range(-2.0, 2.0, &random)), f32(rand.float64_range(-2.0, 2.0, &random))};
        //particles[i] = render.Object3D{true, render.Vec3{0, 0, 0}, par};
        particles[i] = par;
    }

    /*for i in 0..5 {
        z := -1.0 + 0.4 * f32(i);
        for j in 0..5 {
            y := -1.0 + 0.4 * f32(j);
            for k in 0..5 {
                x := -1.0 + 0.4 * f32(k);
                r := f32(rand.float64_range(-0.005, 0.005, &random2));
                par.ctr = render.Vec3{x + r, y + r, z + r};

                particles[i*121 + j*11 + k] = par;
                //particles[i*121 + j*11 + k] = render.Object3D{true, render.Vec3{0, 0, 0}, par};
            }
        }
    }*/

    //cloud := render.Object3D{true, render.Vec3{0, 0, 0}, render.Container{particles}};
    cloud := render.Object3D{true, render.Vec3{0, 0, 0}, render.init_PointCloud(particles)};

    cam := render.init_camera(position = render.Vec3{0.0, 0.0, -3.0}, resolution = render.Resolution{800, 600});

    tri := render.Object3D{true, render.Vec3{0, 0, 0}, render.Quad{render.GREEN, render.Vec3{-1.0, -0.5, 0.0}, render.Vec3{1.0, -0.5, 0.0}, render.Vec3{0.0, 1.0, 0.0}}};

    //c := render.accList_getCandidates(&cloud, render.Vec3{-2.0, -2.0, -2.0}, render.Vec3{2.0, 2.0, 2.0});
    //fmt.println(len(c));

    zBuffer, fBuffer := render.render(cam, cloud);
    defer delete(zBuffer);
    defer delete(fBuffer);

    zBufferU8 : []u8 = make([]u8, len(zBuffer));
    defer delete(zBufferU8);

    for i in 0..<len(zBuffer) {
        if zBuffer[i] > 6.0 do zBufferU8[i] = 0;
        else {
            zBufferU8[i] = 255 - u8(zBuffer[i] / 6.0 * 255.0);
        }
    }

    stbi.write_png("fbuffer.png", int(cam.viewport.res.x), int(cam.viewport.res.y), 3, fBuffer[0:cam.viewport.res.x*cam.viewport.res.y*3], int(3*cam.viewport.res.x));
    stbi.write_png("zbuffer_s3.png", int(cam.viewport.res.x), int(cam.viewport.res.y), 1, zBufferU8[0:cam.viewport.res.x*cam.viewport.res.y], int(cam.viewport.res.x));
}