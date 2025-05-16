# configure - in theory we should use CMAKE_INSTALL_SYSCONFDIR but that doesn't work
install(FILES slim.conf DESTINATION ${SYSCONFDIR})
