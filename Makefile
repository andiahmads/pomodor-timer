run:
	clang -fobjc-arc -framework Cocoa -framework UserNotifications -framework AVFoundation -framework Carbon -framework EventKit -o PomodoroTimer main.m
	mv PomodoroTimer PomodoroTimer.app/Contents/MacOS/
	mkdir -p PomodoroTimer.app/Contents/Resources/Sounds


