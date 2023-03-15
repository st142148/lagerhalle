package render

import "core:math"
import "core:fmt"

ObjType :: union {
    Sphere,
    Plane,
    Tri,
    Quad,
    Particle,
    //HeightMap,
    BoundingBox,
    Container,
    PointCloud,
    MetaBalls
}

Object3D :: struct {
    visible:    bool,
    ctr:        Vec3,

    oType:      ObjType,
}

Vertex :: struct {
    ctr:        Vec3,
    //texCoord: Vec2,
    clr:        RGB8,
}

Sphere :: struct {
    ctr:           Vec3,
    rad:           f32,
    clr:           RGB8,
}

Particle :: struct {
    ctr:            Vec3,
    rad:            f32,
    //vel:            Vec3,
    clr:            RGB8,
}

Tri :: struct {
    clr:            RGB8,
    A:              Vec3,
    B:              Vec3,
    C:              Vec3,
}

Quad :: struct {
    clr:            RGB8,
    A:              Vec3,
    B:              Vec3,
    C:              Vec3,
}

Plane :: struct {
    pnt:            Vec3,
    normal:         Vec3,
    clr:            RGB8,
}

Mesh :: struct {
    tris:           []Vertex,
    indices:        []uint,
}

BoundingBox :: struct {
    boundaries:     [6]Quad,
}

Container :: struct {
    content:        []Object3D,
}

PointCloud :: struct {
    boundingBox:    BoundingBox,
    points:         []Particle,
    lx:             []uint,
    ly:             []uint,
    lz:             []uint,
}

MetaBall :: struct {
    using base:     Particle,

}

MetaBalls :: struct {
    boundingBox:    BoundingBox,
    points:         []MetaBall,
    lx:             []uint,
    ly:             []uint,
    lz:             []uint,
}

init_PointCloud :: proc (particles: []Particle) -> (cloud: PointCloud) {
    minX, maxX, minY, maxY, minZ, maxZ : f32;
    len := len(particles);
    cloud.lx = make([]uint, len);
    cloud.ly = make([]uint, len);
    cloud.lz = make([]uint, len);
    for i in 0..<len {
        cloud.lx[i] = uint(i);
        cloud.ly[i] = uint(i);
        cloud.lz[i] = uint(i);
    }
    quick_sort_pc(cloud.lx, particles, 0);
    quick_sort_pc(cloud.ly, particles, 1);
    quick_sort_pc(cloud.lz, particles, 2);

    cloud.points = particles;
    //cloud.visible = true;

    max := len-1;
    offset : f32 = 0.25;

    using cloud;
    a := Vec3{particles[lx[0]].ctr.x-offset, particles[ly[0]].ctr.y-offset, particles[lz[0]].ctr.z-offset};
    b := Vec3{particles[lx[0]].ctr.x-offset, particles[ly[max]].ctr.y+offset, particles[lz[0]].ctr.z-offset};
    c := Vec3{particles[lx[max]].ctr.x+offset, particles[ly[max]].ctr.y+offset, particles[lz[0]].ctr.z-offset};
    d := Vec3{particles[lx[max]].ctr.x+offset, particles[ly[0]].ctr.y-offset, particles[lz[0]].ctr.z-offset};
    e := Vec3{particles[lx[0]].ctr.x-offset, particles[ly[0]].ctr.y-offset, particles[lz[max]].ctr.z+offset};
    f := Vec3{particles[lx[0]].ctr.x-offset, particles[ly[max]].ctr.y+offset, particles[lz[max]].ctr.z+offset};
    g := Vec3{particles[lx[max]].ctr.x+offset, particles[ly[max]].ctr.y+offset, particles[lz[max]].ctr.z+offset};
    h := Vec3{particles[lx[max]].ctr.x+offset, particles[ly[0]].ctr.y-offset, particles[lz[max]].ctr.z+offset};

    boundingBox.boundaries[0] = Quad{RGB8{20, 150, 20}, a, b, d};
    boundingBox.boundaries[1] = Quad{RGB8{20, 150, 20}, e, f, h};
    boundingBox.boundaries[2] = Quad{RGB8{20, 150, 20}, a, b, e};
    boundingBox.boundaries[3] = Quad{RGB8{20, 150, 20}, d, c, h};
    boundingBox.boundaries[4] = Quad{RGB8{20, 150, 20}, b, f, c};
    boundingBox.boundaries[5] = Quad{RGB8{20, 150, 20}, a, e, d};

    return;
}

init_MetaBalls :: proc (balls: []MetaBall) -> (metaBalls: MetaBalls) {
    minX, maxX, minY, maxY, minZ, maxZ : f32;
    len := len(balls);
    metaBalls.lx = make([]uint, len);
    metaBalls.ly = make([]uint, len);
    metaBalls.lz = make([]uint, len);
    for i in 0..<len {
        metaBalls.lx[i] = uint(i);
        metaBalls.ly[i] = uint(i);
        metaBalls.lz[i] = uint(i);
    }
    quick_sort_pc(metaBalls.lx, balls, 0);
    quick_sort_pc(metaBalls.ly, balls, 1);
    quick_sort_pc(metaBalls.lz, balls, 2);

    metaBalls.points = balls;
    //metaBalls.visible = true;

    max := len-1;
    offset : f32 = 0.25;

    using metaBalls;
    a := Vec3{balls[lx[0]].ctr.x-offset, balls[ly[0]].ctr.y-offset, balls[lz[0]].ctr.z-offset};
    b := Vec3{balls[lx[0]].ctr.x-offset, balls[ly[max]].ctr.y+offset, balls[lz[0]].ctr.z-offset};
    c := Vec3{balls[lx[max]].ctr.x+offset, balls[ly[max]].ctr.y+offset, balls[lz[0]].ctr.z-offset};
    d := Vec3{balls[lx[max]].ctr.x+offset, balls[ly[0]].ctr.y-offset, balls[lz[0]].ctr.z-offset};
    e := Vec3{balls[lx[0]].ctr.x-offset, balls[ly[0]].ctr.y-offset, balls[lz[max]].ctr.z+offset};
    f := Vec3{balls[lx[0]].ctr.x-offset, balls[ly[max]].ctr.y+offset, balls[lz[max]].ctr.z+offset};
    g := Vec3{balls[lx[max]].ctr.x+offset, balls[ly[max]].ctr.y+offset, balls[lz[max]].ctr.z+offset};
    h := Vec3{balls[lx[max]].ctr.x+offset, balls[ly[0]].ctr.y-offset, balls[lz[max]].ctr.z+offset};

    boundingBox.boundaries[0] = Quad{RGB8{20, 150, 20}, a, b, d};
    boundingBox.boundaries[1] = Quad{RGB8{20, 150, 20}, e, f, h};
    boundingBox.boundaries[2] = Quad{RGB8{20, 150, 20}, a, b, e};
    boundingBox.boundaries[3] = Quad{RGB8{20, 150, 20}, d, c, h};
    boundingBox.boundaries[4] = Quad{RGB8{20, 150, 20}, b, f, c};
    boundingBox.boundaries[5] = Quad{RGB8{20, 150, 20}, a, e, d};

    return;
}