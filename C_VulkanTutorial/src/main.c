#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <errno.h>
#include <memory.h>
#include <sys/stat.h>
#include <limits.h>
#include <math.h>
#include <time.h>

#include "libs/lodepng.h"
#define TINYOBJ_LOADER_C_IMPLEMENTATION
#include "libs/tinyobj_loader_c.h"

#define GLM_FORCE_RADIANS
#define GLM_FORCE_DEPTH_ZERO_TO_ONE
#include <cglm/cglm.h>

#define GLFW_INCLUDE_VULKAN
#include <GLFW/glfw3.h>

#include <vulkan/vulkan.h>

#define true 1
#define false 0

//#define DEBUG
#ifdef DEBUG
    #define DEBUG_PRINT(...) do{ fprintf( stderr, __VA_ARGS__ ); } while( 0 )
    const bool enableValidationLayers = true;
#else
    #define DEBUG_PRINT(...) do{ } while ( 0 )
    const bool enableValidationLayers = false;
#endif

//########################################################################

#define WIDTH 800
#define HEIGHT 600

#define MAX_FRAMES_IN_FLIGHT 2

#define VALIDATION_LAYER_COUNT 1
const char *validationLayers[] = {
    "VK_LAYER_LUNARG_standard_validation"
};
#define DEVICE_EXTENSION_COUNT 1
const char *deviceExtensions[] = {
    VK_KHR_SWAPCHAIN_EXTENSION_NAME
};

typedef struct Vertex {
    vec3 pos;
    vec3 color;
    vec2 texCoord;
} Vertex;

static VkVertexInputBindingDescription vtxBindingDescription = {
    .binding = 0,
    .stride = sizeof(Vertex),
    .inputRate = VK_VERTEX_INPUT_RATE_VERTEX
};
static VkVertexInputAttributeDescription vtxAttributeDescription[3] = {
    {
        .binding = 0,
        .location = 0,
        .format = VK_FORMAT_R32G32B32_SFLOAT,
        .offset = offsetof(Vertex, pos),
    },{
        .binding = 0,
        .location = 1,
        .format = VK_FORMAT_R32G32B32_SFLOAT,
        .offset = offsetof(Vertex, color),
    },{
        .binding = 0,
        .location = 2,
        .format = VK_FORMAT_R32G32_SFLOAT,
        .offset = offsetof(Vertex, texCoord),
    }
};

const char* MODEL_PATH = "assets/chalet.obj";
const char* TEXTURE_PATH = "assets/chalet.png";

const Vertex vertices[8] = {
    {{-0.5f, -0.5f, 0.0f}, {1.0f, 0.0f, 0.0f}, {1.0f, 0.0f}},
    {{0.5f, -0.5f, 0.0f}, {0.0f, 1.0f, 0.0f}, {0.0f, 0.0f}},
    {{0.5f, 0.5f, 0.0f}, {0.0f, 0.0f, 1.0f}, {0.0f, 1.0f}},
    {{-0.5f, 0.5f, 0.0f}, {1.0f, 1.0f, 1.0f}, {1.0f, 1.0f}},

    {{-0.5f, -0.5f, -0.5f}, {1.0f, 0.0f, 0.0f}, {1.0f, 0.0f}},
    {{0.5f, -0.5f, -0.5f}, {0.0f, 1.0f, 0.0f}, {0.0f, 0.0f}},
    {{0.5f, 0.5f, -0.5f}, {0.0f, 0.0f, 1.0f}, {0.0f, 1.0f}},
    {{-0.5f, 0.5f, -0.5f}, {1.0f, 1.0f, 1.0f}, {1.0f, 1.0f}}
};

const uint16_t indices[12] = {
    0, 1, 2, 2, 3, 0,
    4, 5, 6, 6, 7, 4
};

typedef struct UniformBufferObject {
    mat4 model;
    mat4 view;
    mat4 proj;
} UniformBufferObject;

struct Application {
    GLFWwindow *window;

    VkInstance instance;
    VkDebugUtilsMessengerEXT debugMessenger;
    VkSurfaceKHR surface;
    VkPhysicalDevice physicalDevice;
    VkDevice device;
    VkQueue graphicsQueue;
    VkQueue presentingQueue;

    VkSwapchainKHR swapChain;
    int swapChainImageCount;
    VkImage *swapChainImages;
    VkFormat swapChainImageFormat;
    VkExtent2D swapChainExtent;
    VkImageView *swapChainImageViews;

    VkRenderPass renderPass;
    VkDescriptorSetLayout descriptorSetLayout;
    VkPipelineLayout pipelineLayout;
    VkPipeline graphicsPipeline;
    VkFramebuffer *swapChainFramebuffers;

    VkDescriptorSetLayout descriptorSetLayoutCompute;
    VkPipelineLayout pipelineLayoutCompute;
    VkPipeline computePipeline;

    Vertex *vertices;
    uint32_t *indices;
    VkBuffer vertexBuffer;
    VkDeviceMemory vertexBufferMemory;

    VkBuffer indexBuffer;
    VkDeviceMemory indexBufferMemory;
    VkBuffer *uniformBuffers;
    VkDeviceMemory *uniformBuffersMemory;

    VkImage textureImage;
    VkDeviceMemory textureImageMemory;
    VkImageView textureImageView;
    VkSampler textureSampler;

    VkImage depthImage;
    VkDeviceMemory depthImageMemory;
    VkImageView depthImageView;

    VkDescriptorPool descriptorPool;
    VkDescriptorSet *descriptorSets;

    VkCommandPool commandPool;
    VkCommandBuffer *commandBuffers;

    VkSemaphore imageAvailableSemaphore[MAX_FRAMES_IN_FLIGHT];
    VkSemaphore renderFinishedSemaphore[MAX_FRAMES_IN_FLIGHT];
    VkFence inFlightFences[MAX_FRAMES_IN_FLIGHT];
    int currentFrame;

    bool framebufferResized;
} app;

struct QueueFamilyIndices {
    bool hasGraphics;
    bool hasPresenting;
    uint32_t graphicsFamily;
    uint32_t presentingFamily;
};

struct SwapChainSupportDetails {
    VkSurfaceCapabilitiesKHR capabilities;
    int formatCount;
    VkSurfaceFormatKHR *formats;
    int presentModeCount;
    VkPresentModeKHR *presentModes;
};

void app_initWindow();
static void framebufferResizeCallback(GLFWwindow* window, int width, int height);

void app_initVulkan();
void vk_createInstance();
void vk_setupDebugMessenger();

void vk_createSurface();

bool vk_checkValidationLayerSupport();
uint32_t vk_getRequiredExtensions(const char ***requiredeExtensions);
static VKAPI_ATTR VkBool32 VKAPI_CALL debugCallback(
    VkDebugUtilsMessageSeverityFlagBitsEXT messageSeverity,
    VkDebugUtilsMessageTypeFlagsEXT messageType,
    const VkDebugUtilsMessengerCallbackDataEXT* pCallbackData,
    void* pUserData);
VkResult CreateDebugUtilsMessengerEXT(VkInstance instance, const VkDebugUtilsMessengerCreateInfoEXT* pCreateInfo, const VkAllocationCallbacks* pAllocator, VkDebugUtilsMessengerEXT* pDebugMessenger);
void DestroyDebugUtilsMessengerEXT(VkInstance instance, VkDebugUtilsMessengerEXT debugMessenger, const VkAllocationCallbacks* pAllocator);

void vk_pickPhysicalDevice();
bool vk_isDeviceSuitable(VkPhysicalDevice device);
// int vk_rateDeviceSuitability(VkPhysicalDevice device);
bool vk_checkDeviceExtensionSupport(VkPhysicalDevice device);
struct QueueFamilyIndices vk_findQueueFamilies(VkPhysicalDevice device);
void vk_createLogicalDevice();

struct SwapChainSupportDetails vk_querySwapChainSupport(VkPhysicalDevice device);
struct VkSurfaceFormatKHR vk_chooseSwapSurfaceFormat(VkSurfaceFormatKHR *availableFormats, int formatCount);
enum VkPresentModeKHR vk_chooseSwapPresentMode(VkPresentModeKHR *availablePresentModes, int presentModeCount);
struct VkExtent2D vk_chooseSwapExtent(const VkSurfaceCapabilitiesKHR capabilities);
void vk_createSwapChain();
void vk_recreateSwapChain();
void vk_cleanupSwapChain();
VkImageView vk_createImageView(VkImage image, VkFormat format, VkImageAspectFlags aspectFlags);
void vk_createImageViews();

void vk_createRenderPass();
void vk_createDescriptorSetLayout();
void vk_createGraphicsPipeline();
VkShaderModule vk_createShaderModule(const unsigned char* code, int codeSize);
void vk_createFramebuffers();

void vk_createDescriptorSetLayoutCompute();
void vk_createComputePipeline();

uint32_t vk_findMemoryType(uint32_t typeFilter, VkMemoryPropertyFlags properties);

void vk_createBuffer(
    VkDeviceSize size, VkBufferUsageFlags usage, VkMemoryPropertyFlags properties,
    VkBuffer *buffer, VkDeviceMemory *bufferMemory);
void vk_createVertexBuffer();
void vk_createIndexBuffer();
void vk_createUniformBuffers();
void vk_createDescriptorPool();
void vk_createDescriptorSets();
void vk_copyBuffer(VkBuffer srcBuffer, VkBuffer dstBuffer, VkDeviceSize size);
VkCommandBuffer vk_beginSingleTimeCommands();
void vk_endSingleTimeCommands(VkCommandBuffer commandBuffer);

void vk_copyBufferToImage(VkBuffer buffer, VkImage image, uint32_t width, uint32_t height);
void vk_transitionImageLayout(VkImage image, VkFormat format, VkImageLayout oldLayout, VkImageLayout newLayout);

void vk_createDepthResource();

void vk_createTextureImage();
void vk_createTextureImageView();
void vk_createTextureSampler();
void vk_createImage(uint32_t width, uint32_t height, VkFormat format, VkImageTiling tiling,
    VkImageUsageFlags usage, VkMemoryPropertyFlags properties, VkImage *image, VkDeviceMemory * imageMemory);

void vk_createCommandPool();
void vk_createCommandBuffers();

void vk_updateUniformBuffer(uint32_t currentImage);
void vk_drawFrame();
void vk_createSyncObjects();

int readFile(const char* fileName, const unsigned char** dst);
static unsigned getFileSize (const char * file_name);

void loadModel();

void app_mainLoop();
void app_cleanup();

int run_app(){
    DEBUG_PRINT("run_app\n");
    app_initWindow(app);
    app_initVulkan(app);
    app_mainLoop(app);
    app_cleanup(app);
    return 0;
}

int main() {
    app.currentFrame = 0;
    app.framebufferResized = false;
    return run_app(&app);
}
//#########################################################################

void app_initWindow() {
    DEBUG_PRINT("app_initWindow\n");

    glfwInit();
    glfwWindowHint(GLFW_CLIENT_API, GLFW_NO_API);
    //glfwWindowHint(GLFW_RESIZABLE, GLFW_FALSE);
    app.window = glfwCreateWindow(WIDTH, HEIGHT, "Vulkan", NULL, NULL);

    glfwSetWindowUserPointer(app.window, &app);
    glfwSetFramebufferSizeCallback(app.window, framebufferResizeCallback);
}

static void framebufferResizeCallback(GLFWwindow* window, int width, int height) {
    struct Application *pApp = glfwGetWindowUserPointer(app.window);
    pApp->framebufferResized = true;
}

void app_initVulkan() {
    DEBUG_PRINT("app_initVulkan\n");
    vk_createInstance();
    vk_setupDebugMessenger();
    vk_createSurface();

    vk_pickPhysicalDevice();
    vk_createLogicalDevice();

    vk_createSwapChain();
    vk_createImageViews();

    vk_createRenderPass();
    vk_createDescriptorSetLayout();
    vk_createGraphicsPipeline();
    vk_createCommandPool();
    vk_createDepthResource();
    vk_createFramebuffers();

    vk_createTextureImage();
    vk_createTextureImageView();
    vk_createTextureSampler();

    loadModel();

    vk_createVertexBuffer();
    vk_createIndexBuffer();
    vk_createUniformBuffers();
    vk_createDescriptorPool();
    vk_createDescriptorSets();

    vk_createSyncObjects();
    vk_createCommandBuffers();
}

void vk_createInstance(){
    DEBUG_PRINT("vk_createInstance\n");
    if(enableValidationLayers && !vk_checkValidationLayerSupport()){
        perror("Validation Layer requested, but not available!");
        exit(EXIT_FAILURE);
    }

    //Optional; for optimization
    VkApplicationInfo appInfo = {};
    appInfo.sType = VK_STRUCTURE_TYPE_APPLICATION_INFO;
    appInfo.pApplicationName = "Hello Triangle";
    appInfo.applicationVersion = VK_MAKE_VERSION(1, 0, 0);
    appInfo.pEngineName = "No Engine";
    appInfo.engineVersion = VK_MAKE_VERSION(1, 0, 0);
    appInfo.apiVersion = VK_API_VERSION_1_0;

    //not optional
    VkInstanceCreateInfo createInfo = {};
    createInfo.sType = VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO;
    createInfo.pApplicationInfo = &appInfo;

    //extensions required for window creation
    uint32_t glfwExtensionCount = 0;
    const char** glfwExtensions;
    glfwExtensionCount = vk_getRequiredExtensions(&glfwExtensions);

    createInfo.enabledExtensionCount = glfwExtensionCount;
    createInfo.ppEnabledExtensionNames = glfwExtensions;

    if(enableValidationLayers){
        createInfo.enabledLayerCount = VALIDATION_LAYER_COUNT;
        createInfo.ppEnabledLayerNames = validationLayers;
    } else {
        createInfo.enabledLayerCount = 0;
    }
    
    if(vkCreateInstance(&createInfo, NULL, &app.instance) != VK_SUCCESS) {
        perror("Unable to create Vulkan Instance");
        exit(EXIT_FAILURE);
    }
}

void vk_setupDebugMessenger(){
    if(!enableValidationLayers) return;

    VkDebugUtilsMessengerCreateInfoEXT createInfo = {};
    createInfo.sType = VK_STRUCTURE_TYPE_DEBUG_UTILS_MESSENGER_CREATE_INFO_EXT;
    createInfo.messageSeverity = VK_DEBUG_UTILS_MESSAGE_SEVERITY_VERBOSE_BIT_EXT | VK_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT | VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT;
    createInfo.messageType = VK_DEBUG_UTILS_MESSAGE_TYPE_GENERAL_BIT_EXT | VK_DEBUG_UTILS_MESSAGE_TYPE_VALIDATION_BIT_EXT | VK_DEBUG_UTILS_MESSAGE_TYPE_PERFORMANCE_BIT_EXT;
    createInfo.pfnUserCallback = debugCallback;
    createInfo.pUserData = NULL; // optional

    if (CreateDebugUtilsMessengerEXT(app.instance, &createInfo, NULL, &app.debugMessenger) != VK_SUCCESS) {
        perror("failed to set up debug messenger!");
    }
}

VkResult CreateDebugUtilsMessengerEXT(VkInstance instance, const VkDebugUtilsMessengerCreateInfoEXT* pCreateInfo, const VkAllocationCallbacks* pAllocator, VkDebugUtilsMessengerEXT* pDebugMessenger) {
    PFN_vkCreateDebugUtilsMessengerEXT func = (PFN_vkCreateDebugUtilsMessengerEXT) vkGetInstanceProcAddr(instance, "vkCreateDebugUtilsMessengerEXT");
    if (func != NULL) {
        return func(instance, pCreateInfo, pAllocator, pDebugMessenger);
    } else {
        return VK_ERROR_EXTENSION_NOT_PRESENT;
    }
}

void DestroyDebugUtilsMessengerEXT(VkInstance instance, VkDebugUtilsMessengerEXT debugMessenger, const VkAllocationCallbacks* pAllocator) {
    PFN_vkDestroyDebugUtilsMessengerEXT func = (PFN_vkDestroyDebugUtilsMessengerEXT) vkGetInstanceProcAddr(instance, "vkDestroyDebugUtilsMessengerEXT");
    if (func != NULL) {
        func(instance, debugMessenger, pAllocator);
    }
}

void vk_createSurface(){
    if (glfwCreateWindowSurface(app.instance, app.window, NULL, &app.surface) != VK_SUCCESS) {
        perror("failed to create window surface!");
        exit(EXIT_FAILURE);
    }
}

bool vk_checkValidationLayerSupport(){
    DEBUG_PRINT("vk_checkValidationLayerSupport\n");
    uint32_t layerCount = 0;
    vkEnumerateInstanceLayerProperties(&layerCount, NULL);
    VkLayerProperties *availableLayers = calloc(layerCount, sizeof(VkLayerProperties));
    vkEnumerateInstanceLayerProperties(&layerCount, availableLayers);

    for(int i = 0; i < VALIDATION_LAYER_COUNT; i++){
        bool layerFound = false;
        for (int j = 0; j < layerCount; ++j)
        {
            if(strcmp(validationLayers[i], availableLayers[j].layerName) == 0) {
                printf("+%s\n-%s", validationLayers[i], availableLayers[j].layerName);
                layerFound = true;
                break;
            }
        }
        if (!layerFound){
            free(availableLayers);
            return false;
        }
    }
    free(availableLayers);
    return true;
}

static VKAPI_ATTR VkBool32 VKAPI_CALL debugCallback(
    VkDebugUtilsMessageSeverityFlagBitsEXT messageSeverity,
    VkDebugUtilsMessageTypeFlagsEXT messageType,
    const VkDebugUtilsMessengerCallbackDataEXT* pCallbackData,
    void* pUserData){

    printf("Validation Layer: %s", pCallbackData->pMessage);
    return VK_FALSE;
}

uint32_t vk_getRequiredExtensions(const char ***requiredExtensions) {
    uint32_t glfwExtensionCount = 0;
    const char **glfwExtensions;
    glfwExtensions = glfwGetRequiredInstanceExtensions(&glfwExtensionCount);

    if(enableValidationLayers){
        const char **newGlfwExtensions = calloc(++glfwExtensionCount, sizeof(char*));
        for (int i = 0; i < glfwExtensionCount -1; ++i){
             newGlfwExtensions[i] = glfwExtensions[i];
        }
        newGlfwExtensions[glfwExtensionCount - 1] = VK_EXT_DEBUG_UTILS_EXTENSION_NAME;
        *requiredExtensions = newGlfwExtensions;
    }else{
        *requiredExtensions = glfwExtensions;
    }
    return glfwExtensionCount;
}

void vk_pickPhysicalDevice() {
    DEBUG_PRINT("vk_pickPhysicalDevice\n");
    uint32_t deviceCount = 0;
    vkEnumeratePhysicalDevices(app.instance, &deviceCount, NULL);

    if(deviceCount == 0) {
        perror("Failed to find GPUs with Vulkan support!");
        exit(EXIT_FAILURE);
    }

    VkPhysicalDevice *devices = calloc(deviceCount, sizeof(VkPhysicalDevice));
    vkEnumeratePhysicalDevices(app.instance, &deviceCount, devices);

    for(int i = 0; i < deviceCount; i++) {
        if (vk_isDeviceSuitable(devices[i])){
            app.physicalDevice = devices[i];
            break;
        }
    }

    free(devices);
    
    if(app.physicalDevice == VK_NULL_HANDLE) {
        perror("Failed to find a suitable GPU!");
        exit(EXIT_FAILURE);
    }
}

bool vk_isDeviceSuitable(VkPhysicalDevice device) {
    DEBUG_PRINT("vk_isDeviceSuitable\n");
    VkPhysicalDeviceProperties deviceProperties;
    VkPhysicalDeviceFeatures deviceFeatures;
    vkGetPhysicalDeviceProperties(device, &deviceProperties);
    vkGetPhysicalDeviceFeatures(device, &deviceFeatures);
    //select wanted features and return accordingly

    struct QueueFamilyIndices indices = vk_findQueueFamilies(device);
    bool extensionsSupported = vk_checkDeviceExtensionSupport(device);

    bool swapChainAdequat = false;
    if(extensionsSupported){
        struct SwapChainSupportDetails swapChainSupport = vk_querySwapChainSupport(device);
        swapChainAdequat = swapChainSupport.presentModeCount && swapChainSupport.formatCount;
    }

    return indices.hasGraphics && indices.hasPresenting 
        && extensionsSupported && swapChainAdequat && deviceFeatures.samplerAnisotropy;
}

/*
int vk_rateDeviceSuitability(VkPhysicalDevice device) {
    int score = 0;
    return score;
}*/

bool vk_checkDeviceExtensionSupport(VkPhysicalDevice device) {
    DEBUG_PRINT("vk_checkDeviceExtensionSupport\n");
    uint32_t extensionCount;
    vkEnumerateDeviceExtensionProperties(device, NULL, &extensionCount, NULL);

    VkExtensionProperties *availableExtensions = calloc(extensionCount, sizeof(VkExtensionProperties));
    vkEnumerateDeviceExtensionProperties(device, NULL, &extensionCount, availableExtensions);

    for (int i = 0; i < DEVICE_EXTENSION_COUNT; ++i) {
        bool extensionFound = false;
        for (int j = 0; j < extensionCount; ++j) {
            extensionFound = strcmp(deviceExtensions[i], availableExtensions[j].extensionName);
            if(extensionFound) break;
        }
        if(!extensionFound) {
            free(availableExtensions);
            return false;
        }
    }

    free(availableExtensions);
    return true;
}

struct SwapChainSupportDetails vk_querySwapChainSupport(VkPhysicalDevice device) {
    DEBUG_PRINT("vk_querySwapChainSupport\n");
    struct SwapChainSupportDetails details;

    vkGetPhysicalDeviceSurfaceCapabilitiesKHR(device, app.surface, &details.capabilities);

    vkGetPhysicalDeviceSurfaceFormatsKHR(device, app.surface, &details.formatCount, NULL);
    if (details.formatCount != 0) {
        details.formats = calloc(details.formatCount, sizeof(VkSurfaceFormatKHR));
        vkGetPhysicalDeviceSurfaceFormatsKHR(device, app.surface, &details.formatCount, details.formats);
    }

    vkGetPhysicalDeviceSurfacePresentModesKHR(device, app.surface, &details.presentModeCount, NULL);
    if (details.presentModeCount != 0) {
        details.presentModes = calloc(details.presentModeCount, sizeof(VkPresentModeKHR));
        vkGetPhysicalDeviceSurfacePresentModesKHR(device, app.surface, &details.presentModeCount, details.presentModes);
    }

    return details;
}

struct VkSurfaceFormatKHR vk_chooseSwapSurfaceFormat(VkSurfaceFormatKHR *availableFormats, int formatCount){
    DEBUG_PRINT("vk_chooseSwapSurfaceFormat\n");
    if(formatCount == 1 && availableFormats[0].format == VK_FORMAT_UNDEFINED) {
        struct VkSurfaceFormatKHR format = {VK_FORMAT_B8G8R8A8_UNORM, VK_COLOR_SPACE_SRGB_NONLINEAR_KHR};
        return format;
    }
    for(int i = 0; i < formatCount; i++) {
        if (availableFormats[i].format == VK_FORMAT_B8G8R8A8_UNORM && availableFormats[i].colorSpace == VK_COLOR_SPACE_SRGB_NONLINEAR_KHR){
            return availableFormats[i];
        }
    }
    return availableFormats[0];
}

enum VkPresentModeKHR vk_chooseSwapPresentMode(VkPresentModeKHR *availablePresentModes, int presentModeCount) {
    DEBUG_PRINT("vk_chooseSwapPresentMode\n");
    for(int i = 0; i < presentModeCount; i++) {
        if (availablePresentModes[i] == VK_PRESENT_MODE_MAILBOX_KHR) {
            return availablePresentModes[i];
        }
    }

    return VK_PRESENT_MODE_FIFO_KHR;
}

struct VkExtent2D vk_chooseSwapExtent(const VkSurfaceCapabilitiesKHR capabilities){
    DEBUG_PRINT("vk_chooseSwapExtent\n");
    if (capabilities.currentExtent.width != UINT32_MAX) {
        return capabilities.currentExtent;
    } else {
        int width, height;
        glfwGetFramebufferSize(app.window, &width, &height);
        VkExtent2D actualExtent = {(uint32_t)width, (uint32_t) height};

        actualExtent.width = capabilities.maxImageExtent.width < actualExtent.width ? capabilities.maxImageExtent.width : actualExtent.width;
        actualExtent.width = actualExtent.width > capabilities.minImageExtent.width ? actualExtent.width : capabilities.minImageExtent.width;

        actualExtent.height = capabilities.maxImageExtent.height < actualExtent.height ? capabilities.maxImageExtent.height : actualExtent.height;
        actualExtent.height = actualExtent.height > capabilities.minImageExtent.height ? actualExtent.height : capabilities.minImageExtent.height;
        return actualExtent;
    }
}


struct QueueFamilyIndices vk_findQueueFamilies(VkPhysicalDevice device) {
    DEBUG_PRINT("vk_findQueueFamilies\n");
    struct QueueFamilyIndices indices;

    uint32_t queueFamilyCount = 0;
    vkGetPhysicalDeviceQueueFamilyProperties(device, &queueFamilyCount, NULL);

    VkQueueFamilyProperties *queueFamilies = calloc(queueFamilyCount, sizeof(VkQueueFamilyProperties));
    vkGetPhysicalDeviceQueueFamilyProperties(device, &queueFamilyCount, queueFamilies);

    int i = 0;
    for (int j = 0; j < queueFamilyCount; j++) {
        if (queueFamilies[j].queueCount > 0 && queueFamilies[j].queueFlags & VK_QUEUE_GRAPHICS_BIT) {
            indices.graphicsFamily = i;
            indices.hasGraphics = true;
        }

        VkBool32 presentSupport = false;
        vkGetPhysicalDeviceSurfaceSupportKHR(device, i, app.surface, &presentSupport);

        if (queueFamilies[j].queueCount > 0 && presentSupport) {
            indices.presentingFamily = i;
            indices.hasPresenting = true;
        }

        if (indices.hasGraphics && indices.hasPresenting) {
            break;
        }

        i++;
    }

    free(queueFamilies);
    return indices;
}

void vk_createLogicalDevice() {
    DEBUG_PRINT("vk_createLogicalDevice\n");
    struct QueueFamilyIndices indices = vk_findQueueFamilies(app.physicalDevice);

    int infoCount = 1;
    VkDeviceQueueCreateInfo *queueCreateInfos = calloc(1, sizeof(VkDeviceQueueCreateInfo));
  
    VkDeviceQueueCreateInfo queueCreateInfo = {};
    queueCreateInfo.sType = VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO;
    queueCreateInfo.queueFamilyIndex = indices.graphicsFamily;
    queueCreateInfo.queueCount = 1;
    float queuePriority = 1.0f;
    queueCreateInfo.pQueuePriorities = &queuePriority;

    queueCreateInfos[0] = queueCreateInfo;

    if (indices.graphicsFamily != indices.presentingFamily) {
        infoCount = 2;
        queueCreateInfos = realloc(queueCreateInfos, 2 * sizeof(VkDeviceQueueCreateInfo));
    
        VkDeviceQueueCreateInfo queueCreateInfo = {};
        queueCreateInfo.sType = VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO;
        queueCreateInfo.queueFamilyIndex = indices.presentingFamily;
        queueCreateInfo.queueCount = 1;
        float queuePriority = 1.0f;
        queueCreateInfo.pQueuePriorities = &queuePriority;

        queueCreateInfos[1] = queueCreateInfo;
    }

    VkPhysicalDeviceFeatures deviceFeatures = {
        .samplerAnisotropy = VK_TRUE
    };
    VkDeviceCreateInfo createInfo = {};
    createInfo.sType = VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO;
    createInfo.pQueueCreateInfos = queueCreateInfos;
    createInfo.queueCreateInfoCount = infoCount;

    createInfo.pEnabledFeatures = &deviceFeatures;

    createInfo.enabledExtensionCount = DEVICE_EXTENSION_COUNT;
    createInfo.ppEnabledExtensionNames = deviceExtensions;

    if (enableValidationLayers) {
        createInfo.enabledLayerCount = VALIDATION_LAYER_COUNT;
        createInfo.ppEnabledLayerNames = validationLayers;
    } else {
        createInfo.enabledLayerCount = 0;
    }

    if (vkCreateDevice(app.physicalDevice, &createInfo, NULL, &app.device) != VK_SUCCESS) {
        perror("failed to create logical device!");
        exit(EXIT_FAILURE);
    }

    vkGetDeviceQueue(app.device, indices.graphicsFamily, 0, &app.graphicsQueue);
    vkGetDeviceQueue(app.device, indices.presentingFamily, 0, &app.presentingQueue);

    free(queueCreateInfos);
}

void vk_createSwapChain() {
    DEBUG_PRINT("vk_createSwapChain\n");
    struct SwapChainSupportDetails swapChainSupport = vk_querySwapChainSupport(app.physicalDevice);

    VkSurfaceFormatKHR surfaceFormat = vk_chooseSwapSurfaceFormat(swapChainSupport.formats, swapChainSupport.formatCount);
    VkPresentModeKHR presentMode = vk_chooseSwapPresentMode(swapChainSupport.presentModes, swapChainSupport.presentModeCount);
    VkExtent2D extent = vk_chooseSwapExtent(swapChainSupport.capabilities);

    uint32_t imageCount = swapChainSupport.capabilities.minImageCount + 1;
    if (swapChainSupport.capabilities.maxImageCount > 0 && imageCount > swapChainSupport.capabilities.maxImageCount) {
        imageCount = swapChainSupport.capabilities.maxImageCount;
    }

    struct VkSwapchainCreateInfoKHR createInfo = {};
    createInfo.sType = VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR;
    createInfo.surface = app.surface;
    createInfo.minImageCount = imageCount;
    createInfo.imageFormat = surfaceFormat.format;
    createInfo.imageColorSpace = surfaceFormat.colorSpace;
    createInfo.imageExtent = extent;
    createInfo.imageArrayLayers = 1;
    createInfo.imageUsage = VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT;

    struct QueueFamilyIndices indices = vk_findQueueFamilies(app.physicalDevice);
    uint32_t queueFamilyIndices[] = {indices.graphicsFamily, indices.presentingFamily};

    if (indices.graphicsFamily != indices.presentingFamily) {
        createInfo.imageSharingMode = VK_SHARING_MODE_CONCURRENT;
        createInfo.queueFamilyIndexCount = 2;
        createInfo.pQueueFamilyIndices = queueFamilyIndices;
    } else {
        createInfo.imageSharingMode = VK_SHARING_MODE_EXCLUSIVE;
        createInfo.queueFamilyIndexCount = 0; // Optional
        createInfo.pQueueFamilyIndices = NULL; // Optional
    }

    createInfo.preTransform = swapChainSupport.capabilities.currentTransform;
    createInfo.compositeAlpha = VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR;
    createInfo.presentMode = presentMode;
    createInfo.clipped = VK_TRUE;
    createInfo.oldSwapchain = VK_NULL_HANDLE;

    if (vkCreateSwapchainKHR(app.device, &createInfo, NULL, &app.swapChain) != VK_SUCCESS) {
        perror("failed to create swapchain!");
        exit(EXIT_FAILURE);
    }

    vkGetSwapchainImagesKHR(app.device, app.swapChain, &imageCount, NULL);
    app.swapChainImageCount = imageCount;
    app.swapChainImages = calloc(imageCount, sizeof(VkImage));
    vkGetSwapchainImagesKHR(app.device, app.swapChain, &imageCount, app.swapChainImages);

    app.swapChainImageFormat = surfaceFormat.format;
    app.swapChainExtent = extent;

}

void vk_recreateSwapChain(){
    DEBUG_PRINT("vk_recreateSwapChain");
    int width = 0, height = 0;
    while (width == 0 || height == 0) {
        glfwGetFramebufferSize(app.window, &width, &height);
        glfwWaitEvents();
    }

    vkDeviceWaitIdle(app.device);

    vk_cleanupSwapChain();

    vk_createSwapChain();
    vk_createImageViews();
    vk_createRenderPass();
    vk_createGraphicsPipeline();
    vk_createDepthResource();
    vk_createFramebuffers();
    vk_createUniformBuffers();
    vk_createDescriptorPool();
    vk_createDescriptorSets();
    vk_createCommandBuffers();
}

void vk_cleanupSwapChain(){
    DEBUG_PRINT("vk_cleanupSwapChain");

    vkDestroyImageView(app.device, app.depthImageView, NULL);
    vkDestroyImage(app.device, app.depthImage, NULL);
    vkFreeMemory(app.device, app.depthImageMemory, NULL);

    for(int i = 0; i < app.swapChainImageCount; i++){
        vkDestroyFramebuffer(app.device, app.swapChainFramebuffers[i], NULL);
    }

    vkFreeCommandBuffers(app.device, app.commandPool, (uint32_t) app.swapChainImageCount, app.commandBuffers);

    vkDestroyPipeline(app.device, app.graphicsPipeline, NULL);
    vkDestroyPipelineLayout(app.device, app.pipelineLayout, NULL);
    vkDestroyRenderPass(app.device, app.renderPass, NULL);

    for(int i = 0; i < app.swapChainImageCount; i++){
        vkDestroyImageView(app.device, app.swapChainImageViews[i], NULL);
    }
    free(app.swapChainImageViews);
    free(app.swapChainImages);

    vkDestroySwapchainKHR(app.device, app.swapChain, NULL);

    for (int i = 0; i < app.swapChainImageCount; ++i){
        vkDestroyBuffer(app.device, app.uniformBuffers[i], NULL);
        vkFreeMemory(app.device, app.uniformBuffersMemory[i], NULL);
    }

    vkDestroyDescriptorPool(app.device, app.descriptorPool, NULL);
}

void vk_createImageViews() {
    DEBUG_PRINT("vk_createImageViews\n");
    app.swapChainImageViews = calloc(app.swapChainImageCount, sizeof(VkImageView));

    for(int i = 0; i < app.swapChainImageCount; i++) {
        app.swapChainImageViews[i] = vk_createImageView(app.swapChainImages[i], app.swapChainImageFormat, VK_IMAGE_ASPECT_COLOR_BIT);
    }
}

void vk_createRenderPass() {
    DEBUG_PRINT("vk_createRenderPass\n");
    VkAttachmentDescription colorAttachment = {};
    colorAttachment.format = app.swapChainImageFormat;
    colorAttachment.samples = VK_SAMPLE_COUNT_1_BIT;
    colorAttachment.loadOp = VK_ATTACHMENT_LOAD_OP_CLEAR;
    colorAttachment.storeOp = VK_ATTACHMENT_STORE_OP_STORE;
    colorAttachment.stencilLoadOp = VK_ATTACHMENT_LOAD_OP_DONT_CARE;
    colorAttachment.stencilStoreOp = VK_ATTACHMENT_STORE_OP_DONT_CARE;
    colorAttachment.initialLayout = VK_IMAGE_LAYOUT_UNDEFINED;
    colorAttachment.finalLayout = VK_IMAGE_LAYOUT_PRESENT_SRC_KHR;

    VkAttachmentReference colorAttachmentRef = {};
    colorAttachmentRef.attachment = 0;
    colorAttachmentRef.layout = VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL;

    VkAttachmentDescription depthAttachment = {};
    depthAttachment.format = VK_FORMAT_D32_SFLOAT;
    depthAttachment.samples = VK_SAMPLE_COUNT_1_BIT;
    depthAttachment.loadOp = VK_ATTACHMENT_LOAD_OP_CLEAR;
    depthAttachment.storeOp = VK_ATTACHMENT_STORE_OP_DONT_CARE;
    depthAttachment.stencilLoadOp = VK_ATTACHMENT_LOAD_OP_DONT_CARE;
    depthAttachment.stencilStoreOp = VK_ATTACHMENT_STORE_OP_DONT_CARE;
    depthAttachment.initialLayout = VK_IMAGE_LAYOUT_UNDEFINED;
    depthAttachment.finalLayout = VK_IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL;

    VkAttachmentReference depthAttachmentRef = {};
    depthAttachmentRef.attachment = 1;
    depthAttachmentRef.layout = VK_IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL;

    VkSubpassDescription subpass = {};
    subpass.pipelineBindPoint = VK_PIPELINE_BIND_POINT_GRAPHICS;
    subpass.colorAttachmentCount = 1;
    subpass.pColorAttachments = &colorAttachmentRef;
    subpass.pDepthStencilAttachment = &depthAttachmentRef;

    VkAttachmentDescription attachments[2] = {colorAttachment, depthAttachment};

    VkRenderPassCreateInfo renderPassInfo = {};
    renderPassInfo.sType = VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO;
    renderPassInfo.attachmentCount = 2;
    renderPassInfo.pAttachments = attachments;
    renderPassInfo.subpassCount = 1;
    renderPassInfo.pSubpasses = &subpass;

    VkSubpassDependency dependency = {};
    dependency.srcSubpass = VK_SUBPASS_EXTERNAL;
    dependency.dstSubpass = 0;

    dependency.srcStageMask = VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT;
    dependency.srcAccessMask = 0;

    dependency.dstStageMask = VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT;
    dependency.dstAccessMask = VK_ACCESS_COLOR_ATTACHMENT_READ_BIT | VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT;

    renderPassInfo.dependencyCount = 1;
    renderPassInfo.pDependencies = &dependency;

    if (vkCreateRenderPass(app.device, &renderPassInfo, NULL, &app.renderPass) != VK_SUCCESS) {
        perror("failed to create render pass!");
        exit(EXIT_FAILURE);
    }
}

void vk_createDescriptorSetLayout(){
    DEBUG_PRINT("vk_createDescriptorSetLayout");
    VkDescriptorSetLayoutBinding uboLayoutBinding = {};
    uboLayoutBinding.binding = 0;
    uboLayoutBinding.descriptorType = VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER;
    uboLayoutBinding.descriptorCount = 1;
    uboLayoutBinding.stageFlags = VK_SHADER_STAGE_VERTEX_BIT;
    uboLayoutBinding.pImmutableSamplers = NULL;//optional

    VkDescriptorSetLayoutBinding samplerLayoutBinding = {};
    samplerLayoutBinding.binding = 1;
    samplerLayoutBinding.descriptorCount = 1;
    samplerLayoutBinding.descriptorType = VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER;
    samplerLayoutBinding.pImmutableSamplers = NULL;
    samplerLayoutBinding.stageFlags = VK_SHADER_STAGE_FRAGMENT_BIT;

    VkDescriptorSetLayoutBinding bindings[2] = {uboLayoutBinding, samplerLayoutBinding};

    VkDescriptorSetLayoutCreateInfo layoutInfo = {};
    layoutInfo.sType = VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO;
    layoutInfo.bindingCount = 2;
    layoutInfo.pBindings = bindings;

    if (vkCreateDescriptorSetLayout(app.device, &layoutInfo, NULL, &app.descriptorSetLayout) != VK_SUCCESS){
        perror("failed to create descriptor set layout!");
        exit(EXIT_FAILURE);
    }
}

void vk_createDescriptorSetLayoutCompute(){
    DEBUG_PRINT("vk_createDescriptorSetLayout");
    VkDescriptorSetLayoutBinding inLayoutBinding = {
        .binding = 0,
        .descriptorType = VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER,
    };

    VkDescriptorSetLayoutBinding outLayoutBinding = {

    };

    VkDescriptorSetLayoutBinding bindings[2] = {inLayoutBinding, outLayoutBinding};

    VkDescriptorSetLayoutCreateInfo layoutInfo = {};
    layoutInfo.sType = VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO;
    layoutInfo.bindingCount = 2;
    layoutInfo.pBindings = bindings;

    if (vkCreateDescriptorSetLayout(app.device, &layoutInfo, NULL, &app.descriptorSetLayout) != VK_SUCCESS){
        perror("failed to create descriptor set layout!");
        exit(EXIT_FAILURE);
    }
}

void vk_createGraphicsPipeline() {
    DEBUG_PRINT("vk_createGraphicsPipeline\n");

    const unsigned char *vertShaderCode;
    int vertShaderSize = readFile("src/shaders/vert.spv", &vertShaderCode);
    
    const unsigned char *fragShaderCode;
    int fragShaderSize =readFile("src/shaders/frag.spv", &fragShaderCode);

    VkShaderModule vertShaderModule = vk_createShaderModule((const unsigned char*) vertShaderCode, vertShaderSize);
    VkShaderModule fragShaderModule = vk_createShaderModule((const unsigned char*) fragShaderCode, fragShaderSize);

    //Vertex
    VkPipelineShaderStageCreateInfo vertShaderStageInfo = {};
    vertShaderStageInfo.sType = VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO;
    vertShaderStageInfo.stage = VK_SHADER_STAGE_VERTEX_BIT;
    vertShaderStageInfo.module = vertShaderModule;
    vertShaderStageInfo.pName = "main";
    //Fragment
    VkPipelineShaderStageCreateInfo fragShaderStageInfo = {};
    fragShaderStageInfo.sType = VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO;
    fragShaderStageInfo.stage = VK_SHADER_STAGE_FRAGMENT_BIT;
    fragShaderStageInfo.module = fragShaderModule;
    fragShaderStageInfo.pName = "main";

    VkPipelineShaderStageCreateInfo shaderStages[] = {vertShaderStageInfo, fragShaderStageInfo};

    VkPipelineVertexInputStateCreateInfo vertexInputInfo = {};
    vertexInputInfo.sType = VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO;
    vertexInputInfo.vertexBindingDescriptionCount = 1;
    vertexInputInfo.pVertexBindingDescriptions = &vtxBindingDescription;
    vertexInputInfo.vertexAttributeDescriptionCount = 3;
    vertexInputInfo.pVertexAttributeDescriptions = vtxAttributeDescription;

    VkPipelineInputAssemblyStateCreateInfo inputAssembly = {};
    inputAssembly.sType = VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO;
    inputAssembly.topology = VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST;
    inputAssembly.primitiveRestartEnable = VK_FALSE;

    //Viewport
    VkViewport viewport = {};
    viewport.x = 0.0f;
    viewport.y = 0.0f;
    viewport.width = (float) app.swapChainExtent.width;
    viewport.height = (float) app.swapChainExtent.height;
    viewport.minDepth = 0.0f;
    viewport.maxDepth = 1.0f;
    //Scissor
    VkRect2D scissor = {};
    VkOffset2D offset = {0, 0};
    scissor.offset = offset;
    scissor.extent = app.swapChainExtent;

    VkPipelineViewportStateCreateInfo viewportState = {};
    viewportState.sType = VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO;
    viewportState.viewportCount = 1;
    viewportState.pViewports = &viewport;
    viewportState.scissorCount = 1;
    viewportState.pScissors = &scissor;

    //Rasterizer
    VkPipelineRasterizationStateCreateInfo rasterizer = {};
    rasterizer.sType = VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO;
    rasterizer.depthClampEnable = VK_FALSE;
    rasterizer.rasterizerDiscardEnable = VK_FALSE;
    rasterizer.polygonMode = VK_POLYGON_MODE_FILL;
    rasterizer.lineWidth = 1.0f;
    rasterizer.cullMode = VK_CULL_MODE_BACK_BIT;
    rasterizer.frontFace = VK_FRONT_FACE_COUNTER_CLOCKWISE;
    //Depth manipulation
    rasterizer.depthBiasEnable = VK_FALSE;
    rasterizer.depthBiasConstantFactor = 0.0f; // Optional
    rasterizer.depthBiasClamp = 0.0f; // Optional
    rasterizer.depthBiasSlopeFactor = 0.0f; // Optional

    //Multisampling
    VkPipelineMultisampleStateCreateInfo multisampling = {};
    multisampling.sType = VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO;
    multisampling.sampleShadingEnable = VK_FALSE;
    multisampling.rasterizationSamples = VK_SAMPLE_COUNT_1_BIT;
    multisampling.minSampleShading = 1.0f; // Optional
    multisampling.pSampleMask = NULL; // Optional
    multisampling.alphaToCoverageEnable = VK_FALSE; // Optional
    multisampling.alphaToOneEnable = VK_FALSE; // Optional

    //Depth / Stencil
    VkPipelineDepthStencilStateCreateInfo depthStencil = {};
    depthStencil.sType = VK_STRUCTURE_TYPE_PIPELINE_DEPTH_STENCIL_STATE_CREATE_INFO;
    depthStencil.depthTestEnable = VK_TRUE;
    depthStencil.depthWriteEnable = VK_TRUE;
    depthStencil.depthCompareOp = VK_COMPARE_OP_LESS;
    depthStencil.depthBoundsTestEnable = VK_FALSE;
    depthStencil.stencilTestEnable = VK_FALSE;

    //Color blending
    VkPipelineColorBlendAttachmentState colorBlendAttachment = {};
    colorBlendAttachment.colorWriteMask = VK_COLOR_COMPONENT_R_BIT | VK_COLOR_COMPONENT_G_BIT | VK_COLOR_COMPONENT_B_BIT | VK_COLOR_COMPONENT_A_BIT;
    colorBlendAttachment.blendEnable = VK_FALSE;
    colorBlendAttachment.srcColorBlendFactor = VK_BLEND_FACTOR_ONE; // Optional
    colorBlendAttachment.dstColorBlendFactor = VK_BLEND_FACTOR_ZERO; // Optional
    colorBlendAttachment.colorBlendOp = VK_BLEND_OP_ADD; // Optional
    colorBlendAttachment.srcAlphaBlendFactor = VK_BLEND_FACTOR_ONE; // Optional
    colorBlendAttachment.dstAlphaBlendFactor = VK_BLEND_FACTOR_ZERO; // Optional
    colorBlendAttachment.alphaBlendOp = VK_BLEND_OP_ADD; // Optional

    VkPipelineColorBlendStateCreateInfo colorBlending = {};
    colorBlending.sType = VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO;
    colorBlending.logicOpEnable = VK_FALSE;
    colorBlending.logicOp = VK_LOGIC_OP_COPY; // Optional
    colorBlending.attachmentCount = 1;
    colorBlending.pAttachments = &colorBlendAttachment;
    colorBlending.blendConstants[0] = 0.0f; // Optional
    colorBlending.blendConstants[1] = 0.0f; // Optional
    colorBlending.blendConstants[2] = 0.0f; // Optional
    colorBlending.blendConstants[3] = 0.0f; // Optional

    //Pipeline-Layout
    VkPipelineLayoutCreateInfo pipelineLayoutInfo = {};
    pipelineLayoutInfo.sType = VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO;
    pipelineLayoutInfo.setLayoutCount = 1;
    pipelineLayoutInfo.pSetLayouts = &app.descriptorSetLayout;
    pipelineLayoutInfo.pushConstantRangeCount = 0; // Optional
    pipelineLayoutInfo.pPushConstantRanges = NULL; // Optional

    if (vkCreatePipelineLayout(app.device, &pipelineLayoutInfo, NULL, &app.pipelineLayout) != VK_SUCCESS) {
        perror("failed to create pipeline layout!");
        exit(EXIT_FAILURE);
    }

    //Final Pipeline creation
    VkGraphicsPipelineCreateInfo pipelineInfo = {};
    pipelineInfo.sType = VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO;
    pipelineInfo.stageCount = 2;
    pipelineInfo.pStages = shaderStages;
    pipelineInfo.pVertexInputState = &vertexInputInfo;
    pipelineInfo.pInputAssemblyState = &inputAssembly;
    pipelineInfo.pViewportState = &viewportState;
    pipelineInfo.pRasterizationState = &rasterizer;
    pipelineInfo.pMultisampleState = &multisampling;
    pipelineInfo.pDepthStencilState = &depthStencil;
    pipelineInfo.pColorBlendState = &colorBlending;
    pipelineInfo.pDynamicState = NULL; // Optional
    pipelineInfo.layout = app.pipelineLayout;
    pipelineInfo.renderPass = app.renderPass;
    pipelineInfo.subpass = 0;
    pipelineInfo.basePipelineHandle = VK_NULL_HANDLE; // Optional
    pipelineInfo.basePipelineIndex = -1; // Optional

    if (vkCreateGraphicsPipelines(app.device, VK_NULL_HANDLE, 1, &pipelineInfo, NULL, &app.graphicsPipeline) != VK_SUCCESS) {
        perror("failed to create graphics pipeline!");
       exit(EXIT_FAILURE);
    }

    vkDestroyShaderModule(app.device, fragShaderModule, NULL);
    vkDestroyShaderModule(app.device, vertShaderModule, NULL);    
}

void vk_createComputePipeline() {
    DEBUG_PRINT("vk_createComputePipeline\n");

    const unsigned char *computeShaderCode;
    int computeShaderSize = readFile("src/shaders/comp.spv", &computeShaderCode);

    VkShaderModule computeShaderModule = vk_createShaderModule((const unsigned char*) computeShaderCode, computeShaderSize);

    //Vertex
    VkPipelineShaderStageCreateInfo computeShaderInfo = {
        .sType = VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
        .stage = VK_SHADER_STAGE_COMPUTE_BIT,
        .module = computeShaderModule,
        .pName = "main",
    };

    //Pipeline-Layout
    VkPipelineLayoutCreateInfo pipelineLayoutInfo = {};
    pipelineLayoutInfo.sType = VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO;
    pipelineLayoutInfo.setLayoutCount = 1;
    pipelineLayoutInfo.pSetLayouts = &app.descriptorSetLayoutCompute;
    pipelineLayoutInfo.pushConstantRangeCount = 0; // Optional
    pipelineLayoutInfo.pPushConstantRanges = NULL; // Optional

    if (vkCreatePipelineLayout(app.device, &pipelineLayoutInfo, NULL, &app.pipelineLayoutCompute) != VK_SUCCESS) {
        perror("failed to create pipeline layout!");
        exit(EXIT_FAILURE);
    }

    //Final Pipeline creation
    VkComputePipelineCreateInfo pipelineInfo = {
        .sType = VK_STRUCTURE_TYPE_COMPUTE_PIPELINE_CREATE_INFO,
        .pNext = NULL,
        .stage = computeShaderInfo,
        .layout = app.pipelineLayoutCompute,

    };

    if (vkCreateComputePipelines(app.device, VK_NULL_HANDLE, 1, &pipelineInfo, NULL, &app.computePipeline) != VK_SUCCESS) {
        perror("failed to create compute pipeline!");
       exit(EXIT_FAILURE);
    }

    vkDestroyShaderModule(app.device, computeShaderModule, NULL);  
}


VkShaderModule vk_createShaderModule(const unsigned char* code, int codeSize){
    DEBUG_PRINT("vk_createShaderModule\n");
    VkShaderModuleCreateInfo createInfo = {};
    createInfo.sType = VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO;
    createInfo.codeSize = (size_t) codeSize;
    createInfo.pCode = (const uint32_t*) code;

    VkShaderModule shaderModule;
    if (vkCreateShaderModule(app.device, &createInfo, NULL, &shaderModule) != VK_SUCCESS) {
        perror("failed to create shader module");
        exit(EXIT_FAILURE);
    }
    return shaderModule;
}

void vk_createFramebuffers() {
    DEBUG_PRINT("vk_createFramebuffers");
    app.swapChainFramebuffers = calloc(app.swapChainImageCount, sizeof(VkFramebuffer));

    for(int i = 0; i < app.swapChainImageCount; i++){
        VkImageView attachments[] = {
            app.swapChainImageViews[i],
            app.depthImageView
        };

        VkFramebufferCreateInfo framebufferInfo = {};
        framebufferInfo.sType = VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO;
        framebufferInfo.renderPass = app.renderPass;
        framebufferInfo.attachmentCount = 2;
        framebufferInfo.pAttachments = attachments;
        framebufferInfo.width = app.swapChainExtent.width;
        framebufferInfo.height = app.swapChainExtent.height;
        framebufferInfo.layers = 1;

        if (vkCreateFramebuffer(app.device, &framebufferInfo, NULL, &app.swapChainFramebuffers[i]) != VK_SUCCESS){
            perror("failed to create framebuffer!");
            exit(EXIT_FAILURE);
        }
    }
}

void vk_createBuffer(
    VkDeviceSize size, VkBufferUsageFlags usage, VkMemoryPropertyFlags properties,
    VkBuffer *buffer, VkDeviceMemory *bufferMemory)
{
    DEBUG_PRINT("vk_createBuffer");

    VkBufferCreateInfo bufferInfo = {};
    bufferInfo.sType = VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO;
    bufferInfo.size = size;
    bufferInfo.usage = usage;
    bufferInfo.sharingMode = VK_SHARING_MODE_EXCLUSIVE;

    if(vkCreateBuffer(app.device, &bufferInfo, NULL, buffer) != VK_SUCCESS) {
        perror("failed to create vertex buffer!");
        exit(EXIT_FAILURE);
    }

    VkMemoryRequirements memRequirements;
    vkGetBufferMemoryRequirements(app.device, *buffer, &memRequirements);

    VkMemoryAllocateInfo allocInfo = {};
    allocInfo.sType = VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO;
    allocInfo.allocationSize = memRequirements.size;
    allocInfo.memoryTypeIndex = vk_findMemoryType(memRequirements.memoryTypeBits, properties);

    if (vkAllocateMemory(app.device, &allocInfo, NULL, bufferMemory) != VK_SUCCESS) {
        perror("failed to allocate buffer memory!");
        exit(EXIT_FAILURE);
    }

    vkBindBufferMemory(app.device, *buffer, *bufferMemory, 0);

}

void vk_createDepthResource(){
    DEBUG_PRINT("vk_createDepthResource");
    VkFormat depthFormat = VK_FORMAT_D32_SFLOAT;

    vk_createImage(app.swapChainExtent.width, app.swapChainExtent.height, depthFormat, 
        VK_IMAGE_TILING_OPTIMAL, VK_IMAGE_USAGE_DEPTH_STENCIL_ATTACHMENT_BIT, 
        VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT, &app.depthImage, &app.depthImageMemory);
    
    app.depthImageView = vk_createImageView(app.depthImage, depthFormat, VK_IMAGE_ASPECT_DEPTH_BIT);

    vk_transitionImageLayout(app.depthImage, depthFormat, 
        VK_IMAGE_LAYOUT_UNDEFINED, VK_IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL);
}

void vk_createTextureImage(){
    DEBUG_PRINT("vk_createTextureImage");
    unsigned texWidth, texHeight, error;
    unsigned char* pixels;

    error = lodepng_decode32_file(&pixels, &texWidth, &texHeight, TEXTURE_PATH);

    VkDeviceSize imageSize = texWidth*texHeight*4;

    if(error || !pixels){
        perror("failed to load texture image!");
        exit(EXIT_FAILURE);
    }

    VkBuffer stagingBuffer;
    VkDeviceMemory stagingBufferMemory;

    vk_createBuffer(imageSize, VK_BUFFER_USAGE_TRANSFER_SRC_BIT, 
            VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | VK_MEMORY_PROPERTY_HOST_COHERENT_BIT, 
            &stagingBuffer, &stagingBufferMemory);

    void* data;
    vkMapMemory(app.device, stagingBufferMemory, 0, imageSize, 0, &data);
    memcpy(data, pixels, (size_t) imageSize);
    vkUnmapMemory(app.device, stagingBufferMemory);

    free(pixels);

    vk_createImage(texWidth, texHeight, VK_FORMAT_R8G8B8A8_UNORM, VK_IMAGE_TILING_OPTIMAL, 
        VK_IMAGE_USAGE_TRANSFER_DST_BIT | VK_IMAGE_USAGE_SAMPLED_BIT, VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT, 
        &app.textureImage, &app.textureImageMemory);

    vk_transitionImageLayout(app.textureImage, VK_FORMAT_R8G8B8A8_UNORM, 
        VK_IMAGE_LAYOUT_UNDEFINED, VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL);

    vk_copyBufferToImage(stagingBuffer, app.textureImage, (uint32_t) texWidth, (uint32_t) texHeight);

    vk_transitionImageLayout(app.textureImage, VK_FORMAT_R8G8B8A8_UNORM, 
        VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL, VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL);

    vkDestroyBuffer(app.device, stagingBuffer, NULL);
    vkFreeMemory(app.device, stagingBufferMemory, NULL);
}

void vk_createTextureImageView(){
    DEBUG_PRINT("vk_createTextureImageView");
    app.textureImageView = vk_createImageView(app.textureImage, VK_FORMAT_R8G8B8A8_UNORM, VK_IMAGE_ASPECT_COLOR_BIT);
}

void vk_createTextureSampler(){
    DEBUG_PRINT("vk_createTextureSampler");
    VkSamplerCreateInfo samplerInfo = {
        .sType = VK_STRUCTURE_TYPE_SAMPLER_CREATE_INFO,
        .magFilter = VK_FILTER_LINEAR,
        .minFilter = VK_FILTER_LINEAR,
        .addressModeU = VK_SAMPLER_ADDRESS_MODE_REPEAT,
        .addressModeV = VK_SAMPLER_ADDRESS_MODE_REPEAT,
        .addressModeW = VK_SAMPLER_ADDRESS_MODE_REPEAT,
        .anisotropyEnable = VK_TRUE,
        .maxAnisotropy = 16,
        .borderColor = VK_BORDER_COLOR_INT_OPAQUE_BLACK,
        .unnormalizedCoordinates = VK_FALSE,
        .compareEnable = VK_FALSE,
        .compareOp = VK_COMPARE_OP_ALWAYS,
        .mipmapMode = VK_SAMPLER_MIPMAP_MODE_LINEAR,
        .mipLodBias = 0.0f,
        .minLod = 0.0f,
        .maxLod = 0.0f
    };

    if (vkCreateSampler(app.device, &samplerInfo, NULL, &app.textureSampler) != VK_SUCCESS) {
        perror("failed to create texture sampler!");
        exit(EXIT_FAILURE);
    }
}

VkImageView vk_createImageView(VkImage image, VkFormat format, VkImageAspectFlags aspectFlags){
    DEBUG_PRINT("vk_createImageView");
    VkImageViewCreateInfo viewInfo = {};
    viewInfo.sType = VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO;
    viewInfo.image = image;
    viewInfo.viewType = VK_IMAGE_VIEW_TYPE_2D;
    viewInfo.format = format;
    viewInfo.subresourceRange.aspectMask = aspectFlags;
    viewInfo.subresourceRange.baseMipLevel = 0;
    viewInfo.subresourceRange.levelCount = 1;
    viewInfo.subresourceRange.baseArrayLayer = 0;
    viewInfo.subresourceRange.layerCount = 1;

    VkImageView imageView;
    if (vkCreateImageView(app.device, &viewInfo, NULL, &imageView) != VK_SUCCESS) {
        perror("failed to create texture image view!");
        exit(EXIT_FAILURE);
    }

    return imageView;
}

void vk_createImage(uint32_t width, uint32_t height, VkFormat format, VkImageTiling tiling,
    VkImageUsageFlags usage, VkMemoryPropertyFlags properties, VkImage *image, VkDeviceMemory * imageMemory){
    DEBUG_PRINT("vk_createImage");
    
    VkImageCreateInfo imageInfo = {
        .sType = VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO,
        .imageType = VK_IMAGE_TYPE_2D,
        .extent.width = (uint32_t) width,
        .extent.height = (uint32_t) height,
        .extent.depth = 1,
        .mipLevels = 1,
        .arrayLayers = 1,
        .format = format,
        .tiling = tiling,
        .initialLayout = VK_IMAGE_LAYOUT_UNDEFINED,
        .usage = usage,
        .sharingMode = VK_SHARING_MODE_EXCLUSIVE,
        .samples = VK_SAMPLE_COUNT_1_BIT,
        .flags = 0 //optional
    };

    if (vkCreateImage(app.device, &imageInfo, NULL, image) != VK_SUCCESS){
        perror("failed to create image!");
        exit(EXIT_FAILURE);
    }

    VkMemoryRequirements memRequirements;
    vkGetImageMemoryRequirements(app.device, *image, &memRequirements);

    VkMemoryAllocateInfo allocInfo = {
        .sType = VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
        .allocationSize = memRequirements.size,
        .memoryTypeIndex = vk_findMemoryType(memRequirements.memoryTypeBits, VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT)
    };

    if (vkAllocateMemory(app.device, &allocInfo, NULL, imageMemory) != VK_SUCCESS) {
        perror("failed to allocate image memory!");
        exit(EXIT_FAILURE);
    }

    vkBindImageMemory(app.device, *image, *imageMemory, 0);    
}

void vk_createVertexBuffer(){
    DEBUG_PRINT("vk_createVertexBuffer");

    VkDeviceSize bufferSize = sizeof(Vertex) * 1500000;

    VkBuffer stagingBuffer;
    VkDeviceMemory stagingBufferMemory;

    vk_createBuffer(bufferSize, VK_BUFFER_USAGE_TRANSFER_SRC_BIT,
        VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | VK_MEMORY_PROPERTY_HOST_COHERENT_BIT, &stagingBuffer, &stagingBufferMemory);

    void *data;
    vkMapMemory(app.device, stagingBufferMemory, 0, bufferSize, 0, &data);
    memcpy(data, app.vertices, (size_t) bufferSize);
    vkUnmapMemory(app.device, stagingBufferMemory);

    vk_createBuffer(bufferSize, VK_BUFFER_USAGE_TRANSFER_DST_BIT | VK_BUFFER_USAGE_VERTEX_BUFFER_BIT,
        VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT, &app.vertexBuffer, &app.vertexBufferMemory);

    vk_copyBuffer(stagingBuffer, app.vertexBuffer, bufferSize);

    vkDestroyBuffer(app.device, stagingBuffer, NULL);
    vkFreeMemory(app.device, stagingBufferMemory, NULL);
}

void vk_createIndexBuffer(){
    DEBUG_PRINT("vk_createIndexBuffer");

    VkDeviceSize bufferSize = sizeof(uint32_t)*1500000;

    VkBuffer stagingBuffer;
    VkDeviceMemory stagingBufferMemory;

    vk_createBuffer(bufferSize, VK_BUFFER_USAGE_TRANSFER_SRC_BIT,
        VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | VK_MEMORY_PROPERTY_HOST_COHERENT_BIT, &stagingBuffer, &stagingBufferMemory);

    void *data;
    vkMapMemory(app.device, stagingBufferMemory, 0, bufferSize, 0, &data);
    memcpy(data, app.indices, (size_t) bufferSize);
    vkUnmapMemory(app.device, stagingBufferMemory);

    vk_createBuffer(bufferSize, VK_BUFFER_USAGE_TRANSFER_DST_BIT | VK_BUFFER_USAGE_INDEX_BUFFER_BIT,
        VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT, &app.indexBuffer, &app.indexBufferMemory);

    vk_copyBuffer(stagingBuffer, app.indexBuffer, bufferSize);

    vkDestroyBuffer(app.device, stagingBuffer, NULL);
    vkFreeMemory(app.device, stagingBufferMemory, NULL);
}

void vk_createUniformBuffers(){
    DEBUG_PRINT("vk_createUniformBuffers");
    VkDeviceSize bufferSize = sizeof(UniformBufferObject);

    app.uniformBuffers = calloc(app.swapChainImageCount, sizeof(VkBuffer));
    app.uniformBuffersMemory = calloc(app.swapChainImageCount, sizeof(VkDeviceMemory));

    for (int i = 0; i < app.swapChainImageCount; ++i){
        vk_createBuffer(bufferSize, VK_BUFFER_USAGE_UNIFORM_BUFFER_BIT, VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | VK_MEMORY_PROPERTY_HOST_COHERENT_BIT,
            &app.uniformBuffers[i], &app.uniformBuffersMemory[i]);
    }
}

void vk_createDescriptorPool() {
    DEBUG_PRINT("vk_createDescriptorPool");
    VkDescriptorPoolSize poolSizes[2] = {};
    poolSizes[0].type = VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER;
    poolSizes[0].descriptorCount = app.swapChainImageCount;
    poolSizes[1].type = VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER;
    poolSizes[1].descriptorCount = app.swapChainImageCount;

    VkDescriptorPoolCreateInfo poolInfo = {};
    poolInfo.sType = VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO;
    poolInfo.poolSizeCount = 2;
    poolInfo.pPoolSizes = poolSizes;
    poolInfo.maxSets = app.swapChainImageCount;

    if(vkCreateDescriptorPool(app.device, &poolInfo, NULL, &app.descriptorPool) != VK_SUCCESS){
        perror("failed to create descriptor pool!");
        exit(EXIT_FAILURE);
    }
}

void vk_createDescriptorSets(){
    DEBUG_PRINT("vk_createDescriptorSets");
    VkDescriptorSetLayout layouts[app.swapChainImageCount];// = calloc(app.swapChainImageCount, sizeof(app.descriptorSetLayout));
    for(int i = 0; i < app.swapChainImageCount; i++){
        layouts[i] = app.descriptorSetLayout;
    }

    VkDescriptorSetAllocateInfo allocInfo = {};
    allocInfo.sType = VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO;
    allocInfo.descriptorPool = app.descriptorPool;
    allocInfo.descriptorSetCount = app.swapChainImageCount;
    allocInfo.pSetLayouts = layouts;

    app.descriptorSets = calloc(app.swapChainImageCount, sizeof(VkDescriptorSet));
    if(vkAllocateDescriptorSets(app.device, &allocInfo, app.descriptorSets) != VK_SUCCESS){
        perror("failed to allocate descripto sets!");
        exit(EXIT_FAILURE);
    }

    for (int i = 0; i < app.swapChainImageCount; ++i){
        VkDescriptorBufferInfo bufferInfo = {};
        bufferInfo.buffer = app.uniformBuffers[i];
        bufferInfo.offset = 0;
        bufferInfo.range = sizeof(UniformBufferObject);

        VkDescriptorImageInfo imageInfo = {};
        imageInfo.imageLayout = VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL;
        imageInfo.imageView = app.textureImageView;
        imageInfo.sampler = app.textureSampler;

        VkWriteDescriptorSet descriptorWrites[2] = {};
        descriptorWrites[0].sType = VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET;
        descriptorWrites[0].dstSet = app.descriptorSets[i];
        descriptorWrites[0].dstBinding = 0;
        descriptorWrites[0].dstArrayElement = 0;
        descriptorWrites[0].descriptorType = VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER;
        descriptorWrites[0].descriptorCount = 1;
        descriptorWrites[0].pBufferInfo = &bufferInfo;

        descriptorWrites[1].sType = VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET;
        descriptorWrites[1].dstSet = app.descriptorSets[i];
        descriptorWrites[1].dstBinding = 1;
        descriptorWrites[1].dstArrayElement = 0;
        descriptorWrites[1].descriptorType = VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER;
        descriptorWrites[1].descriptorCount = 1;
        descriptorWrites[1].pImageInfo = &imageInfo;

        vkUpdateDescriptorSets(app.device, 2, descriptorWrites, 0, NULL);
    }
}

void vk_copyBuffer(VkBuffer srcBuffer, VkBuffer dstBuffer, VkDeviceSize size){
    DEBUG_PRINT("vk_copyBuffer");
    
    VkCommandBuffer commandBuffer = vk_beginSingleTimeCommands();


    VkBufferCopy copyRegion = {};
    copyRegion.srcOffset = 0; //optional
    copyRegion.dstOffset = 0; //optional
    copyRegion.size = size;
    vkCmdCopyBuffer(commandBuffer, srcBuffer, dstBuffer, 1, &copyRegion);

    vk_endSingleTimeCommands(commandBuffer);
}

VkCommandBuffer vk_beginSingleTimeCommands(){
    DEBUG_PRINT("vk_beginSingleTimeCommands");
    VkCommandBufferAllocateInfo allocInfo = {
        .sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
        .level = VK_COMMAND_BUFFER_LEVEL_PRIMARY,
        .commandPool = app.commandPool,
        .commandBufferCount = 1
    };

    VkCommandBuffer commandBuffer;
    vkAllocateCommandBuffers(app.device, &allocInfo, &commandBuffer);

    VkCommandBufferBeginInfo beginInfo = {
        .sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
        .flags = VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT
    };

    vkBeginCommandBuffer(commandBuffer, &beginInfo);

    return commandBuffer;
}

void vk_endSingleTimeCommands(VkCommandBuffer commandBuffer){
    DEBUG_PRINT("vk_endSingleTimeCommands");
    vkEndCommandBuffer(commandBuffer);

    VkSubmitInfo submitInfo = {
        .sType = VK_STRUCTURE_TYPE_SUBMIT_INFO,
        .commandBufferCount = 1,
        .pCommandBuffers = &commandBuffer
    };

    vkQueueSubmit(app.graphicsQueue, 1, &submitInfo, VK_NULL_HANDLE);
    vkQueueWaitIdle(app.graphicsQueue);

    vkFreeCommandBuffers(app.device, app.commandPool, 1, &commandBuffer);
}

void vk_copyBufferToImage(VkBuffer buffer, VkImage image, uint32_t width, uint32_t height){
    DEBUG_PRINT("vk_copyBuffer");
    VkCommandBuffer commandBuffer = vk_beginSingleTimeCommands();

    VkBufferImageCopy region = {
        .bufferOffset = 0,
        .bufferRowLength = 0,
        .bufferImageHeight = 0,

        .imageSubresource.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT,
        .imageSubresource.mipLevel = 0,
        .imageSubresource.baseArrayLayer = 0,
        .imageSubresource.layerCount = 1,

        .imageOffset = {0, 0, 0},
        .imageExtent = {
            width,
            height,
            1
        }
    };

    vkCmdCopyBufferToImage(
        commandBuffer,
        buffer,
        image,
        VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
        1,
        &region
    );

    vk_endSingleTimeCommands(commandBuffer);
}

void vk_transitionImageLayout(VkImage image, VkFormat format, VkImageLayout oldLayout, VkImageLayout newLayout){
    DEBUG_PRINT("vk_transitionImageLayout");
    VkCommandBuffer commandBuffer = vk_beginSingleTimeCommands();

    VkImageMemoryBarrier barrier = {
        .sType = VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER,
        .oldLayout = oldLayout,
        .newLayout = newLayout,
        .srcQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED,
        .dstQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED,
        .image = image,
        .subresourceRange.baseMipLevel = 0,
        .subresourceRange.levelCount = 1,
        .subresourceRange.baseArrayLayer = 0,
        .subresourceRange.layerCount = 1,
        .srcAccessMask = 0, //TODO
        .dstAccessMask = 1 //TODO
    };

    if (newLayout == VK_IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL) {
        barrier.subresourceRange.aspectMask = VK_IMAGE_ASPECT_DEPTH_BIT;

            if (format == VK_FORMAT_D32_SFLOAT_S8_UINT || format == VK_FORMAT_D24_UNORM_S8_UINT) {
                barrier.subresourceRange.aspectMask |= VK_IMAGE_ASPECT_STENCIL_BIT;
            }
    } else {
        barrier.subresourceRange.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
    }


    VkPipelineStageFlags sourceStage;
    VkPipelineStageFlags destinationStage;

    if (oldLayout == VK_IMAGE_LAYOUT_UNDEFINED && newLayout == VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL) {
        barrier.srcAccessMask = 0;
        barrier.dstAccessMask = VK_ACCESS_TRANSFER_WRITE_BIT;

        sourceStage = VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT;
        destinationStage = VK_PIPELINE_STAGE_TRANSFER_BIT;
    } else if (oldLayout == VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL && newLayout == VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL) {
        barrier.srcAccessMask = VK_ACCESS_TRANSFER_WRITE_BIT;
        barrier.dstAccessMask = VK_ACCESS_SHADER_READ_BIT;

        sourceStage = VK_PIPELINE_STAGE_TRANSFER_BIT;
        destinationStage = VK_PIPELINE_STAGE_FRAGMENT_SHADER_BIT;
    } else if (oldLayout == VK_IMAGE_LAYOUT_UNDEFINED && newLayout == VK_IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL) {
        barrier.srcAccessMask = 0;
        barrier.dstAccessMask = VK_ACCESS_DEPTH_STENCIL_ATTACHMENT_READ_BIT | VK_ACCESS_DEPTH_STENCIL_ATTACHMENT_WRITE_BIT;

        sourceStage = VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT;
        destinationStage = VK_PIPELINE_STAGE_EARLY_FRAGMENT_TESTS_BIT;
    } else {
        perror("unsupported layout transition!");
        exit(EXIT_FAILURE);
    }

    vkCmdPipelineBarrier(
        commandBuffer, //before barrier
        sourceStage, destinationStage,
        0,
        0, NULL, //memory barriers
        0, NULL, //buffer memory barriers
        1, &barrier //image memory barriers
    );

    vk_endSingleTimeCommands(commandBuffer);
}

uint32_t vk_findMemoryType(uint32_t typeFilter, VkMemoryPropertyFlags properties){
    DEBUG_PRINT("vk_findMemoryType");
    VkPhysicalDeviceMemoryProperties memProperties;
    vkGetPhysicalDeviceMemoryProperties(app.physicalDevice, &memProperties);

    for(uint32_t i = 0; i < memProperties.memoryTypeCount; i++){
        if (typeFilter & (1 << i) && (memProperties.memoryTypes[i].propertyFlags & properties) == properties) {
            return i;
        }
    }

    perror("failed to find suitable memory type!");
    exit(EXIT_FAILURE);
}

void vk_createCommandPool(){
    DEBUG_PRINT("vk_createCommandPool");
    struct QueueFamilyIndices queueFamilyIndices = vk_findQueueFamilies(app.physicalDevice);

    VkCommandPoolCreateInfo poolInfo = {};
    poolInfo.sType = VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO;
    poolInfo.queueFamilyIndex = queueFamilyIndices.graphicsFamily;
    poolInfo.flags = 0; //Optional

    if(vkCreateCommandPool(app.device, &poolInfo, NULL, &app.commandPool) != VK_SUCCESS){
        perror("failed to create command pool!");
        exit(EXIT_FAILURE);
    }

}

void vk_createCommandBuffers(){
    DEBUG_PRINT("vk_createCommandBuffers");
    app.commandBuffers = calloc(app.swapChainImageCount, sizeof(VkCommandBuffer));

    VkCommandBufferAllocateInfo allocInfo = {};
    allocInfo.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO;
    allocInfo.commandPool = app.commandPool;
    allocInfo.level = VK_COMMAND_BUFFER_LEVEL_PRIMARY;
    allocInfo.commandBufferCount = app.swapChainImageCount;

    if (vkAllocateCommandBuffers(app.device, &allocInfo, app.commandBuffers) != VK_SUCCESS) {
        perror("failed to allocate command buffers!");
        exit(EXIT_FAILURE);
    }

    for (size_t i = 0; i < app.swapChainImageCount; i++) {
        VkCommandBufferBeginInfo beginInfo = {};
        beginInfo.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO;
        beginInfo.flags = VK_COMMAND_BUFFER_USAGE_SIMULTANEOUS_USE_BIT;
        beginInfo.pInheritanceInfo = NULL; // Optional

        if (vkBeginCommandBuffer(app.commandBuffers[i], &beginInfo) != VK_SUCCESS) {
            perror("failed to begin recording command buffer!");
            exit(EXIT_FAILURE);
        }

        VkClearValue clearValues[2] = {
            {.color = {.float32 = {0.0f, 0.0f, 0.0f, 1.0f}}},
            {.depthStencil = {1.0f, 0}}
        };

        VkRenderPassBeginInfo renderPassInfo = {};
        renderPassInfo.sType = VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO;
        renderPassInfo.renderPass = app.renderPass;
        renderPassInfo.framebuffer = app.swapChainFramebuffers[i];
        renderPassInfo.renderArea = (VkRect2D) {.offset={0, 0}, .extent=app.swapChainExtent};
        renderPassInfo.clearValueCount = 2;
        renderPassInfo.pClearValues = clearValues;

        vkCmdBeginRenderPass(app.commandBuffers[i], &renderPassInfo, VK_SUBPASS_CONTENTS_INLINE);

        vkCmdBindPipeline(app.commandBuffers[i], VK_PIPELINE_BIND_POINT_GRAPHICS, app.graphicsPipeline);

        VkBuffer vertexBuffers[] = {app.vertexBuffer};
        VkDeviceSize offsets[] = {0};
        vkCmdBindVertexBuffers(app.commandBuffers[i], 0, 1, vertexBuffers, offsets);
        vkCmdBindIndexBuffer(app.commandBuffers[i], app.indexBuffer, 0, VK_INDEX_TYPE_UINT32);

        vkCmdBindDescriptorSets(app.commandBuffers[i], VK_PIPELINE_BIND_POINT_GRAPHICS, app.pipelineLayout,
            0, 1, &app.descriptorSets[i], 0, NULL);

        //vkCmdDraw(app.commandBuffers[i], 4, 1, 0, 0);
        vkCmdDrawIndexed(app.commandBuffers[i], (uint32_t) 1500000, 1, 0, 0, 0);

        vkCmdEndRenderPass(app.commandBuffers[i]);
        if(vkEndCommandBuffer(app.commandBuffers[i]) != VK_SUCCESS){
            perror("failed to record command buffer!");
            exit(EXIT_FAILURE);
        }
    }
}

void vk_updateUniformBuffer(uint32_t currentImage){
    static clock_t startTime = 0;
    if(startTime == 0) {startTime = clock();}
    clock_t now = clock();

    //double diff = difftime(now, startTime);
    double diff = (double)(now-startTime)/(double)CLOCKS_PER_SEC;

    UniformBufferObject ubo = {};
    glm_rotate_make(ubo.model, diff * glm_rad(90.0f), (vec3){0.0f, 0.0f, 1.0f});
    glm_lookat((vec3){2.0f, 2.0f, 2.0f}, (vec3){0.0f, 0.0f, 0.0f}, (vec3){0.0f, 0.0f, 1.0f}, ubo.view);
    glm_perspective(glm_rad(45.0f), app.swapChainExtent.width / (float) app.swapChainExtent.height, 
        0.1f, 10.0f, ubo.proj);
    ubo.proj[1][1] *= -1;

    void *data;
    vkMapMemory(app.device, app.uniformBuffersMemory[currentImage], 0, sizeof(ubo), 0, &data);
        memcpy(data, &ubo, sizeof(ubo));
    vkUnmapMemory(app.device, app.uniformBuffersMemory[currentImage]);
}

void vk_drawFrame(){
    vkWaitForFences(app.device, 1, &app.inFlightFences[app.currentFrame], VK_TRUE, ULLONG_MAX);

    uint32_t imageIndex;
    VkResult result = vkAcquireNextImageKHR(app.device, app.swapChain, ULLONG_MAX, app.imageAvailableSemaphore[app.currentFrame], VK_NULL_HANDLE, &imageIndex);

    if (result == VK_ERROR_OUT_OF_DATE_KHR) {
        vk_recreateSwapChain();
        return;
    } else if (result != VK_SUCCESS && result != VK_SUBOPTIMAL_KHR) {
        perror("failed to acquire swap chain image!");
        exit(EXIT_FAILURE);
    }

    vk_updateUniformBuffer(imageIndex);

    VkSubmitInfo submitInfo = {};
    submitInfo.sType = VK_STRUCTURE_TYPE_SUBMIT_INFO;

    VkSemaphore waitSemaphores[] = {app.imageAvailableSemaphore[app.currentFrame]};
    VkPipelineStageFlags waitStages[] = {VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT};
    submitInfo.waitSemaphoreCount = 1;
    submitInfo.pWaitSemaphores = waitSemaphores;
    submitInfo.pWaitDstStageMask = waitStages;

    submitInfo.commandBufferCount = 1;
    submitInfo.pCommandBuffers = &app.commandBuffers[imageIndex];

    VkSemaphore signalSemaphores[] = {app.renderFinishedSemaphore[app.currentFrame]};
    submitInfo.signalSemaphoreCount = 1;
    submitInfo.pSignalSemaphores = signalSemaphores;

    vkResetFences(app.device, 1, &app.inFlightFences[app.currentFrame]);

    if(vkQueueSubmit(app.graphicsQueue, 1, &submitInfo, app.inFlightFences[app.currentFrame]) != VK_SUCCESS){
        perror("failed to submit draw command buffer!");
        exit(EXIT_FAILURE);
    }

    VkPresentInfoKHR presentInfo = {};
    presentInfo.sType = VK_STRUCTURE_TYPE_PRESENT_INFO_KHR;

    presentInfo.waitSemaphoreCount = 1;
    presentInfo.pWaitSemaphores = signalSemaphores;

    VkSwapchainKHR swapChains[] = {app.swapChain};
    presentInfo.swapchainCount = 1;
    presentInfo.pSwapchains = swapChains;
    presentInfo.pImageIndices = &imageIndex;
    presentInfo.pResults = NULL; //optional

    result = vkQueuePresentKHR(app.presentingQueue, &presentInfo);

    if (result == VK_ERROR_OUT_OF_DATE_KHR || result == VK_SUBOPTIMAL_KHR || app.framebufferResized) {
        app.framebufferResized = false;
        vk_recreateSwapChain();
    } else if (result != VK_SUCCESS) {
        perror("failed to present swap chain image!");
        exit(EXIT_FAILURE);
    }

    app.currentFrame = (app.currentFrame + 1) % MAX_FRAMES_IN_FLIGHT;
}

void vk_createSyncObjects(){
    DEBUG_PRINT("vk_createSyncObjects");
    VkSemaphoreCreateInfo semaphoreInfo = {};
    semaphoreInfo.sType = VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO;

    VkFenceCreateInfo fenceInfo = {};
    fenceInfo.sType = VK_STRUCTURE_TYPE_FENCE_CREATE_INFO;
    fenceInfo.flags = VK_FENCE_CREATE_SIGNALED_BIT;

    for(int i = 0; i < MAX_FRAMES_IN_FLIGHT; i++){
        if (vkCreateSemaphore(app.device, &semaphoreInfo, NULL, &app.imageAvailableSemaphore[i]) != VK_SUCCESS ||
            vkCreateSemaphore(app.device, &semaphoreInfo, NULL, &app.renderFinishedSemaphore[i]) != VK_SUCCESS ||
            vkCreateFence(app.device, &fenceInfo, NULL, &app.inFlightFences[i]) != VK_SUCCESS) {

            perror("failed to create synchronization objects for a frame!");
            exit(EXIT_FAILURE);
        }
    }
}

void app_mainLoop() {
    DEBUG_PRINT("app_mainLoop\n");

    while (!glfwWindowShouldClose(app.window)){
        glfwPollEvents();
        vk_drawFrame();
    }

    vkDeviceWaitIdle(app.device);
}

void app_cleanup() {
    DEBUG_PRINT("app_cleanup\n");

    vk_cleanupSwapChain();

    vkDestroySampler(app.device, app.textureSampler, NULL);
    vkDestroyImageView(app.device, app.textureImageView, NULL);

    vkDestroyImage(app.device, app.textureImage, NULL);
    vkFreeMemory(app.device, app.textureImageMemory, NULL);

    vkDestroyDescriptorSetLayout(app.device, app.descriptorSetLayout, NULL);

    vkDestroyBuffer(app.device, app.vertexBuffer, NULL);
    vkFreeMemory(app.device, app.vertexBufferMemory, NULL);

    vkDestroyBuffer(app.device, app.indexBuffer, NULL);
    vkFreeMemory(app.device, app.indexBufferMemory, NULL);

    for(int i = 0; i < MAX_FRAMES_IN_FLIGHT; i++){
        vkDestroySemaphore(app.device, app.renderFinishedSemaphore[i], NULL);
        vkDestroySemaphore(app.device, app.imageAvailableSemaphore[i], NULL);
        vkDestroyFence(app.device, app.inFlightFences[i], NULL);
    }

    vkDestroyCommandPool(app.device, app.commandPool, NULL);

    vkDestroyDevice(app.device, NULL);

    if (enableValidationLayers) {
        DestroyDebugUtilsMessengerEXT(app.instance, app.debugMessenger, NULL);
    }

    vkDestroySurfaceKHR(app.instance, app.surface, NULL);
    vkDestroyInstance(app.instance, NULL);

    glfwDestroyWindow(app.window);
    glfwTerminate();
}

//TODO: add Windows support (without sys/stat)
int readFile(const char* fileName, const unsigned char** dst) {
    uint32_t fileSize = getFileSize(fileName);
    printf("\nLoading file \"%s\" with %d bytes\n", fileName, fileSize);
    FILE *file = fopen(fileName, "rb");
    if(file == NULL) {
        perror("failed to open file");
        exit(EXIT_FAILURE);
    }

    unsigned char *tmp = malloc(fileSize);

    for(int i = 0; i < fileSize; i++) {
        tmp[i] = fgetc(file);
        //printf("%02x", tmp[i]);
        //if(i % 2 == 1){printf(" ");}
        //if (i % 16 == 15){printf("\n");}
        //printf("_%d_", i);
    }

    if (ferror(file)) {
        perror("failed to read file");
        exit(EXIT_FAILURE);
    }

    fclose(file);
    *dst = tmp;
    return fileSize;
}

void loadModel(){
    tinyobj_attrib_t attrib;
    tinyobj_shape_t* shapes = NULL;
    size_t num_shapes;
    tinyobj_material_t* materials = NULL;
    size_t num_materials;

    const unsigned char* data;// = get_file_data(&data_len, MODEL_PATH);
    size_t data_len = readFile(MODEL_PATH, &data);

    if (data == NULL) {
        perror("failed loading model");
        exit(EXIT_FAILURE);
    }
    printf("filesize: %d\n", (int)data_len);

    {
        unsigned int flags = TINYOBJ_FLAG_TRIANGULATE;
        int ret = tinyobj_parse_obj(&attrib, &shapes, &num_shapes, &materials,
                                    &num_materials, data, data_len, flags);
        if (ret != TINYOBJ_SUCCESS) {
            perror("failed loading model");
            exit(EXIT_FAILURE);
        }

        printf("# of shapes    = %d\n", (int)num_shapes);
        printf("# of materials = %d\n", (int)num_materials); 
        printf("# of vertices: %d\n", attrib.num_vertices);   
        printf("# of tex_coords: %d\n", attrib.num_texcoords); 
        printf("# of faces: %d\n", attrib.num_faces);
        printf("# face # verts: %d\n", attrib.num_face_num_verts);           
        
        app.indices = calloc(sizeof(uint32_t), attrib.num_faces);
        for (int i = 0; i < num_shapes; i++) {
            printf("shape[%d] name = %s\n", i, shapes[i].name);
            printf("length: %d\n", shapes[i].length);
            printf("face_offset: %d\n", shapes[i].face_offset);
            
            app.vertices = calloc(sizeof(Vertex), shapes[i].length * 3);
            for (int j = shapes[i].face_offset; j < shapes[i].face_offset + 3 * shapes[i].length ; j++)
            {
                Vertex vertex = {
                    .pos = {
                        attrib.vertices[3*attrib.faces[j].v_idx ],
                        attrib.vertices[3*attrib.faces[j].v_idx + 1],
                        attrib.vertices[3*attrib.faces[j].v_idx + 2]
                    },
                    .texCoord = {
                        attrib.texcoords[2*attrib.faces[j].vt_idx + 0],
                        1.0f-attrib.texcoords[2*attrib.faces[j].vt_idx + 1],
                    },
                    .color = {1.0f, 1.0f, 1.0f}
                };
                app.vertices[j - shapes[i].face_offset] = vertex;
                app.indices[j - shapes[i].face_offset] = j - shapes[i].face_offset;
                
            }
        }        
    }
}

static unsigned getFileSize(const char * file_name) {
    struct stat sb;
    if (stat (file_name, & sb) != 0) {
        fprintf (stderr, "'stat' failed for '%s': %s.\n",
                 file_name, strerror (errno));
        exit (EXIT_FAILURE);
    }
    return sb.st_size;
}
