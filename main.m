#import <AVFoundation/AVFoundation.h>
#include <AppKit/AppKit.h>
#import <Cocoa/Cocoa.h>
#include <Foundation/Foundation.h>
#import <UserNotifications/UserNotifications.h>

@interface AppDelegate : NSObject <NSApplicationDelegate>
@property(strong) NSWindow *window;
@property(strong) NSTextField *timeLabel;
@property(strong) NSProgressIndicator *progressBar;
@property(strong) NSButton *startButton;
@property(strong) NSButton *pauseButton;
@property(strong) NSButton *resetButton;
@property(strong) NSTimer *timer;

@property(assign) BOOL isWorkSession;
@property(assign) BOOL isRunning;
@property(assign) NSInteger totalSeconds;
@property(assign) NSInteger remainingSeconds;
@property(strong) AVAudioPlayer *rainPlayer;
@property(assign) NSInteger workDuration;  // durasi kerja dalam detik
@property(assign) NSInteger breakDuration; // durasi istirahat dalam detik

// setting modal window
@property(strong) NSWindow *settingsWindow;
@property(strong) NSPopUpButton *sessionSelector;
@end

@implementation AppDelegate

#pragma mark - Setup Aplikasi
- (void)applicationDidFinishLaunching:(NSNotification *)notification {

  // === Konfigurasi awal ===
  self.isWorkSession = YES; // Mulai dengan work session
  self.isRunning = NO;
  self.totalSeconds = 25 * 60; // 25 menit
  self.remainingSeconds = self.totalSeconds;

  // === Buat window ===
  self.window = [[NSWindow alloc]
      initWithContentRect:NSMakeRect(300, 300, 400, 250)
                styleMask:(NSWindowStyleMaskTitled | NSWindowStyleMaskClosable)
                  backing:NSBackingStoreBuffered
                    defer:NO];
  [self.window setTitle:@"Pomodoro Timer"];
  [self.window makeKeyAndOrderFront:nil];

  [self setupMenuBar];

  // === Label waktu ===
  self.timeLabel =
      [[NSTextField alloc] initWithFrame:NSMakeRect(100, 150, 200, 40)];
  [self.timeLabel setStringValue:[self formatTime:self.remainingSeconds]];
  [self.timeLabel setFont:[NSFont boldSystemFontOfSize:24]];
  [self.timeLabel setBezeled:NO];
  [self.timeLabel setDrawsBackground:NO];
  [self.timeLabel setEditable:NO];
  [self.timeLabel setSelectable:NO];
  [self.timeLabel setAlignment:NSTextAlignmentCenter];
  [self.window.contentView addSubview:self.timeLabel];

  // === Progress bar ===
  self.progressBar =
      [[NSProgressIndicator alloc] initWithFrame:NSMakeRect(50, 120, 300, 20)];
  [self.progressBar setIndeterminate:NO];
  [self.progressBar setMinValue:0.0];
  [self.progressBar setMaxValue:(double)self.totalSeconds];
  [self.progressBar setDoubleValue:(double)self.remainingSeconds];
  [self.window.contentView addSubview:self.progressBar];

  // === Tombol Start ===
  self.startButton =
      [[NSButton alloc] initWithFrame:NSMakeRect(50, 50, 80, 40)];
  [self.startButton setTitle:@"Start"];
  [self.startButton setButtonType:NSButtonTypeMomentaryPushIn];
  [self.startButton setBezelStyle:NSBezelStyleRounded];
  [self.startButton setTarget:self];
  [self.startButton setAction:@selector(startTimer)];
  [self.window.contentView addSubview:self.startButton];

  // === Tombol Pause ===
  self.pauseButton =
      [[NSButton alloc] initWithFrame:NSMakeRect(160, 50, 80, 40)];
  [self.pauseButton setTitle:@"Pause"];
  [self.pauseButton setButtonType:NSButtonTypeMomentaryPushIn];
  [self.pauseButton setBezelStyle:NSBezelStyleRounded];
  [self.pauseButton setTarget:self];
  [self.pauseButton setAction:@selector(pauseTimer)];
  [self.pauseButton setEnabled:NO]; // Tidak aktif di awal
  [self.window.contentView addSubview:self.pauseButton];

  // === Tombol Reset ===
  self.resetButton =
      [[NSButton alloc] initWithFrame:NSMakeRect(270, 50, 80, 40)];
  [self.resetButton setTitle:@"Reset"];
  [self.resetButton setButtonType:NSButtonTypeMomentaryPushIn];
  [self.resetButton setBezelStyle:NSBezelStyleRounded];
  [self.resetButton setTarget:self];
  [self.resetButton setAction:@selector(resetTimer)];
  [self.window.contentView addSubview:self.resetButton];

  [self setupRainSound];
  // === Minta izin notifikasi ===
  UNUserNotificationCenter *center =
      [UNUserNotificationCenter currentNotificationCenter];
  [center requestAuthorizationWithOptions:(UNAuthorizationOptionAlert |
                                           UNAuthorizationOptionSound)
                        completionHandler:^(BOOL granted,
                                            NSError *_Nullable error) {
                          if (!granted) {
                            NSLog(@"User tidak memberi izin untuk notifikasi.");
                          }
                        }];
}

#pragma mark - Menu bar setup
- (void)setupMenuBar {
  NSMenu *mainMenu = [[NSMenu alloc] init];

  // Menu Utama Pomodoro
  NSMenuItem *appMenuItem = [[NSMenuItem alloc] init];
  [mainMenu addItem:appMenuItem];

  NSMenu *appMenu = [[NSMenu alloc] initWithTitle:@"Pomodoro"];
  [appMenuItem setSubmenu:appMenu];

  // menu setting
  NSMenuItem *settingItem =
      [[NSMenuItem alloc] initWithTitle:@"Setting"
                                 action:@selector(openSettingModal)
                          keyEquivalent:@" "];
  [settingItem setTarget:self];
  [appMenu addItem:settingItem];

  // Menu Quit
  NSMenuItem *quitItem = [[NSMenuItem alloc] initWithTitle:@"Quit"
                                                    action:@selector(terminate:)
                                             keyEquivalent:@"q"];
  [appMenu addItem:quitItem];

  [NSApp setMainMenu:mainMenu];
}

#pragma mark - Setting Modal
- (void)openSettingModal {
  if (!self.settingsWindow) {
    // === Buat window setting ===
    self.settingsWindow =
        [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 300, 180)
                                    styleMask:(NSWindowStyleMaskTitled |
                                               NSWindowStyleMaskClosable)
                                      backing:NSBackingStoreBuffered
                                        defer:NO];
    [self.settingsWindow setTitle:@"Settings"];
    [self.settingsWindow setBackgroundColor:[NSColor windowBackgroundColor]];
    [self.settingsWindow setOpaque:YES];
    [self.settingsWindow center];

    NSView *contentView = self.settingsWindow.contentView;

    // === Label judul ===
    NSTextField *label =
        [[NSTextField alloc] initWithFrame:NSMakeRect(50, 130, 200, 24)];
    [label setStringValue:@"Work / Break Duration"];
    [label setBezeled:NO];
    [label setDrawsBackground:NO];
    [label setEditable:NO];
    [label setSelectable:NO];
    [label setAlignment:NSTextAlignmentCenter];
    [label setFont:[NSFont boldSystemFontOfSize:14]];
    [contentView addSubview:label];

    // === PopUp Button untuk memilih sesi ===
    self.sessionSelector =
        [[NSPopUpButton alloc] initWithFrame:NSMakeRect(80, 95, 140, 30)];
    [self.sessionSelector addItemWithTitle:@"25 / 5"];
    [self.sessionSelector addItemWithTitle:@"50 / 10"];

    // Default pilihannya sesuai durasi sekarang
    if (self.workDuration == 25 * 60) {
      [self.sessionSelector selectItemAtIndex:0];
    } else {
      [self.sessionSelector selectItemAtIndex:1];
    }

    [contentView addSubview:self.sessionSelector];

    // === Tombol Save ===
    NSButton *saveButton =
        [[NSButton alloc] initWithFrame:NSMakeRect(60, 40, 80, 30)];
    [saveButton setTitle:@"Save"];
    [saveButton setButtonType:NSButtonTypeMomentaryPushIn];
    [saveButton setBezelStyle:NSBezelStyleRounded];
    [saveButton setTarget:self];
    [saveButton setAction:@selector(saveSetting)];
    [contentView addSubview:saveButton];

    // === Tombol Cancel ===
    NSButton *cancelButton =
        [[NSButton alloc] initWithFrame:NSMakeRect(160, 40, 80, 30)];
    [cancelButton setTitle:@"Cancel"];
    [cancelButton setButtonType:NSButtonTypeMomentaryPushIn];
    [cancelButton setBezelStyle:NSBezelStyleRounded];
    [cancelButton setTarget:self];
    [cancelButton setAction:@selector(closeSettingModal)];
    [contentView addSubview:cancelButton];
  }

  // Pastikan window muncul di depan dan aktif
  [self.settingsWindow center];

  [self.window beginSheet:self.settingsWindow completionHandler:nil];
}
#pragma save setting
- (void)saveSetting {
  NSString *selected = self.sessionSelector.titleOfSelectedItem;

  if ([selected isEqualToString:@"25 / 5"]) {
    self.workDuration = 25 * 60;
    self.breakDuration = 5 * 60;
  } else if ([selected isEqualToString:@"50 / 10"]) {
    self.workDuration = 50 * 60;
    self.breakDuration = 10 * 60;
  }

  // reset timer ke mode baru
  self.isWorkSession = YES;
  self.totalSeconds = self.workDuration;
  self.remainingSeconds = self.totalSeconds;

  [self.timeLabel setStringValue:[self formatTime:self.remainingSeconds]];
  [self.progressBar setMaxValue:(double)self.totalSeconds];
  [self.progressBar setDoubleValue:(double)self.remainingSeconds];

  NSLog(@"Setting saved: %@", selected);

  [self.window endSheet:self.settingsWindow];
}

#pragma closeModal
- (void)closeSettingModal {
  [self.window endSheet:self.settingsWindow];
}

#pragma change session mode
- (void)changeSessionMode:(NSPopUpButton *)sender {
  NSString *selected = sender.titleOfSelectedItem;

  if ([selected isEqualToString:@"25 / 5"]) {
    self.workDuration = 25 * 60;
    self.breakDuration = 5 * 60;
  } else if ([selected isEqualToString:@"50 / 10"]) {
    self.workDuration = 50 * 60;
    self.breakDuration = 10 * 60;
  }

  // reset timer ke mode baru
  self.isWorkSession = YES;
  self.totalSeconds = self.workDuration;
  self.remainingSeconds = self.totalSeconds;

  [self.timeLabel setStringValue:[self formatTime:self.remainingSeconds]];
  [self.progressBar setMaxValue:(double)self.totalSeconds];
  [self.progressBar setDoubleValue:(double)self.remainingSeconds];

  NSString *title =
      [NSString stringWithFormat:@"Pomodor Timer - Work (%@)", selected];
  [self.window setTitle:title];

  NSLog(@"Session mode change to %@", selected);
}

#pragma mark - Rain Sound Setup
- (void)setupRainSound {
  NSString *path = [[NSBundle mainBundle] pathForResource:@"rain"
                                                   ofType:@"mp3"];
  if (!path) {
    NSLog(@"Rain sound file not found!");
    return;
  }

  NSURL *url = [NSURL fileURLWithPath:path];
  NSError *error = nil;
  self.rainPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:url
                                                           error:&error];

  if (error) {
    NSLog(@"Error loading rain sound: %@", error.localizedDescription);
    return;
  }

  self.rainPlayer.numberOfLoops = -1; // Looping tak terbatas
  [self.rainPlayer prepareToPlay];
}

#pragma mark - Timer Logic
- (void)startTimer {
  if (self.isRunning)
    return;

  self.isRunning = YES;
  [self.startButton setEnabled:NO];
  [self.pauseButton setEnabled:YES];

  // jika player belum di setup, siapkan dulu
  if (!self.rainPlayer) {
    [self setupRainSound];
  }

  // Mainkan hujan
  if (self.rainPlayer && !self.rainPlayer.isPlaying) {
    self.rainPlayer.volume = 1.0;
    [self.rainPlayer play];
    NSLog(@"Rain sound started...");
  }

  self.timer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                target:self
                                              selector:@selector(updateTimer)
                                              userInfo:nil
                                               repeats:YES];
}

- (void)pauseTimer {
  if (!self.isRunning)
    return;

  self.isRunning = NO;
  [self.startButton setEnabled:YES];
  [self.pauseButton setEnabled:NO];

  [self.timer invalidate];
  self.timer = nil;

  // Hentikan hujan saat pause
  if (self.rainPlayer.isPlaying) {
    [self.rainPlayer stop];
    NSLog(@"Rain sound stopped on pause...");
  }
}

- (void)resetTimer {
  [self pauseTimer];
  self.remainingSeconds = self.totalSeconds;
  [self.timeLabel setStringValue:[self formatTime:self.remainingSeconds]];
  [self.progressBar setDoubleValue:(double)self.remainingSeconds];
  self.isWorkSession = YES;
  [self.window setTitle:@"Pomodoro Timer - Work"];
}

- (void)updateTimer {
  if (self.remainingSeconds > 0) {
    self.remainingSeconds--;
    [self.timeLabel setStringValue:[self formatTime:self.remainingSeconds]];
    [self.progressBar setDoubleValue:(double)self.remainingSeconds];
  } else {
    [self.timer invalidate];
    self.timer = nil;
    self.isRunning = NO;

    // Hentikan suara hujan
    if (self.rainPlayer.isPlaying) {
      [self.rainPlayer stop];
      NSLog(@"Rain sound stopped...");
    }

    [self.startButton setEnabled:YES];
    [self.pauseButton setEnabled:NO];

    [self sendNotification];

    // Switch antara Work Session dan Break
    if (self.isWorkSession) {
      // selesai sesi kerja -> masuk sesi istirahat
      self.totalSeconds = self.breakDuration;
      [self.window setTitle:@"Pomodoro timer - Break"];
    } else {
      // selesai sesi istirahat -> kembali ke sesi kerja
      self.totalSeconds = self.workDuration; // 25 menit kerja
      [self.window setTitle:@"Pomodoro Timer - Work"];
    }

    self.remainingSeconds = self.totalSeconds;
    [self.progressBar setMaxValue:(double)self.totalSeconds];
    [self.progressBar setDoubleValue:(double)self.remainingSeconds];
  }
}

#pragma mark - Helper
- (NSString *)formatTime:(NSInteger)seconds {
  NSInteger minutes = seconds / 60;
  NSInteger sec = seconds % 60;
  return [NSString stringWithFormat:@"%02ld:%02ld", (long)minutes, (long)sec];
}

- (void)sendNotification {
  UNMutableNotificationContent *content =
      [[UNMutableNotificationContent alloc] init];
  if (self.isWorkSession) {
    content.title = @"Waktunya Istirahat!";
    content.body = @"Kerja selesai, ambil waktu 5 menit istirahat.";
  } else {
    content.title = @"Waktunya Kerja!";
    content.body = @"Istirahat selesai, kembali bekerja selama 25 menit.";
  }
  content.sound = [UNNotificationSound defaultSound];

  UNTimeIntervalNotificationTrigger *trigger =
      [UNTimeIntervalNotificationTrigger triggerWithTimeInterval:1 repeats:NO];
  UNNotificationRequest *request =
      [UNNotificationRequest requestWithIdentifier:@"PomodoroDone"
                                           content:content
                                           trigger:trigger];

  [[UNUserNotificationCenter currentNotificationCenter]
      addNotificationRequest:request
       withCompletionHandler:nil];

  // Ganti status sesi
  self.isWorkSession = !self.isWorkSession;
}

@end

#pragma mark - Main
int main(int argc, const char *argv[]) {
  @autoreleasepool {
    NSApplication *app = [NSApplication sharedApplication];

    static AppDelegate *gAppDelegate = nil;
    gAppDelegate = [[AppDelegate alloc] init];
    [app setDelegate:gAppDelegate];

    [app run]; // Gantikan NSApplicationMain
    return 0;
  }
}
