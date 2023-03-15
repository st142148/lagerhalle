package render

import "core:fmt"
import "core:hash"
import "core:math"
import "core:time"

HASH_TABLE_U32 : [64]u64;

build_hash_table_u32 :: proc() {
    bit : u64 = 0b1000000000000000000000000000000000000000000000000000000000000000;
    for i in 0..<64 {
        HASH_TABLE_U32[i] = bit;
        bit = bit >> 1;
    }
}

getU32Hash :: proc(val: uint) -> u64 {
    return HASH_TABLE_U32[val % 64];
}

accList_getCandidates :: proc(cloud: ^PointCloud, entry: Vec3, exit: Vec3, support: f32) -> (candidates: [dynamic]Particle) {

    timeStart := time.now();
    using cloud;

    offsetX, offsetY, offsetZ := support, support, support;
    invx, invy, invz : bool;

    if entry.x > exit.x {
        offsetX *= -1.0;
        invx = true;
    }
    if entry.y > exit.y {
        offsetY *= -1.0;
        invy = true;
    }
    if entry.z > exit.z {
        offsetZ *= -1.0;
        invz = true;
    }

    x0, _ := binary_search(points, lx, entry.x - offsetX, uint(0));
    x1, _ := binary_search(points, lx, exit.x + offsetX, uint(0));
    y0, _ := binary_search(points, ly, entry.y - offsetY, uint(1));
    y1, _ := binary_search(points, ly, exit.y + offsetY, uint(1));
    z0, _ := binary_search(points, lz, entry.z - offsetZ, uint(2));
    z1, _ := binary_search(points, lz, exit.z + offsetZ, uint(2));

    
    if x0 == x1 || y0 == y1 || z0 == z1 do return;

    nx, ny, nz: int;
    if x0 < x1 do nx = x1 - x0;
    else do nx = x0 - x1;
    if y0 < y1 do ny = y1 - y0;
    else do ny = y0 - y1;
    if z0 < z1 do nz = z1-z0;
    else do nz = z0 - z1;

    n := nx < ny ? nx : ny;
    n = n < nz ? n : nz;
    //fmt.println(y0, y1);
    //fmt.println(nx, ny, nz, n);

    lvl := uint(log2(f32(n)));
    if lvl < 6 do lvl = 1;
    else do lvl -= 5;
    //if lvl >= 5 do lvl -= 4;
    //fmt.println(n,  lvl);

    numSteps := (1<<lvl)-1;
    //fmt.println(n, numSteps);
    stepx : int = nx >> lvl;
    stepy : int = ny >> lvl;
    stepz : int = nz >> lvl;


    //cX := lx[x0:x1];
    //cY := ly[y0:y1];
    //cZ := lz[z0:z1];


    //for i in 0..numSteps{
    reached_end := false;
    for !reached_end {
        //fmt.println("STEP ", i);

        //if x0+stepx >= x1*incrx || y0+stepy >= y1*incry || z0+stepz >= z1*incrz) {
        //if i == numSteps {
        //    x1 = uint(len(cX)-1);
        //    y1 = uint(len(cY)-1);
        //    z1 = uint(len(cZ)-1);
        //    reached_end = true;
        //}
        //fmt.println("Ranges: \nX: ", x0, x1, "\nY: ", y0, y1, "\nZ: ", z0, z1);

        bloom : u64;
        bloom2: u64;

        x0n, y0n, z0n : int = 0, 0, 0;

        countx := 0;
        county := 0;
        countz := 0;

        //fmt.println("--x--");
        if invx {
            x0n = x0 - stepx;
            if x0n < x1 {
                x0n = x1;
                reached_end = true;
            }
            for j : int = x0; j > x0n; j -= 1 {
                bloom |= getU32Hash(lx[j]);
                //fmt.printf("%d; %32b\n", cX[j], getU32Hash(cX[j]));
                countx += 1;
            }
        } else {
            x0n = x0 + stepx;
            if x0n > x1 {
                x0n = x1;
                reached_end = true;
            }
            for j in x0..x0n {
                bloom |= getU32Hash(lx[j]);
                //fmt.printf("%d; %32b\n", cX[j], getU32Hash(cX[j]));
                countx += 1;
            }
        }
        //fmt.println("Count: ", countx);
        //fmt.println("--y--");
        if invy {
            y0n = y0 - stepy;
            if y0n < y1 {
                y0n = y1;
                reached_end = true;
            }
            for j : int = y0; j > y0n; j -= 1 {
                h := getU32Hash(ly[j]);
                if bloom & h == h do bloom2 |= h;
                //fmt.printf("%d; %32b\n", cX[j], getU32Hash(cX[j]));
                county += 1;
            }
        } else {
            y0n = y0 + stepy;
            if y0n > y1 {
                y0n = y1;
                reached_end = true;
            }
            for j in y0..y0n {
                h := getU32Hash(ly[j]);
                if bloom & h == h do bloom2 |= h;
                //fmt.printf("%d; %32b\n", cX[j], getU32Hash(cX[j]));
                county += 1;
            }
        }
        //fmt.println("Count: ", county);
        //fmt.println("--z--");
        if invz {
            z0n = z0 - stepz;
            if z0n < z1 {
                z0n = z1;
                reached_end = true;
            }
            for j : int = z0; j > z0n; j -= 1 {
                h := getU32Hash(lz[j]);
                if bloom2 & h == h do append(&candidates, points[lz[j]]);
                //fmt.printf("%d; %32b\n", cX[j], getU32Hash(cX[j]));
                countz += 1;
            }
        } else {
            z0n = z0 + stepz;
            if z0n > z1 {
                z0n = z1;
                reached_end = true;
            }
            for j in z0..z0n {
                h := getU32Hash(lz[j]);
                if bloom2 & h == h do append(&candidates, points[lz[j]]);
                //fmt.printf("%d; %32b\n", cX[j], getU32Hash(cX[j]));
                countz += 1;
            }
        }
        //fmt.println("Count: ", countz);

        x0 = x0n;
        y0 = y0n;
        z0 = z0n;

        //fmt.printf("%32b\n", bloom);
        //fmt.printf("%32b\n", bloom2);
    }

    timeEnd := time.now();
    //fmt.println("Time to get candidates: ", time.duration_seconds(time.diff(timeStart, timeEnd)));
    return;
}

accList_getNeighbours :: proc(cloud: ^PointCloud, sample: Vec3, support: f32) -> (candidates: [dynamic]Particle) {
    using cloud;
    x0, _ := binary_search(points, lx, sample.x - support, uint(0));
    x1, _ := binary_search(points, lx, sample.x + support, uint(0));
    y0, _ := binary_search(points, ly, sample.y - support, uint(1));
    y1, _ := binary_search(points, ly, sample.y + support, uint(1));
    z0, _ := binary_search(points, lz, sample.z - support, uint(2));
    z1, _ := binary_search(points, lz, sample.z + support, uint(2));

    cX := lx[x0:x1];
    cY := ly[y0:y1];
    cZ := lz[z0:z1];

    bloom : u64;
    bloom2: u64;

    for p in cX {
        bloom |= getU32Hash(p);
    }
    for p in cY {
        h := getU32Hash(p);
        if bloom & h == h do bloom2 |= h;
    }
    for p in cZ {
        h := getU32Hash(p);
        if bloom2 & h == h do append(&candidates, points[p]);
    }
    return;
}

accList_getNNeighbours :: proc(cloud: ^PointCloud, sample: Vec3, n: int) -> (candidates: [dynamic]Particle) {
    return;
}


binary_search :: proc {binary_search_base, binary_search_pc};

binary_search_base :: proc (array: []$T, element: T) -> (idx: uint, ok: bool) {
    size : uint = transmute(uint)len(array);
    if size == 0 do return;
    eval : T;
    cmp : i8;

    base : uint = 0;
    for size > 1 {
        half : uint = size / 2;
        mid : uint = base + half;

        #no_bounds_check { eval = array[mid];}

        if element < eval do cmp = -1;
        else if element > eval do cmp = 1;
        else {
            idx = mid;
            ok = true;
            return;
        }
        
        if cmp == 1 do base = mid;
        size -= half;
    }

    #no_bounds_check { eval = array[base];}
    if element < eval do cmp = -1;
    else if element > eval do cmp = 1;
    else {
        idx = base;
        ok = true;
        return;
    }
    idx = base;
    if cmp == 1 do idx += 1;
    ok = false;
    return;
}

binary_search_pc :: proc (elements: []Particle, array: []uint, element: f32, dim: uint) -> (idx: int, ok: bool) {
    size : uint = transmute(uint)len(array);
    if size == 0 do return;
    eval : f32;
    cmp : i8;

    base : uint = 0;
    for size > 1 {
        half : uint = size / 2;
        mid : uint = base + half;

        #no_bounds_check { eval = elements[array[mid]].ctr[dim];}
        if element < eval do cmp = -1;
        else if element > eval do cmp = 1;
        else {
            idx = int(mid);
            ok = true;
            return;
        }
        
        if cmp == 1 do base = mid;
        size -= half;
    }

    #no_bounds_check { eval = elements[array[base]].ctr[dim];}
    if element < eval do cmp = -1;
    else if element > eval do cmp = 1;
    else {
        idx = int(base);
        ok = true;
        return;
    }
    idx = int(base);
    if cmp == 1 do idx += 1;
    if idx == len(array) do idx -= 1;
    ok = false;
    return;
}

quick_sort_pc :: proc(array: []uint, particles: []$P, dim: uint) {
    a := array;
    n := len(a);
    if n < 2 do return;

    p := particles[a[n/2]].ctr[dim];
    i, j := 0, n-1;

    loop: for {
        for particles[a[i]].ctr[dim] < p do i += 1;
        for p < particles[a[j]].ctr[dim] do j -= 1;

        if i >= j do break loop;

        a[i], a[j] = a[j], a[i];
        i += 1;
        j -= 1;
    }

    quick_sort_pc(a[0:i], particles, dim);
    quick_sort_pc(a[i:n], particles, dim);
}

log2 :: proc(v: f32) -> f32 {
    return math.log(v) / math.LOG_TWO;
}