# systemd service file - condition is wrong - not all Linux uses systemd!
if (${CMAKE_SYSTEM_NAME} MATCHES "Linux")
	install(FILES slim.service DESTINATION ${SYSTEMDDIR}/system)
endif (${CMAKE_SYSTEM_NAME} MATCHES "Linux")

