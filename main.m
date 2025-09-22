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
@property(strong) AVAudioPlayer *soundType;
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
  self.totalSeconds = 1 * 60; // 25 menit
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

  [self setupSoundWithType:SoundTypeWork];
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

- (void)saveSetting {
  NSString *selected = self.sessionSelector.titleOfSelectedItem;

  if ([selected isEqualToString:@"25 / 5"]) {
    self.workDuration = 1 * 60; // Testing: 1 menit
    self.breakDuration = 30;    // Testing: 30 detik (0.5 * 60 = 30)
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

  NSLog(@"Setting saved: %@ - Work: %ld seconds, Break: %ld seconds", selected,
        (long)self.workDuration, (long)self.breakDuration);
  [self.window endSheet:self.settingsWindow];
}
#pragma closeModal
- (void)closeSettingModal {
  [self.window endSheet:self.settingsWindow];
}

typedef NS_ENUM(NSInteger, SoundType) { SoundTypeBreak, SoundTypeWork };

#pragma setup sound
- (void)setupSoundWithType:(SoundType)SoundType {
  NSString *fileName;

  switch (SoundType) {
  case SoundTypeBreak:
    fileName = @"alarm-clock";
    break;
  case SoundTypeWork:
    fileName = @"fireplace";
    break;
  }

  NSString *path = [[NSBundle mainBundle] pathForResource:fileName
                                                   ofType:@"mp3"];
  if (!path) {
    NSLog(@"Sound file %@.mp3 not found!", fileName);
    return;
  }

  NSURL *url = [NSURL fileURLWithPath:path];
  NSError *error = nil;
  self.soundType = [[AVAudioPlayer alloc] initWithContentsOfURL:url
                                                          error:&error];

  if (error) {
    NSLog(@"Error loading %@ sound: %@", fileName, error.localizedDescription);
    return;
  }

  self.soundType.numberOfLoops = -1;
  [self.soundType prepareToPlay];
}

#pragma mark - Timer Logic
- (void)startTimer {
  if (self.isRunning)
    return;

  // pastikan timer sebelumnya dibersihkan
  if (self.timer) {
    [self.timer invalidate];
    self.timer = nil;
  }

  self.isRunning = YES;
  [self.startButton setEnabled:NO];
  [self.pauseButton setEnabled:YES];

  // jika player belum di setup, siapkan dulu
  if (!self.soundType) {
    [self setupSoundWithType:SoundTypeWork];
  }

  // Mainkan hujan
  if (self.soundType && !self.soundType.isPlaying) {
    self.soundType.volume = 1.0;
    [self.soundType play];
    NSLog(@"Rain sound started...");
  }

  // Buat timer dan tambahkan ke common modes supaya tetap berjalan setelah
  // modal/during event tracking
  NSTimer *t = [NSTimer timerWithTimeInterval:1.0
                                       target:self
                                     selector:@selector(updateTimer)
                                     userInfo:nil
                                      repeats:YES];
  self.timer = t;
  [[NSRunLoop mainRunLoop] addTimer:self.timer forMode:NSRunLoopCommonModes];

  [self updateUI];
  NSLog(@"[startTimer] started (isWorkSession=%@) for %ld seconds",
        self.isWorkSession ? @"YES" : @"NO", (long)self.remainingSeconds);
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
  if (self.soundType.isPlaying) {
    [self.soundType stop];
    NSLog(@"Rain sound stopped on pause...");
  }
}

- (void)resetTimer {
  [self pauseTimer];

  if (self.isWorkSession) {
    self.totalSeconds = self.workDuration;
    self.remainingSeconds = self.workDuration;
    [self.window setTitle:@"Pomodoro Timer - Work"];
  } else {
    self.totalSeconds = self.breakDuration;
    self.remainingSeconds = self.breakDuration;
    [self.window setTitle:@"Pomodoro Timer - Break"];
  }

  [self.timeLabel setStringValue:[self formatTime:self.remainingSeconds]];
  [self.progressBar setMaxValue:(double)self.totalSeconds];
  [self.progressBar setDoubleValue:(double)self.remainingSeconds];
  [self updateUI];
}

- (void)updateTimer {
  if (self.remainingSeconds > 0) {
    self.remainingSeconds--;
    [self updateUI];
    return;
  }

  // Timer selesai - hentikan timer dan suara
  [self.timer invalidate];
  self.timer = nil;
  self.isRunning = NO;

  // Hentikan suara hujan
  if (self.soundType && self.soundType.isPlaying) {
    [self.soundType stop];
    NSLog(@"Rain sound stopped...");
  }

  [self.startButton setEnabled:YES];
  [self.pauseButton setEnabled:NO];

  [self sendNotification];

  // DEBUG: Log nilai sebelum switching
  NSLog(@"BEFORE SWITCH - workDuration: %ld, breakDuration: %ld, "
        @"isWorkSession: %@",
        (long)self.workDuration, (long)self.breakDuration,
        self.isWorkSession ? @"YES" : @"NO");

  if (self.isWorkSession) {
    [self switchToBreakSession];
  } else {
    [self switchToWorkSession];
  }
}

- (void)switchToBreakSession {

  // PASTIKAN breakDuration tidak 0
  if (self.breakDuration == 0) {
    self.breakDuration = 30;
  }

  self.isWorkSession = NO;
  self.totalSeconds = self.breakDuration;
  self.remainingSeconds = self.breakDuration;

  // Hentikan semua sound sebelumnya
  if (self.soundType) {
    [self.soundType stop];
    self.soundType = nil;
  }

  // Update UI untuk break session
  [self.progressBar setMaxValue:(double)self.totalSeconds];
  [self.progressBar setDoubleValue:(double)self.remainingSeconds];
  [self updateUI];

  NSAlert *alert = [[NSAlert alloc] init];
  alert.messageText = @"Work session completed!";
  alert.informativeText = [NSString
      stringWithFormat:@"Time for a %d second break", (int)self.breakDuration];
  [alert addButtonWithTitle:@"Start Break"];

  // 🔥 PUTAR ALARM HANYA UNTUK ALERT
  if (!self.isWorkSession) {
    [self setupSoundWithType:SoundTypeBreak];
    if (self.soundType) {
      self.soundType.numberOfLoops = 0; // 🔥 HANYA SEKALI
      self.soundType.volume = 1.0;
      [self.soundType play];
    }
  }

  [alert beginSheetModalForWindow:self.window
                completionHandler:^(NSModalResponse returnCode) {
                  dispatch_async(dispatch_get_main_queue(), ^{
                    if (self.soundType && self.soundType.isPlaying) {
                      [self.soundType stop];
                      self.soundType = nil;
                    }
                    [self startTimer];
                  });
                }];
}

- (void)switchToWorkSession {
  NSLog(@"Break session completed, switching to work session");

  // PASTIKAN workDuration tidak 0
  if (self.workDuration == 0) {
    NSLog(@"WARNING: workDuration is 0, setting to default 60 seconds");
    self.workDuration = 60;
  }

  self.isWorkSession = YES;
  self.totalSeconds = self.workDuration;
  self.remainingSeconds = self.workDuration;

  // Hentikan semua sound
  if (self.soundType) {
    [self.soundType stop];
    self.soundType = nil;
  }

  // Update UI untuk work session
  [self.progressBar setMaxValue:(double)self.totalSeconds];
  [self.progressBar setDoubleValue:(double)self.remainingSeconds];
  [self updateUI];

  NSAlert *alert = [[NSAlert alloc] init];
  alert.messageText = @"Break is over!";
  alert.informativeText = [NSString
      stringWithFormat:@"Time to work for %d seconds", (int)self.workDuration];
  [alert addButtonWithTitle:@"Start Work"];

  [alert beginSheetModalForWindow:self.window
                completionHandler:^(NSModalResponse returnCode) {
                  dispatch_async(dispatch_get_main_queue(), ^{
                    NSLog(@"Starting WORK session - Duration: %ld seconds",
                          (long)self.workDuration);

                    // 🔥 Setup dan putar sound untuk work session (jika
                    // diinginkan)
                    [self setupSoundWithType:SoundTypeWork];
                    if (self.soundType) {
                      self.soundType.numberOfLoops =
                          -1; // Loop selama work session
                      [self.soundType play];
                      NSLog(@"🌧️ Work session sound started");
                    }

                    [self startTimer];
                  });
                }];
}

- (void)updateUI {
  NSString *sessionType = self.isWorkSession ? @"Work" : @"Break";
  NSInteger minutes = self.remainingSeconds / 60;
  NSInteger seconds = self.remainingSeconds % 60;

  self.timeLabel.stringValue =
      [NSString stringWithFormat:@"%@: %02ld:%02ld", sessionType, (long)minutes,
                                 (long)seconds];

  // Update progress bar
  [self.progressBar setDoubleValue:(double)self.remainingSeconds];

  // Update window title
  NSString *title =
      [NSString stringWithFormat:@"Pomodoro Timer - %@", sessionType];
  [self.window setTitle:title];
}

- (void)initializeDefaultValues {
  // Set nilai default jika belum ada
  if (self.workDuration == 0) {
    self.workDuration = 1 * 60; // 1 menit untuk testing
  }
  if (self.breakDuration == 0) {
    self.breakDuration = 30; // 30 detik untuk testing
  }

  NSLog(@"Default values initialized - Work: %ld, Break: %ld",
        (long)self.workDuration, (long)self.breakDuration);
}

// Method untuk debug nilai saat ini
- (void)logCurrentValues {
  NSLog(@"Current values - Work: %ld seconds, Break: %ld seconds, "
        @"isWorkSession: %@, remainingSeconds: %ld",
        (long)self.workDuration, (long)self.breakDuration,
        self.isWorkSession ? @"YES" : @"NO", (long)self.remainingSeconds);
}

- (void)changeSessionMode:(NSPopUpButton *)sender {
  NSString *selected = sender.titleOfSelectedItem;

  if ([selected isEqualToString:@"25 / 5"]) {
    self.workDuration = 1 * 60; // Testing: 1 menit
    self.breakDuration = 30;    // Testing: 30 detik
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
      [NSString stringWithFormat:@"Pomodoro Timer - Work (%@)", selected];
  [self.window setTitle:title];

  NSLog(@"Session mode changed to %@ - Work: %ld, Break: %ld", selected,
        (long)self.workDuration, (long)self.breakDuration);
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
