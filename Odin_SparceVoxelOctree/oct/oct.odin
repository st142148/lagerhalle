package oct

import "core:fmt"
import "core:math"
import "core:math/linalg"
import "../ply"

Vec3 :: linalg.Vector3f32;
RGB :: [3]byte;

Child_Position :: enum { Bottom_South_West, Bottom_North_West, Bottom_South_East, Bottom_North_East,
                            Top_South_West, Top_North_West, Top_South_East, Top_North_East };

Child_Position_Set :: bit_set[Child_Position];


Oct :: struct {
    ctr     : Vec3,
    width   : f32,
    height  : f32,
    depth   : f32,
    lvls    : byte,
    unit    : f32,
    nodes   : [dynamic][dynamic]Oct_Node,
}

Oct_Node :: struct {
    parent_node : ^Oct_Node,
    clr         : RGB,
    child_mask  : Child_Position_Set,
    child_nodes : [8](^Oct_Node),
}

create_oct :: proc (pc : ply.Pointcloud, lvls : byte) -> (oct : Oct) {
    oct.ctr     = pc.ctr;
    oct.width   = pc.width;
    oct.height  = pc.height;
    oct.depth   = pc.depth;
    oct.lvls    = lvls;

    oct.unit  = oct.height >= oct.width ? oct.height : oct.width;
    oct.unit  = oct.depth >= oct.unit ? oct.depth : oct.unit;
    oct.unit /= f32(int(1) << lvls);

    oct.nodes = make([dynamic][dynamic]Oct_Node, lvls+1);
    oct.nodes[0] = make([dynamic]Oct_Node, 1);
    for i in 1..lvls {
        oct.nodes[i] = make([dynamic]Oct_Node);
    }

    split := 0;//2 << (lvls - 1);
    i := 0;
    for point in pc.points {
        i += 1;
        //if i > 1 do break;
        pos_rel := point.pos - oct.ctr;
        pos_conv : [3]int = [3]int{int(pos_rel.x / oct.unit), int(pos_rel.y / oct.unit), int(pos_rel.z / oct.unit)};
        insert(&oct, &oct.nodes[0][0], nil, 0, {split, split, split}, pos_conv, point.clr);
    }
    fmt.println("Inserted:  ", i);

    return oct;
}

delete_oct :: proc (oct : Oct) {
    for i in 0..oct.lvls {
        delete(oct.nodes[i]);
    }
    delete(oct.nodes);
}

insert :: proc (oct : ^Oct, node : ^Oct_Node, parent_node : ^Oct_Node, lvl : byte, split : [3]int,
                point : [3]int, clr : RGB) -> (insert_location : ^Oct_Node) {

    //fmt.println("########");
    //fmt.println(len(oct.nodes));
    //fmt.println(len(oct.nodes[len(oct.nodes)-1]));
    //fmt.println("Insert:    ", split, " | ", point);
    //fmt.println("at lvl:    ", lvl);
    //fmt.println("of:        ", oct.lvls);
    //fmt.println("into:      ", parent_node);

    new_node : ^Oct_Node;
    if node == nil {
        //append(&oct.nodes[lvl], Oct_Node{});
        new_node = new(Oct_Node);//&oct.nodes[lvl][len(oct.nodes[lvl])-1];
    } else {
        new_node = node;
    }
    new_node.parent_node = parent_node;

    if lvl == oct.lvls {
        new_node.clr = clr;
        return new_node;
    }

    split_diff := 1 << (oct.lvls - lvl - 1);
    using Child_Position;
    if point.x < split.x {
        if point.y < split.y {
            if point.z < split.z {
                new_node.child_mask |= {Bottom_South_West};
                new_node.child_nodes[0] = insert(oct, new_node.child_nodes[0], new_node, lvl + 1,
                                                [3]int{split.x - split_diff, split.y - split_diff, split.z - split_diff},
                                                point, clr);
            } else {
                new_node.child_mask |= {Bottom_North_West};
                new_node.child_nodes[1] = insert(oct, new_node.child_nodes[1], new_node, lvl + 1,
                                                [3]int{split.x - split_diff, split.y - split_diff, split.z + split_diff},
                                                point, clr);
            }
        } else {
            if point.z < split.z {
                new_node.child_mask |= {Top_South_West};
                new_node.child_nodes[4] = insert(oct, new_node.child_nodes[4], new_node, lvl + 1,
                                                [3]int{split.x - split_diff, split.y + split_diff, split.z - split_diff},
                                                point, clr);
            } else {
                new_node.child_mask |= {Top_North_West};
                new_node.child_nodes[5] = insert(oct, new_node.child_nodes[5], new_node, lvl + 1,
                                                [3]int{split.x - split_diff, split.y + split_diff, split.z + split_diff},
                                                point, clr);
            }
        }
    } else {
       if point.y < split.y {
            if point.z < split.z {
                new_node.child_mask |= {Bottom_South_East};
                new_node.child_nodes[2] = insert(oct, new_node.child_nodes[2], new_node, lvl + 1,
                                                [3]int{split.x + split_diff, split.y - split_diff, split.z - split_diff},
                                                point, clr);
            } else {
                new_node.child_mask |= {Bottom_North_East};
                new_node.child_nodes[3] = insert(oct, new_node.child_nodes[3], new_node, lvl + 1,
                                                [3]int{split.x + split_diff, split.y - split_diff, split.z + split_diff},
                                                point, clr);
            }
        } else {
            if point.z < split.z {
                new_node.child_mask |= {Top_South_East};
                new_node.child_nodes[6] = insert(oct, new_node.child_nodes[6], new_node, lvl + 1,
                                                [3]int{split.x + split_diff, split.y + split_diff, split.z - split_diff},
                                                point, clr);
            } else {
                new_node.child_mask |= {Top_North_East};
                new_node.child_nodes[7] = insert(oct, new_node.child_nodes[7], new_node, lvl + 1,
                                                [3]int{split.x + split_diff, split.y + split_diff, split.z + split_diff},
                                                point, clr);
            }
        }
    }

    count : int;
    color : [3]int;
    for n in new_node.child_nodes {
        if n != nil {
            color.x += int(n.clr.x);
            color.y += int(n.clr.y);
            color.z += int(n.clr.z);
            count += 1;
        }
    }
    new_node.clr.x = u8(color.x / count);
    new_node.clr.y = u8(color.y / count);
    new_node.clr.z = u8(color.z / count);

    return new_node;
}


//Traversal order based on ray direction
_NEU := [8]int{0, 1, 2, 3, 4, 5, 6, 7};
_SEU := [8]int{1, 0, 3, 2, 5, 4, 7, 6};
_NWU := [8]int{2, 3, 0, 1, 6, 7, 4, 5};
_SWU := [8]int{3, 2, 1, 0, 7, 6, 5, 4};
_NED := [8]int{4, 5, 6, 7, 0, 1, 2, 3};
_SED := [8]int{5, 4, 7, 6, 1, 0, 3, 2};
_NWD := [8]int{6, 7, 4, 5, 2, 3, 0, 1};
_SWD := [8]int{7, 6, 5, 4, 3, 2, 1, 0};

_SPLITS := [8][3]int{
    {-1, -1, -1},
    {-1, -1,  1},
    { 1, -1, -1},
    { 1, -1,  1},
    {-1,  1, -1},
    {-1,  1,  1},
    { 1,  1, -1},
    { 1,  1,  1},
};

traverse :: proc "contextless" (oct : ^Oct, lvl : byte, start : Vec3, end : Vec3) -> (ok : bool, clr : RGB, t : f32) {

    clr = {5, 0, 15};
    t = math.F32_MAX;

    pos_rel := start - oct.ctr;
    start_conv : [3]int = [3]int{int(pos_rel.x / oct.unit), int(pos_rel.y / oct.unit), int(pos_rel.z / oct.unit)};

    pos_rel = end - oct.ctr;
    end_conv : [3]int = [3]int{int(pos_rel.x / oct.unit), int(pos_rel.y / oct.unit), int(pos_rel.z / oct.unit)};

    s := end_conv - start_conv;
    r := 1 << (oct.lvls);
    w := r * sum(s);

    hit_node : [3]int;

    split := start_conv;

    traversal_oder : ^[8]int;
    if s.x > 0 {
        if s.y > 0 {
            if s.z > 0 {
                traversal_oder = &_NEU;
            } else {
                s.z = -s.z;
                split.z = -split.z;
                traversal_oder = &_SEU;
            }
        } else {
            s.y = -s.y;
            split.y = -split.y;
            if s.z > 0 {
                traversal_oder = &_NED;
            } else {
                s.z = -s.z;
                split.z = -split.z;
                traversal_oder = &_SED;
            }
        }
    } else {
        s.x = -s.x;
        split.x = -split.x;
        if s.y > 0 {
            if s.z > 0 {
                traversal_oder = &_NWU;
            } else {
                s.z = -s.z;
                split.z = -split.z;
                traversal_oder = &_SWU;
            }
        } else {
            s.y = -s.y;
            split.y = -split.y;
            if s.z > 0 {
                traversal_oder = &_NWD;
            } else {
                s.z = -s.z;
                split.z = -split.z;
                traversal_oder = &_SWD;
            }
        }
    }

    ok = _traverse_int(oct, &oct.nodes[0][0], split, lvl, w, r, s, traversal_oder, &clr, &hit_node);

    if ok {
        //hit = true;
        d := hit_node - start_conv;
        t = math.sqrt(
            f32(d.x) * oct.unit * f32(d.x) * oct.unit +
            f32(d.y) * oct.unit * f32(d.y) * oct.unit +
            f32(d.z) * oct.unit * f32(d.z) * oct.unit             );
    }

    return;
}

sum :: proc "contextless" (a : [3]int) -> int {
    return abs(a.x) + abs(a.y) + abs(a.z);
}

cross_abs :: proc "contextless" (ax, ay, bx, by : int) -> int {
    return abs(ax * by - ay * bx);
}
cross :: proc "contextless" (ax, ay, bx, by : int) -> int {
    return (ax * by - ay * bx);
}

_traverse_int :: proc "contextless" (oct : ^Oct, node : ^Oct_Node, split : [3]int, lvl : byte, w : int, r : int,
                        s : [3]int, traversal_oder: ^[8]int,
                        clr : ^RGB, hit_node : ^[3]int) -> bool {

    //fmt.println("------Traversal step");
    //fmt.println("Node:  \n", node^);
    //fmt.println("split:     ", split);
    //fmt.println("lvl:       ", lvl);
    //fmt.println("r:         ", r);
    //fmt.println("w:         ", ww);
    //fmt.println("ca:        ", cross_abs(s.x, s.y, split.x, split.y));
    //fmt.println("s:         ", s);

    if lvl == oct.lvls {
        if node == nil {
            hit_node^ = split;
            return false;
        } else {
            clr^ = node.clr;
            hit_node^ = split;
            return true;
        }
    }

    new_r := r >> 1;
    next_lvl := lvl + 1;
    new_split : [3]int;
    ok : bool;

    for i in 0..7 {
        new_split = [3]int{split.x + _SPLITS[i][0] * new_r,
                            split.y + _SPLITS[i][1] * new_r,
                            split.z + _SPLITS[i][2] * new_r};

        if cross_abs(s.x, s.y, new_split.x, new_split.y) <= w && split.x > -r && split.y > -r {
            if cross_abs(s.x, s.z, new_split.x, new_split.z) <= w && split.z > -r {
                if Child_Position(traversal_oder[i])in node.child_mask {
                    ok = _traverse_int(oct, node.child_nodes[traversal_oder[i]], new_split,  next_lvl, w >> 1, new_r, s, traversal_oder, clr, hit_node);
                }
                if ok do return true;   
            }
        }
    }
    
    
    return false;
}

