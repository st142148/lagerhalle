# Vulkan Tutorial C

This project follows [vulkan-tutorial.com](https://www.vulkan-tutorial.com), but without the convenience of C++.
glm is replaced with [cglm](https://github.com/recp/cglm), tinyobjloader with [tinyobjloader-c](https://github.com/syoyo/tinyobjloader-c).

This project is learn-as-you-go in regards to the C language and for the sake of following the tutorial and learning vulkan does not adhere the any particular best practices or style-guides.

Chalet model and texture originaly from [sketchfab](https://sketchfab.com/3d-models/chalet-hippolyte-chassande-baroz-e925320e1d5744d9ae661aeff61e7aef)

## Building
For the main source file:
```shell
make test
```
To recompile the shaders:
```shell
make shaders
```
