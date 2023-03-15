package render

import "core:fmt"
import "core:math"

FACE_CULLING :: false;
MARCHING_DISTANCE : f32 : 0.05;

rayIntersect :: proc {rayInt_base, rayInt_Sphere, rayInt_Particle, rayInt_Quad, rayInt_Tri, rayInt_Plane, rayInt_Container, rayInt_PointCloud};

rayInt_base :: proc(ray: ^Ray, obj: ^Object3D) -> (t: f32 = math.F32_MAX, clr: RGB8 = RGB8{0, 0, 40}, ok: bool){
    if !obj.visible do return;
    switch in obj.oType{
        case Sphere: {
            t, clr, ok = rayInt_Sphere(ray, &obj.oType.(Sphere));
        }
        case Particle: {
            t, clr, ok = rayInt_Particle(ray, &obj.oType.(Particle));
        }
        case Quad: {
            t, clr, ok = rayInt_Quad(ray, &obj.oType.(Quad));
        }
        case Tri: {
            t, clr, ok = rayInt_Tri(ray, &obj.oType.(Tri));
        }
        case Plane: {
            t, clr, ok = rayInt_Plane(ray, &obj.oType.(Plane));
        }
        case Container: {
            t, clr, ok = rayInt_Container(ray, &obj.oType.(Container));
        }
        case PointCloud: {
            t, clr, ok = rayInt_PointCloud(ray, &obj.oType.(PointCloud));            
        }
        case:
    }

    return;
}

rayInt_Sphere :: proc(ray: ^Ray, obj: ^Sphere) -> (t: f32 = math.F32_MAX, clr: RGB8 = RGB8{0, 0, 40}, ok: bool){
    t0, t1, clr_tmp, _, ok_tmp := rayIntersect_hull(ray, obj);
    if !ok_tmp do return;
    if t0 < 0.0 {
        if t1 < 0.0 {
            ok = false;
        }
        t = t1;
        clr = clr_tmp;
        ok = true;
        return;
    }
    t = t0;
    clr = clr_tmp;
    ok = true;
    return;
}

rayInt_Particle :: proc(ray: ^Ray, obj: ^Particle) -> (t: f32 = math.F32_MAX, clr: RGB8 = RGB8{0, 0, 40}, ok: bool){
    counter += 1;
    originToCtr := obj.ctr - ray.origin;
    distance := math.dot(originToCtr, ray.dir) / (math.length(originToCtr) * math.length(ray.dir)) * math.length(originToCtr);
    offset := math.length(obj.ctr - (ray.origin + ray.dir * distance));
    if offset <= obj.rad {
        t = distance;
        clr = obj.clr;
        ok = true;
    }
    return;
}

rayInt_Quad :: proc(ray: ^Ray, obj: ^Quad) -> (t: f32 = math.F32_MAX, clr: RGB8 = RGB8{0, 0, 40}, ok: bool){
    /*
     *  "Fast, Minimum Storage Ray/Triangle Intersection"
     *  - Tomas Möller, Ben Trumbore
    */
    e1 := obj.B - obj.A;
    e2 := obj.C - obj.A;
    pvec := math.cross(ray.dir, e2);
    det := math.dot(e1, pvec);

    //no face culling
    when !FACE_CULLING {
        if det < math.EPSILON && det > -math.EPSILON do return;
        inv_det := 1.0 / det;

        tvec := ray.origin - obj.A;
        u := math.dot(tvec, pvec) * inv_det;
        if u < 0.0 || u > 1.0 do return;

        qvec := math.cross(tvec, e1);
        v := math.dot(ray.dir, qvec) * inv_det;
        if v < 0.0 || v > 1.0 do return;

        t = math.dot(e2, qvec) * inv_det;
        clr = obj.clr;
        ok = true;
        return;
    } else { //face culling
        if det < math.EPSILON do return;

        tvec := ray.origin - obj.A;
        u := math.dot(tvec, pvec);
        if u < 0.0 || u > det do return;

        qvec := math.cross(tvec, e1);
        v := math.dot(ray.dir, qvec);
        if v < 0.0 || v + u > det do return; //for tris: ...|| v > det...

        t = math.dot(e2, qvec) * 1.0 / det;
        clr = obj.clr;
        ok = true;
        return;
    }
}

rayInt_Tri :: proc(ray: ^Ray, obj: ^Tri) -> (t: f32 = math.F32_MAX, clr: RGB8 = RGB8{0, 0, 40}, ok: bool){
    /*
     *  "Fast, Minimum Storage ^Ray/Triangle Intersection"
     *  - Tomas Möller, Ben Trumbore
    */
    e1 := obj.B - obj.A;
    e2 := obj.C - obj.A;
    pvec := math.cross(ray.dir, e2);
    det := math.dot(e1, pvec);

    //no face culling
    when !FACE_CULLING {
        if det < math.EPSILON && det > -math.EPSILON do return;
        inv_det := 1.0 / det;

        tvec := ray.origin - obj.A;
        u := math.dot(tvec, pvec) * inv_det;
        if u < 0.0 || u > 1.0 do return;

        qvec := math.cross(tvec, e1);
        v := math.dot(ray.dir, qvec) * inv_det;
        if v < 0.0 || v > 1.0 do return;

        t = math.dot(e2, qvec) * inv_det;
        clr = obj.clr;
        ok = true;
        return;
    } else { //face culling
        if det < math.EPSILON do return;

        tvec := ray.origin - obj.A;
        u := math.dot(tvec, pvec);
        if u < 0.0 || u > det do return;

        qvec := math.cross(tvec, e1);
        v := math.dot(ray.dir, qvec);
        if v < 0.0 || v + u > det do return;

        t = math.dot(e2, qvec) * 1.0 / det;
        clr = obj.clr;
        ok = true;
        return;
    }
}

rayInt_Plane :: proc(ray: ^Ray, obj: ^Plane) -> (t: f32 = math.F32_MAX, clr: RGB8 = RGB8{0, 0, 40}, ok: bool){
    denom := math.dot(obj.normal, ray.dir);
    if denom < -math.EPSILON {
        distance := ray.origin - obj.pnt;
        t = math.dot(distance, obj.normal) / -denom;
        if t >= 0.0 {
            ok = true;
            clr = obj.clr;
        }
    }
    return;
}

rayInt_Container :: proc(ray: ^Ray, obj: ^Container) -> (t: f32 = math.F32_MAX, clr: RGB8 = RGB8{0, 0, 40}, ok: bool){
    t = math.F32_MAX;
    clr = RGB8{0, 0, 20};

    for i in 0..<len(obj.content) {
        t_tmp, clr_tmp, ok_tmp := rayIntersect(ray, &obj.content[i]);
        if t_tmp < t {
            t = t_tmp;
            clr = clr_tmp;
            ok = true;
        }
    }
    return;
}

rayInt_PointCloud :: proc(ray: ^Ray, obj: ^PointCloud) -> (t: f32 = math.F32_MAX, clr: RGB8 = RGB8{0, 0, 40}, ok: bool){
    t0, t1, clr0, clr1, ok_bound := rayIntersect_hull(ray, &(obj.boundingBox));
    if  !ok_bound {
        return;
    }

    candidates := accList_getCandidates(obj, ray.origin + ray.dir * t0, ray.origin + ray.dir * t1, 0.030);
    defer delete(candidates);
    for i in 0..<len(candidates) {
        t_tmp, clr_tmp, ok_tmp := rayIntersect(ray, &candidates[i]);
        if t_tmp < t {
            t = t_tmp;
            clr = clr_tmp;
            ok = true;
        }
    }
    return;
}

rayInt_MetaBalls :: proc(ray: ^Ray, obj: ^MetaBalls) -> (t: f32 = math.F32_MAX, clr: RGB8 = RGB8{0, 0, 40}, ok: bool){
    t0, t1, clr0, clr1, ok_bound := rayIntersect_hull(ray, &(obj.boundingBox));
    if  !ok_bound {
        return;
    }

    /*candidates := accList_getCandidates(obj, ray.origin + ray.dir * t0, ray.origin + ray.dir * t1, 0.030);
    defer delete(candidates);
    for i in 0..<len(candidates) {
        t_tmp, clr_tmp, ok_tmp := rayIntersect(ray, &candidates[i]);
        if t_tmp < t {
            t = t_tmp;
            clr = clr_tmp;
            ok = true;
        }
    }*/
    return;
}


rayIntersect_hull :: proc {rayInt_hull_base, rayInt_hull_Sphere, rayInt_hull_BoundingBox};

rayInt_hull_base :: proc(ray: ^Ray, obj: ^Object3D) 
    -> (t0: f32 = math.F32_MAX, t1: f32 = math.F32_MAX, clr0: RGB8 = RGB8{0, 0, 40}, clr1: RGB8 = RGB8{0, 0, 40}, ok: bool) {
    

    if !obj.visible do return;
    switch in obj.oType {
        case BoundingBox: {
            t0, t1, clr0, clr1, ok = rayIntersect_hull(ray, &obj.oType.(BoundingBox));
        }
        case Sphere: {
            t0, t1, clr0, clr1, ok = rayIntersect_hull(ray, &obj.oType.(Sphere));
        }
    }
    return;
}

rayInt_hull_Sphere :: proc(ray: ^Ray, obj: ^Sphere) 
    -> (t0: f32 = math.F32_MAX, t1: f32 = math.F32_MAX, clr0: RGB8 = RGB8{0, 0, 40}, clr1: RGB8 = RGB8{0, 0, 40}, ok: bool) {

    l := ray.origin - obj.ctr;
    a := math.dot(ray.dir, ray.dir);
    b := 2.0 * math.dot(ray.dir, l);
    c := math.dot(l, l) - obj.rad * obj.rad;

    discr := b * b - 4.0 * a * c;
    if discr < 0.0 do return;
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
    clr0 = obj.clr;
    clr1 = obj.clr;
    ok = true;

    return;
}

rayInt_hull_BoundingBox :: proc(ray: ^Ray, obj: ^BoundingBox) 
    -> (t0: f32 = math.F32_MAX, t1: f32 = math.F32_MAX, clr0: RGB8 = RGB8{0, 0, 40}, clr1: RGB8 = RGB8{0, 0, 40}, ok: bool) {

    for i in 0..<len(obj.boundaries) {
        if !ok {
            t_tmp, clr_tmp, ok_tmp := rayInt_Quad(ray, &obj.boundaries[i]);
            if t_tmp < t0 {
                t0 = t_tmp;
                clr0 = clr_tmp;
                ok = true;
            }
        } else {
            t_tmp, clr_tmp, ok_tmp := rayInt_Quad(ray, &obj.boundaries[i]);
            if t_tmp < t1 {
                t1 = t_tmp;
                clr1 = clr_tmp;
                ok = true;
            }
        }
    }
    if t1 < t0 {
        t_tmp := t1;
        t1 = t0;
        t0 = t_tmp;
    }

    return;
}