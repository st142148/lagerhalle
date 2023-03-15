CFLAGS = -std=c99 
LDFLAGS = -L/libs `pkg-config --static --libs glfw3` -lvulkan


shaders: src/shaders/shader.frag src/shaders/shader.vert src/shaders/shader.comp
	glslangValidator -V -o src/shaders/frag.spv src/shaders/shader.frag
	glslangValidator -V -o src/shaders/vert.spv src/shaders/shader.vert
	glslangValidator -V -o src/shaders/comp.spv src/shaders/shader.comp

VulkanTest: src/main.c
	gcc $(CFLAGS) -o VulkanTest src/main.c src/libs/lodepng.c $(LDFLAGS)

VulkanDebug: src/main.c
	gcc $(CFLAGS) -g -o VulkanDebug src/main.c src/libs/lodepng.c $(LDFLAGS)

.PHONY: test clean

test: VulkanTest
	./VulkanTest

debug: VulkanDebug
	gdb VulkanDebug
clean:
	rm -f VulkanTest
