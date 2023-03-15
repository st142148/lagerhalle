package main

import "core:fmt"
import "core:os"
import "core:mem"
import "core:runtime"
import "core:strings"
import "core:math"
import "core:math/linalg"

Vec3 :: linalg.Vector3f32;
RGB :: [3]byte;

Pointcloud :: struct {
    points  : []Point,
    ctr     : Vec3,
    width   : f32,
    height  : f32,
    depth   : f32,
}

Point :: struct #packed {
    pos : Vec3,
    clr : RGB,
    s : f32,
}

load_pointcloud :: proc (path : string) -> (pc : Pointcloud) {
    file, ok := os.read_entire_file(path);

    if !ok do fmt.panicf("Failed to load Pointcloud");

    if strings.compare("ply", transmute(string)file[:3]) != 0 {
        fmt.panicf("File does not use ply format!");
    }
    
    data_start := strings.index(transmute(string)file[:1000], "end_header") + 11;

    pc.points = transmute([]Point)file[data_start:];
    raw_points := transmute(mem.Raw_Slice)pc.points;
    raw_points.len = 6449899;
    pc.points = transmute([]Point)raw_points;

    xmin : f32 = math.F32_MAX;
    ymin : f32 = math.F32_MAX;
    zmin : f32 = math.F32_MAX;
    xmax : f32 = math.F32_MIN;
    ymax : f32 = math.F32_MIN;
    zmax : f32 = math.F32_MIN;

    for point in pc.points {
        if point.pos.x <= xmin do xmin = point.pos.x;
        if point.pos.y <= ymin do ymin = point.pos.y;
        if point.pos.z <= zmin do zmin = point.pos.z;
        if point.pos.x >= xmax do xmax = point.pos.x;
        if point.pos.y >= ymax do ymax = point.pos.y;
        if point.pos.z >= zmax do zmax = point.pos.z;
    }

    pc.width = xmax - xmin;
    pc.height = ymax - ymin;
    pc.depth = zmax - zmin;
    pc.ctr = Vec3{xmin + pc.width / 2, ymin + pc.height / 2, zmin + pc.depth / 2};

    return pc;
}