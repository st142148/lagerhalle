package render

import "core:fmt"
import "core:math"
import "core:time"

Vec3 :: math.Vec3;
Resolution :: distinct [2]u16;
RGB8 :: distinct [3]u8;

VOID := RGB8{0, 0, 40};
WHITE := RGB8{255, 255, 255};
BLACK := RGB8{0, 0, 0};
RED := RGB8{255, 0, 0,};
GREEN := RGB8{0, 255, 0};
BLUE := RGB8{0, 0, 255};
PURPLE := RED + BLUE;
YELLOW := RED + GREEN;
TORQUOISE := BLUE + GREEN;

counter : uint = 0;
counter2 : uint = 0;

Ray :: struct {
	origin:		Vec3,
	dir:		Vec3,
}

Camera :: struct {
	pos:		Vec3,
	up:			Vec3,
	w:			Vec3,
	u:			Vec3,
	v:			Vec3,
	viewport:	Viewport,
}

Viewport :: struct {
	res:		Resolution,
	d:			f32,
	l:			f32,
	r:			f32,
	t:			f32,
	b:			f32,
}

init_camera :: proc(position: Vec3 = {0.0, 0.0, -3.0}, target: Vec3 = {0.0, 0.0, 0.0}, resolution: Resolution = {800, 600}) -> (cam: Camera) {
	cam.up = Vec3{0.0, 1.0, 0.0};
	cam.pos = position;
	cam.w = math.norm(cam.pos - target);
	cam.u = math.norm(math.cross(cam.up, cam.w));
	cam.v = math.norm(math.cross(cam.w, cam.u));

	using cam.viewport;
	res = resolution;
	d = 2.0;
	l = -1.0;
	r = 1.0;
	t = -1.0;
	b = 1.0;

	return;
}

render :: proc (cam: Camera, scene: Object3D) -> (zBuffer: [dynamic]f32, fBuffer: [dynamic]u8){
	fmt.println("Rendering!");
	using cam.viewport;

	zBuffer = make([dynamic]f32, 0, res.x*res.y);
	fBuffer = make([dynamic]u8, 0, res.x*res.y*3);

	stepX := (r - l) / f32(res.x);
	stepY := (b - t) / f32(res.y);

	timeStart := time.now();
	for i in 0..<res.y {
		for j in 0..<res.x {
			x := l + (f32(j) + 0.5) * stepX;
			y := t + (f32(i) + 0.5) * stepY; 

			s := math.norm((x * cam.u) + (y * cam.v) - (d * cam.w));
			ray := Ray{cam.pos, s};

			t, clr, ok := rayIntersect(&ray, &scene);

			counter2 = (counter2 + counter) /2;
			counter = 0;
			if ok {
				append(&zBuffer, t);
				append(&fBuffer, clr[0]);
				append(&fBuffer, clr[1]);
				append(&fBuffer, clr[2]);
			} else {
				append(&zBuffer, math.F32_MAX);
				append(&fBuffer, 0);
				append(&fBuffer, 0);
				append(&fBuffer, 40);
			}
		}
	}
	timeEnd := time.now();
	fmt.println("Time to render: ", time.duration_seconds(time.diff(timeStart, timeEnd)));
	fmt.println("Counter: ", counter2);
	return;
}