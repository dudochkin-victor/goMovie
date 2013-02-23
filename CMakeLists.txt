cmake_minimum_required (VERSION 2.8)
cmake_policy (VERSION 2.6)
list (APPEND CMAKE_MODULE_PATH ${CMAKE_SOURCE_DIR}/cmake/vala)
enable_testing ()
list (APPEND CMAKE_MODULE_PATH ${CMAKE_SOURCE_DIR}/cmake)

project (gomovie)

set (DATADIR "${CMAKE_INSTALL_PREFIX}/share")
set (PKGDATADIR "${DATADIR}/gomovie")
set (GETTEXT_PACKAGE "gomovie")
set (RELEASE_NAME "A modern media player.")
set (VERSION "0.1")
set (VERSION_INFO "The Red Comet")

# Data
install(FILES ${CMAKE_CURRENT_SOURCE_DIR}/data/icons/16/gomovie.svg DESTINATION ${DATADIR}/icons/hicolor/16x16/apps/)
install(FILES ${CMAKE_CURRENT_SOURCE_DIR}/data/icons/24/gomovie.svg DESTINATION ${DATADIR}/icons/hicolor/24x24/apps/)
install(FILES ${CMAKE_CURRENT_SOURCE_DIR}/data/icons/32/gomovie.svg DESTINATION ${DATADIR}/icons/hicolor/32x32/apps/)
install(FILES ${CMAKE_CURRENT_SOURCE_DIR}/data/icons/48/gomovie.svg DESTINATION ${DATADIR}/icons/hicolor/48x48/apps/)
install(FILES ${CMAKE_CURRENT_SOURCE_DIR}/data/icons/64/gomovie.svg DESTINATION ${DATADIR}/icons/hicolor/64x64/apps/)
install(FILES ${CMAKE_CURRENT_SOURCE_DIR}/data/icons/128/gomovie.svg DESTINATION ${DATADIR}/icons/hicolor/128x128/apps/)
install(FILES ${CMAKE_CURRENT_SOURCE_DIR}/data/gomovie.desktop DESTINATION ${DATADIR}/applications/)

# Configure file
configure_file (${CMAKE_SOURCE_DIR}/src/Config.vala.cmake ${CMAKE_BINARY_DIR}/src/Config.vala)
add_definitions(-DGETTEXT_PACKAGE="gomovie")

find_package(PkgConfig)
pkg_check_modules(DEPS REQUIRED granite gtk+-3.0 clutter-gtk-1.0 clutter-gst-1.0 gstreamer-pbutils-0.10 gstreamer-interfaces-0.10 gstreamer-tag-0.10 gdl-3.0 glib-2.0)
add_definitions(${DEPS_CFLAGS})
link_libraries(${DEPS_LIBRARIES})
link_directories(${DEPS_LIBRARY_DIRS})
find_package(Vala REQUIRED)
include(ValaVersion)

ensure_vala_version("0.15.1" MINIMUM)

include(ValaPrecompile)
vala_precompile(VALA_C
    src/gomovie.vala
    src/Consts.vala
    src/Settings.vala
    src/Utils.vala
    ${CMAKE_BINARY_DIR}/src/Config.vala
    src/Widgets/TagView.vala
    src/Widgets/Button.vala
    src/Widgets/ControlsBar.vala
    src/Widgets/LLabel.vala
    src/Widgets/MediaSlider.vala
    src/Widgets/TopPanel.vala
    src/Widgets/Playlist.vala
    src/desktop-launcher.vala
PACKAGES
    gtk+-3.0
    granite
    clutter-gst-1.0
    clutter-gtk-1.0
    gdk-x11-3.0
    gstreamer-pbutils-0.10
    gstreamer-interfaces-0.10
    gstreamer-tag-0.10
    gdl-3.0
OPTIONS
    --thread
    -g
)


include(GSettings)
add_schema ("data/org.gomovie.gschema.xml")

add_subdirectory (po)
add_executable(gomovie ${VALA_C})
install (TARGETS gomovie RUNTIME DESTINATION bin)
