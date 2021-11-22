lib_na_tray_sources = files(
    'fixedtip.c',
    'na-grid.c',
    'na-host.c',
    'na-item.c',
    'na-marshal.c',
    'na-tray-child.c',
    'na-tray-manager.c',
    'na-tray.c'
)

lib_na_tray_dependencies = [
    gtk_dep,
    gobject_dep,
    gdk_pixbuf_dep,
    x11_dep,
    m_dep
]

lib_na_tray_static = static_library ('na_tray',
    lib_na_tray_sources,
    dependencies: lib_na_tray_dependencies
)

lib_na_tray_dependency = declare_dependency (
    link_with: lib_na_tray_static,
    include_directories: [ include_directories('.') ]
)
