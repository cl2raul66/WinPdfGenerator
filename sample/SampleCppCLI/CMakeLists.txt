cmake_minimum_required(VERSION 3.15)
project(SampleCppCLI LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_executable(SampleCppCLI main.cpp)
target_include_directories(SampleCppCLI PRIVATE ${CMAKE_CURRENT_SOURCE_DIR})
target_link_libraries(SampleCppCLI PRIVATE "${CMAKE_SOURCE_DIR}/../../bin/WinPdfGenerator.lib")

if(WIN32)
    target_compile_definitions(SampleCppCLI PRIVATE _CRT_SECURE_NO_WARNINGS)
endif()
