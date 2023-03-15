package main

// Core Imports
import "core:fmt"
import "core:log"
import "core:os"
import "core:mem"
import "core:c"

import "core:math"
import "core:math/linalg"

V3 :: linalg.Vector3;
V2 :: linalg.Vector2;
M4 :: linalg.Matrix4;

// Library Imports
import vk   "shared:odin_vulkan"
import glfw "shared:odin_glfw/bindings"

// Debug
logger      : log.Logger;
logLevel    := log.Level.Debug;

VALIDATION_ENABLED :: true;
when VALIDATION_ENABLED == true {
    ENABLED_LAYERS := []cstring{"VK_LAYER_KHRONOS_validation"};    
} else {
    ENABLED_LAYERS : []cstring = nil;
}

//------------------------------------------------------t

//GLFW
WIDTH       : u32 : 800;
HEIGHT      : u32 : 600;

// Vulkan
// Definitions
DEVICE_EXTENSIONS := []cstring{vk.KHR_SWAPCHAIN_EXTENSION_NAME};

MAX_FRAMES_IN_FLIGHT :: 2;

MODEL_PATH      : cstring = "assets/chalet.obj";
TEXTURE_PATH    : cstring = "assets/chalet.png";

Vertex :: struct {
    pos         : V3,
    color       : V3,
    texCoord    : V2,
}

VERTICES : [8]Vertex = {
    {{-0.5, -0.5, 0.0}, {1.0, 0.0, 0.0}, {1.0, 0.0}},
    {{0.5, -0.5, 0.0}, {0.0, 1.0, 0.0}, {0.0, 0.0}},
    {{0.5, 0.5, 0.0}, {0.0, 0.0, 1.0}, {0.0, 1.0}},
    {{-0.5, 0.5, 0.0}, {1.0, 1.0, 1.0}, {1.0, 1.0}},

    {{-0.5, -0.5, -0.5}, {1.0, 0.0, 0.0}, {1.0, 0.0}},
    {{0.5, -0.5, -0.5}, {0.0, 1.0, 0.0}, {0.0, 0.0}},
    {{0.5, 0.5, -0.5}, {0.0, 0.0, 1.0}, {0.0, 1.0}},
    {{-0.5, 0.5, -0.5}, {1.0, 1.0, 1.0}, {1.0, 1.0}}
};

INDICES : [12]u16 = {
    0, 1, 2, 2, 3, 0,
    4, 5, 6, 6, 7, 4
};

vtxBindingDescription : vk.VertexInputBindingDescription = {
    binding = 0,
    stride = size_of(Vertex),
    inputRate = vk.VertexInputRate.Vertex,
};

vtxAttributeDescription : [3]vk.VertexInputAttributeDescription = {
    {
        binding = 0,
        location = 0,
        format = vk.Format.R32G32B32Sfloat,
        offset = u32(offset_of(Vertex, pos)),
    },
    {
        binding = 0,
        location = 1,
        format = vk.Format.R32G32B32Sfloat,
        offset = u32(offset_of(Vertex, color)),
    },
    {
        binding = 0,
        location = 2,
        format = vk.Format.R32G32Sfloat,
        offset = u32(offset_of(Vertex, texCoord)),
    }
};

UniformBufferObject :: struct {
    model   : M4,
    view    : M4,
    proj    : M4,
}
UBO : UniformBufferObject;

// Variables
window          : glfw.Window_Handle    = nil;
instance        : vk.Instance;
debugMessenger  : vk.DebugUtilsMessengerEXT;
surface         : vk.SurfaceKHR;
physicalDevice  : vk.PhysicalDevice;
device          : vk.Device;
graphicsQueue   : vk.Queue;
presentQueue    : vk.Queue;

// Swapchain
swapchain               : vk.SwapchainKHR;
swapchainImageCount     : int;
swapchainImages         : []vk.Image;
swapchainImageFormat    : vk.Format;
swapChainExtent         : vk.Extent2D;
swapChainImageViews     : []vk.ImageView;

renderPass              : vk.RenderPass;
descriptorSetLayout     : vk.DescriptorSetLayout;
pipelineLayout          : vk.PipelineLayout;
graphicsPipeline        : vk.Pipeline;
swapChainFramebuffers   : []vk.Framebuffer;

vertices                : []Vertex;
indices                 : []u32;
vertexBuffer            : vk.Buffer;
vertexBufferMemory      : vk.DeviceMemory;
indexBuffer             : vk.Buffer;
indexBufferMemory       : vk.DeviceMemory;
uniformBuffers          : []vk.Buffer;
uniformBuffersMemory    : []vk.DeviceMemory;

textureImage            : vk.Image;
textureImageMemory      : vk.DeviceMemory;
textureImageView        : vk.ImageView;
textureSampler          : vk.Sampler;

depthImage              : vk.Image;
depthImageMemory        : vk.DeviceMemory;
depthImageView          : vk.ImageView;

descriptorPool          : vk.DescriptorPool;
descriptorSets          : []vk.DescriptorSet;

commandPool             : vk.CommandPool;
commandBuffers          : []vk.CommandBuffer;

imageAvailableSemaphore : [MAX_FRAMES_IN_FLIGHT]vk.Semaphore;
renderFinishedSemaphore : [MAX_FRAMES_IN_FLIGHT]vk.Semaphore;
inFlightFences          : [MAX_FRAMES_IN_FLIGHT]vk.Fence;
currentFrame            : int;

framebufferResized      : bool;

QueueFamilyIndices :: struct {
    hasGraphics         : bool,
    hasPresenting       : bool,
    graphicsFamily      : u32,
    presentingFamily    : u32,
}

SwapchainCupportDetails :: struct {
    capabilities        : vk.SurfaceCapabilitiesKHR,
    formatCount         : int,
    formats             : []vk.SurfaceFormatKHR,
    presentModeCount    : int,
    presentModes        : []vk.PresentModeKHR,
}



//Procedures
main :: proc() {
    //logFile, error := os.open("log", os.O_CREATE | os.O_TRUNC, os.S_IRUSR | os.S_IWUSR | os.S_IRGRP | os.S_IWGRP | os.S_IROTH | os.S_IWOTH);
    //if error != 0 do log.panic("Error opening log file!", error);

    logger = log.create_console_logger(lowest = logLevel);
    defer log.destroy_console_logger(&logger);
    context.logger = logger;
    log.info("Succesfully created file logger!");

    initWindow();
    initVulkan();
    mainLoop();
    cleanup();
}

initWindow :: proc() {
    log.info("Initializing Window");
    glfw.Init();
    glfw.WindowHint(glfw.CLIENT_API, glfw.NO_API);
    glfw.WindowHint(glfw.RESIZABLE, glfw.FALSE);
    window = glfw.CreateWindow(i32(WIDTH), i32(HEIGHT), "Vulkan Tutorial", nil, nil);

    glfw.SetFramebufferSizeCallback(window, framebufferResizeCallback);
}

framebufferResizeCallback :: proc "c" (window : glfw.Window_Handle, width : i32, height : i32) {
    framebufferResized = true;
}

initVulkan :: proc() {
    log.info("Initializing Vulkan");
    createInstance();

}

createInstance :: proc() {
    log.info("Creating Instance");

    when VALIDATION_ENABLED {
        if !checkValidationLayerSupport() {
            log.panic("Validation Layers requested but not available!");
        }
    }

}

checkValidationLayerSupport :: proc() -> bool {
    log.info("Checking Validation Layer support");

    layerCount : u32;
    vk.enumerate_instance_layer_properties(&layerCount, nil);

    if layerCount == 0 {
        if len(ENABLED_LAYERS) == 0 do return true;
        else do return false;
    }

    availableLayers := make([]vk.LayerProperties, layerCount);
    defer delete(availableLayers);
    vk.enumerate_instance_layer_properties(&layerCount, &availableLayers[0]);

    for layerE in ENABLED_LAYERS {
        layerFound := false;
        for layerA in availableLayers {
            {
                lAName := arrayToCstring(layerA.layerName);
                defer arrayToCstring_delete(lAName);
                if layerE == lAName {
                    log.info("Layer found: ", layerE);
                    layerFound = true;
                    break;
                }
            }
        }
        if (!layerFound) {
            return false;
        }
    }
    return true;
}

mainLoop :: proc() {
    log.info("Main Loop");

    for glfw.WindowShouldClose(window) == 0 {
        glfw.PollEvents();
    }
}

cleanup :: proc() {
    log.info("Cleanup");

    glfw.DestroyWindow(window);
    glfw.Terminate();

}

// Utility
arrayToCstring :: proc(array: [256]c.char) -> (cs : cstring) {
    tmp := make([dynamic]byte);
    for i in 0..<256 {
        append(&tmp, byte(array[i]));
        if array[i] == '0' do break;
    }
    cs = cstring(&tmp[0]);
    log.debug("Created Cstring: ", cs);
    return;
}

// Instead of calling delete() directly, so creation and deletion are both logged
arrayToCstring_delete :: proc(cs : cstring) {
    log.debug("Deleting Cstring: ", cs);
    delete(cs);
}