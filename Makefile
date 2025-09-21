run:
	clang -fobjc-arc -framework Cocoa -framework UserNotifications -framework AVFoundation -o PomodoroTimer main.m
	mv PomodoroTimer PomodoroTimer.app/Contents/MacOS/


