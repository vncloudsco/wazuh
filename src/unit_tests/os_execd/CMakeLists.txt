# Generate execd library
file(GLOB execd_files
    ${SRC_FOLDER}/os_execd/*.o
    ${SRC_FOLDER}/active-response/*.o)

add_library(EXECD_O STATIC ${execd_files})

set_source_files_properties(
    ${execd_files}
    PROPERTIES
    EXTERNAL_OBJECT true
    GENERATED true
)

set_target_properties(
    EXECD_O
    PROPERTIES
    LINKER_LANGUAGE C
)

target_link_libraries(EXECD_O ${WAZUHLIB} ${WAZUHEXT} -lpthread)

#include wrappers
include(${SRC_FOLDER}/unit_tests/wrappers/wazuh/shared/shared.cmake)

# Generate Execd tests
if(${TARGET} STREQUAL "winagent")
    list(APPEND execd_names "test_win_execd")
    list(APPEND execd_flags "-Wl,--wrap,ReadExecConfig -Wl,--wrap,GetCommandbyName -Wl,--wrap,wpopenv -Wl,--wrap,wpclose -Wl,--wrap,fwrite \
                             -Wl,--wrap,fopen -Wl,--wrap,fclose -Wl,--wrap,fflush -Wl,--wrap,fgets -Wl,--wrap,fread -Wl,--wrap,fseek \
                             -Wl,--wrap,remove -Wl,--wrap,fgetpos -Wl,--wrap=fgetc -Wl,--wrap,fwrite \
                             ${DEBUG_OP_WRAPPERS}")
else()
    list(APPEND execd_names "test_execd")
    list(APPEND execd_flags "-Wl,--wrap,time -Wl,--wrap,select -Wl,--wrap,OS_RecvUnix \
                             -Wl,--wrap,ReadExecConfig -Wl,--wrap,GetCommandbyName -Wl,--wrap,wpopenv -Wl,--wrap,wpclose -Wl,--wrap,fwrite \
                             -Wl,--wrap,fopen -Wl,--wrap,fclose -Wl,--wrap,fflush -Wl,--wrap,fgets -Wl,--wrap,fread -Wl,--wrap,fseek \
                             -Wl,--wrap,remove -Wl,--wrap,fgetpos -Wl,--wrap=fgetc -Wl,--wrap,fwrite \
                             -Wl,--wrap,fprintf ${DEBUG_OP_WRAPPERS}")
endif()

list(LENGTH execd_names count)
math(EXPR count "${count} - 1")
foreach(counter RANGE ${count})
    list(GET execd_names ${counter} execd_test_name)
    list(GET execd_flags ${counter} execd_test_flags)

    add_executable(${execd_test_name} ${execd_test_name}.c)

    target_link_libraries(
        ${execd_test_name}
        ${WAZUHLIB}
        ${WAZUHEXT}
        EXECD_O
        ${TEST_DEPS}
    )

    if(NOT execd_test_flags STREQUAL " ")
        target_link_libraries(
            ${execd_test_name}
            ${execd_test_flags}
        )
    endif()
    add_test(NAME ${execd_test_name} COMMAND ${execd_test_name})
endforeach()
